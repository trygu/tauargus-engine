#include "rta_host_io.h"
#include <cstdarg>
#include <stdexcept>
#include <string>
#include <thread>
#include <vector>

extern "C" void native_output(void);
extern "C" void native_exit(void);
extern "C" void native_abort(void);
extern "C" int native_file(void);
void native_cpp_output();
const char *native_raw_literal();
static std::string output, errors;
static std::thread::id interpreter;
static bool foreign_callback = false;
static void append(std::string &target, const char *format, va_list args) {
    if (std::this_thread::get_id() != interpreter) {
        foreign_callback = true;
        return;
    }
    va_list copy; va_copy(copy, args);
    int count = std::vsnprintf(nullptr, 0, format, copy); va_end(copy);
    std::vector<char> data(count + 1);
    std::vsnprintf(data.data(), data.size(), format, args);
    target.append(data.data(), count);
}
extern "C" void Rprintf(const char *format, ...) {
    va_list args; va_start(args, format); append(output, format, args); va_end(args);
}
extern "C" void REprintf(const char *format, ...) {
    va_list args; va_start(args, format); append(errors, format, args); va_end(args);
}
int main() {
    if (std::string(native_raw_literal()) != "stdout std::cout exit(9)") return 10;
    interpreter = std::this_thread::get_id();
    rta_host_begin();
    native_output();
    native_cpp_output();
    if (output != "C output 7\nC++ output\n" || errors != "C error\nC++ error\n") return 1;
    const std::string saved = output;
    if (native_file() != 0 || output != saved) return 2;
    std::thread worker([] { rta_host_printf("worker\n"); });
    worker.join();
    if (foreign_callback || output != saved) return 3;
    rta_host_end();
    if (output != saved + "worker\n") return 4;
    for (int which = 0; which < 2; ++which) {
        bool caught = false;
        try { if (which) native_abort(); else native_exit(); }
        catch (const std::runtime_error &e) {
            caught = std::string(e.what()).find(which ? "abort" : "7") != std::string::npos;
        }
        if (!caught) return 5;
    }
    rta_host_begin();
    FILE *file = rta_host_freopen("host-redirect.txt", "w", rta_host_stdout());
    if (!file) return 6;
    rta_host_printf("redirected");
    rta_host_fclose(file);
    rta_host_printf("restored");
    rta_host_end();
    if (output != saved + "worker\nrestored") return 7;
    file = std::fopen("host-redirect.txt", "r");
    char buffer[20] = {0};
    if (!file) return 8;
    std::fread(buffer, 1, sizeof(buffer) - 1, file); std::fclose(file);
    return std::string(buffer) == "redirected" ? 0 : 9;
}
