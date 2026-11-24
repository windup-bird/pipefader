//! Android link fixes for the bridge cdylib.
//!
//! Bionic exposes `atexit` to executables through `crtbegin_so.o`; a Rust cdylib
//! does not link crtbegin, while the vendored OpenSSL init object calls it. The
//! shim in `src/android_atexit.c` forwards to `__cxa_atexit`, which libc does
//! export. `-z defs` then turns any other missing platform symbol into a link
//! error instead of an on-device `dlopen` failure.

fn main() {
    if std::env::var("CARGO_CFG_TARGET_OS").as_deref() != Ok("android") {
        return;
    }
    cc::Build::new()
        .file("src/android_atexit.c")
        .compile("pipefader_android_atexit");
    println!("cargo:rustc-link-arg=-Wl,-z,defs");
}
