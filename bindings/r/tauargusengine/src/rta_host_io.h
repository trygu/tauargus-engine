/* SPDX-License-Identifier: EUPL-1.2 */
#ifndef RTA_HOST_IO_H
#define RTA_HOST_IO_H
#include <stddef.h>
#include <stdio.h>
#include <stdarg.h>

#ifdef __cplusplus
extern "C" {
#endif
void rta_host_begin(void);
void rta_host_end(void);
FILE *rta_host_stdout(void);
FILE *rta_host_stderr(void);
#if defined(_WIN32) && defined(__GNUC__) && !defined(__clang__)
#define RTA_PRINTF_STYLE gnu_printf
#else
#define RTA_PRINTF_STYLE printf
#endif
#if defined(__GNUC__) || defined(__clang__)
#define RTA_PRINTF(format_index, args_index) __attribute__((format(RTA_PRINTF_STYLE, format_index, args_index)))
#else
#define RTA_PRINTF(format_index, args_index)
#endif
int rta_host_printf(const char *, ...) RTA_PRINTF(1, 2);
int rta_host_vprintf(const char *, va_list) RTA_PRINTF(1, 0);
int rta_host_fprintf(FILE *, const char *, ...) RTA_PRINTF(2, 3);
int rta_host_vfprintf(FILE *, const char *, va_list) RTA_PRINTF(2, 0);
int rta_host_puts(const char *);
int rta_host_fputs(const char *, FILE *);
int rta_host_putchar(int);
int rta_host_fputc(int, FILE *);
size_t rta_host_fwrite(const void *, size_t, size_t, FILE *);
int rta_host_fflush(FILE *);
int rta_host_fclose(FILE *);
FILE *rta_host_freopen(const char *, const char *, FILE *);
int rta_host_fileno(FILE *);
#if defined(__GNUC__) || defined(__clang__)
__attribute__((noreturn))
#endif
void rta_host_exit(int);
#if defined(__GNUC__) || defined(__clang__)
__attribute__((noreturn))
#endif
void rta_host_abort(void);
#ifdef __cplusplus
}
extern "C++" {
#include <ostream>
std::ostream &rta_host_cout();
std::ostream &rta_host_cerr();
std::ostream &rta_host_clog();
}
#endif
#endif
