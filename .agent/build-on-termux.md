# 构建方式(termux chroot)

这份只适用于 termux chroot（aarch64 Arch Linux + 系统 clang wrapper）。本机 x86_64 的 release 构建走 `android-build.md`，不要把这里的 wrapper 套过去。

宿主机是 aarch64 Arch Linux，NDK 自带的 clang/lld 是 x86_64，直接跑会 `Exec format error`。所以用系统 clang 23 + lld，配 NDK 28 的 sysroot 和静态库，写一个 wrapper 覆盖 CC/CXX/linker，绕开 cargo-ndk。wrapper 在 `/tmp/android-cross/clang`，重启就没了，内容如下（`clang++` 是指向它的软链）：

```sh
#!/bin/bash
NDK=/home/windupbird/android-sdk/ndk/28.2.13676358/toolchains/llvm/prebuilt/linux-x86_64
SYSROOT=$NDK/sysroot
LIB=$SYSROOT/usr/lib/aarch64-linux-android
LIBAPI=$LIB/29
CL=$NDK/lib/clang/19/lib/linux
mode=$(basename "$0")
case "$mode" in
  *clang++|*cxx) BIN=/usr/sbin/clang++ ;;
  *) BIN=/usr/sbin/clang ;;
esac
# cc-rs 会在命令行尾部追加自己的 --target=aarch64-linux-android（默认 API 21），
# 必须丢掉，否则盖掉这里的 29：libamidi 是 API 29+，pthread_cond_clockwait 也要 29。
args=()
while [ $# -gt 0 ]; do
  case "$1" in
    --target=*) shift ;;
    -target) shift 2 ;;
    *) args+=("$1"); shift ;;
  esac
done
exec "$BIN" --target=aarch64-linux-android29 --sysroot="$SYSROOT" \
  -nostdinc++ -isystem "$SYSROOT/usr/include/c++/v1" \
  -fuse-ld=lld -nostdlib \
  -L"$LIB" -L"$LIBAPI" -L"$CL" -L"$CL/aarch64" \
  -lc++_static -lc++abi -l:libclang_rt.builtins-aarch64-android.a -l:libunwind.a -lc -lm -ldl -llog \
  -Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384 \
  "${args[@]}"
```

编译和打包：

```sh
env CC=/tmp/android-cross/clang CXX=/tmp/android-cross/clang++ \
  CC_aarch64_linux_android=/tmp/android-cross/clang \
  CXX_aarch64_linux_android=/tmp/android-cross/clang++ \
  CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER=/tmp/android-cross/clang \
  AR=/usr/sbin/llvm-ar AR_aarch64_linux_android=/usr/sbin/llvm-ar \
  cargo build --release -p bridge --target aarch64-linux-android

cp target/aarch64-linux-android/release/libbridge.so \
   flutter/android/app/src/main/jniLibs/arm64-v8a/

cd flutter && env CI=true FLUTTER_SUPPRESS_ANALYTICS=true \
  flutter build apk --debug --target-platform android-arm64
```

`jniLibs/` 不进版本库，每次改 Rust 都要重新拷；只改 Dart 不用重编 Rust，但 `flutter build` 仍会打包目录里现有的那份 `.so`，注意别拿旧的。

两个和打包相关的坑。直接 `cd flutter/android && ./gradlew assembleDebug` 会因为 AGP 的合成 CMake 任务去跑 SDK 里下载的 x86_64 `cmake 3.22.1`，报 `cannot execute binary file`；走 `flutter build` 时工具会传 `-Pflutter.androidSdkRoot` 和已装 NDK 列表，合成任务不触发，所以别绕开 flutter。`flutter --version` 和版本检查会 `git fetch github.com` 卡住（网络到 GitHub 不通），用 `CI=true` 可以让它跳过；测 Flutter 的话同 `.agent/testing.md`，但这个环境里 SDK 是 `~/flutter`，不是 `/opt/flutter`。

Rust 的 android std 是手动装的：rustup 源写死 tuna、`rustup target add` 会 404，从 USTC 下 `rust-std-*-aarch64-linux-android.tar.xz` 解压进 toolchain（`--strip-components=2`），再往 `lib/rustlib/components` 追加一行。`rustup target list` 不一定显示，但 `rustlib/aarch64-linux-android` 在就能编。
