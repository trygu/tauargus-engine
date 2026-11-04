/* SPDX-License-Identifier: EUPL-1.2 */
#include "rta_host_io.h"
#include <R_ext/Print.h>
#include <cstring>
#include <cstddef>
#include <cerrno>
#include <limits>
#include <mutex>
#include <stdexcept>
#include <string>
#include <thread>
#include <utility>
#include <vector>

namespace {
alignas(std::max_align_t) char output_token;
alignas(std::max_align_t) char error_token;
std::mutex state_mutex;
std::thread::id owner;
bool active = false;
FILE *redirects[2] = {nullptr, nullptr};
std::vector<std::pair<int, std::string> > pending;

class EndArgs {
    va_list &args;
public:
    explicit EndArgs(va_list &value) : args(value) {}
    ~EndArgs() { va_end(args); }
};

int channel(FILE *file) {
    if (file == rta_host_stdout()) return 0;
    if (file == rta_host_stderr()) return 1;
    return -1;
}

void emit(int stream, const std::string &text) {
    if (stream) REprintf("%s", text.c_str());
    else Rprintf("%s", text.c_str());
}

size_t write_console(int stream, const char *data, size_t size) {
    std::string text(data, size);
    bool on_owner;
    {
        std::lock_guard<std::mutex> lock(state_mutex);
        if (redirects[stream])
            return std::fwrite(data, 1, size, redirects[stream]);
        on_owner = active && owner == std::this_thread::get_id();
        if (!on_owner) pending.emplace_back(stream, text);
    }
    // R's console API must only be called by the interpreter thread.
    if (on_owner) emit(stream, text);
    return size;
}

class ConsoleBuffer : public std::streambuf {
    int stream;
public:
    explicit ConsoleBuffer(int value) : stream(value) {}
    std::streamsize xsputn(const char *data, std::streamsize count) override {
        return static_cast<std::streamsize>(write_console(stream, data, count));
    }
    int_type overflow(int_type value) override {
        if (traits_type::eq_int_type(value, traits_type::eof()))
            return traits_type::not_eof(value);
        char c = traits_type::to_char_type(value);
        return write_console(stream, &c, 1) == 1 ? value : traits_type::eof();
    }
    int sync() override { return 0; }
};
}

extern "C" FILE *rta_host_stdout() {
    return reinterpret_cast<FILE *>(&output_token);
}
extern "C" FILE *rta_host_stderr() {
    return reinterpret_cast<FILE *>(&error_token);
}
extern "C" void rta_host_end() {
    std::vector<std::pair<int, std::string> > messages;
    {
        std::lock_guard<std::mutex> lock(state_mutex);
        active = false;
        messages.swap(pending);
        for (int i = 0; i < 2; ++i) {
            if (redirects[i]) std::fclose(redirects[i]);
            redirects[i] = nullptr;
        }
    }
    for (const auto &message : messages) emit(message.first, message.second);
}
extern "C" void rta_host_begin() {
    // Also recover buffered output after an R long jump in the preceding call.
    rta_host_end();
    std::lock_guard<std::mutex> lock(state_mutex);
    owner = std::this_thread::get_id();
    active = true;
}

extern "C" int rta_host_vfprintf(FILE *file, const char *format, va_list args) {
    const int stream = channel(file);
    if (stream < 0) return std::vfprintf(file, format, args);
    va_list count_args;
    va_copy(count_args, args);
    int count = std::vsnprintf(nullptr, 0, format, count_args);
    va_end(count_args);
    if (count < 0) return count;
    std::vector<char> text(static_cast<size_t>(count) + 1);
    std::vsnprintf(text.data(), text.size(), format, args);
    return write_console(stream, text.data(), count) == static_cast<size_t>(count) ? count : -1;
}
extern "C" int rta_host_fprintf(FILE *file, const char *format, ...) {
    va_list args; va_start(args, format);
    EndArgs cleanup(args);
    return rta_host_vfprintf(file, format, args);
}
extern "C" int rta_host_vprintf(const char *format, va_list args) {
    return rta_host_vfprintf(rta_host_stdout(), format, args);
}
extern "C" int rta_host_printf(const char *format, ...) {
    va_list args; va_start(args, format);
    EndArgs cleanup(args);
    return rta_host_vprintf(format, args);
}
extern "C" int rta_host_fputs(const char *text, FILE *file) {
    if (channel(file) < 0) return std::fputs(text, file);
    size_t count = std::strlen(text);
    return write_console(channel(file), text, count) == count ? 0 : EOF;
}
extern "C" int rta_host_puts(const char *text) {
    if (rta_host_fputs(text, rta_host_stdout()) == EOF) return EOF;
    return rta_host_fputc('\n', rta_host_stdout());
}
extern "C" int rta_host_fputc(int value, FILE *file) {
    if (channel(file) < 0) return std::fputc(value, file);
    char c = static_cast<char>(value);
    return write_console(channel(file), &c, 1) == 1 ? static_cast<unsigned char>(c) : EOF;
}
extern "C" int rta_host_putchar(int value) {
    return rta_host_fputc(value, rta_host_stdout());
}
extern "C" size_t rta_host_fwrite(const void *data, size_t size, size_t count, FILE *file) {
    if (channel(file) < 0) return std::fwrite(data, size, count, file);
    if (!size || count > std::numeric_limits<size_t>::max() / size) return 0;
    return write_console(channel(file), static_cast<const char *>(data), size * count) / size;
}
extern "C" int rta_host_fflush(FILE *file) {
    if (channel(file) >= 0) {
        std::lock_guard<std::mutex> lock(state_mutex);
        FILE *target = redirects[channel(file)];
        return target ? std::fflush(target) : 0;
    }
    return std::fflush(file);
}
extern "C" int rta_host_fclose(FILE *file) {
    if (channel(file) >= 0) return rta_host_fflush(file);
    {
        std::lock_guard<std::mutex> lock(state_mutex);
        for (auto &target : redirects) if (target == file) target = nullptr;
    }
    return std::fclose(file);
}
extern "C" FILE *rta_host_freopen(const char *path, const char *mode, FILE *file) {
    const int stream = channel(file);
    if (stream < 0) return std::freopen(path, mode, file);
    if (!path) { errno = EINVAL; return nullptr; }
    FILE *replacement = std::fopen(path, mode);
    if (!replacement) return nullptr;
    std::lock_guard<std::mutex> lock(state_mutex);
    if (redirects[stream]) std::fclose(redirects[stream]);
    redirects[stream] = replacement;
    return replacement;
}
extern "C" int rta_host_fileno(FILE *file) {
    int stream = channel(file);
    return stream >= 0 ? stream + 1 : fileno(file);
}
extern "C" void rta_host_exit(int code) {
    throw std::runtime_error("Native solver requested process exit (code " + std::to_string(code) + ")");
}
extern "C" void rta_host_abort() {
    throw std::runtime_error("Native solver requested process abort");
}
std::ostream &rta_host_cout() {
    static ConsoleBuffer buffer(0); static std::ostream stream(&buffer); return stream;
}
std::ostream &rta_host_cerr() {
    static ConsoleBuffer buffer(1); static std::ostream stream(&buffer); return stream;
}
std::ostream &rta_host_clog() { return rta_host_cerr(); }
