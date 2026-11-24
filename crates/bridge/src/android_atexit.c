/*
 * Bionic's libc does not export `atexit`; executables get it from crtbegin_so.o,
 * which a Rust cdylib does not link. OpenSSL's init object references it, so
 * forward to `__cxa_atexit` (exported by libc) with a null dso handle: the
 * handlers still run at process exit, which is all we need here.
 */
#include <stddef.h>

extern int __cxa_atexit(void (*function)(void *), void *argument, void *dso_handle);

int atexit(void (*function)(void)) {
    return __cxa_atexit((void (*)(void *))function, NULL, NULL);
}
