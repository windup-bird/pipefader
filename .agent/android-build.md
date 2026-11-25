# Android 构建与适配

目标只有 arm64-v8a 的 release APK：`flutter/build/app/outputs/flutter-apk/app-release.apk`，Dart 走 AOT，Rust 也是 release。构建链已经在本机跑通：32M 的 APK 里有 `libbridge.so`（14M，已 strip）、`libapp.so`、`libflutter.so` 和 `libc++_shared.so`（1.2M），minSdk 29。真机上已经验证 audio 能在 48k 打开、midir 能枚举 Party Mix；还没解决的是“没声”的路由/UI 和完整 MIDI。termux chroot 那条路只留在 `build-on-termux.md`，不混进这里。

## 本机环境

Flutter 3.50.1 stable 在 `/opt/flutter`，wrapper 会把它挂到 `~/.cache/flutter_sdk`，直接 `flutter` 可用；`/opt/flutter` 本身不要写。NDK 28.2.13676358 在 `/opt/android-ndk`，SDK 在 `/opt/android-sdk`（platform 36，build-tools 36/37）。Rust 的 `aarch64-linux-android` target 和 `cargo-ndk` 都装了。

gradle 里的 minSdk 已经改成 29：`libamidi` 只有 29+，低版本设备装得上，但 `System.loadLibrary("bridge")` 会直接失败。走 B 以后如果要把 midir 从 Android 依赖里摘掉，可以再试更低的 minSdk，但要单独验证 oboe 的 API 下限，不跟这次混。

## 构建

编 Rust：

```sh
cargo ndk -t arm64-v8a -P 29 \
  -o flutter/android/app/src/main/jniLibs \
  build --release -p bridge
```

`-P 29` 不能省，cargo-ndk 默认 21；`-o` 会把 `libbridge.so` 放进 `jniLibs/arm64-v8a`。`jniLibs` 已经加进 `flutter/android/.gitignore`，每次改 Rust 都要重编；只改 Dart 时打包仍会带上目录里现有的 `.so`，注意别拿旧的。

`libbridge.so` 的 NEEDED 里有 `libc++_shared.so`（oboe 的 C++ 部分），Flutter 的 APK 不会自带这一份，要手动放进 `jniLibs`：

```sh
cp /opt/android-ndk/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so \
  flutter/android/app/src/main/jniLibs/arm64-v8a/
```

`/opt/android-sdk/ndk/28.2.13676358` 已经指向 `/opt/android-ndk`，Flutter 能看到 NDK，不再走合成 CMake。出 APK：

```sh
cd flutter && env GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.directory GIT_CONFIG_VALUE_0=/opt/flutter \
  CI=true FLUTTER_SUPPRESS_ANALYTICS=true \
  flutter build apk --release --target-platform android-arm64
```

`GIT_CONFIG_*` 只是绕 `/opt/flutter` 的 git 所有权检查，不改仓库配置；SDK 属主正常时可以去掉。release 现在用 debug key 签名（`build.gradle.kts` 里就是这么写的），侧载能装；正式分发再换 keystore。

## 依赖与链接

`crates/library` 的 rusqlite 在 Android 上要用 `bundled-sqlcipher-vendored-openssl`：NDK 的 sysroot 没有 OpenSSL 头，`bundled-sqlcipher` 会在 `sqlite3.c` 报 `openssl/crypto.h` 找不到。不能退化成普通 bundled：U 盘里 rekordbox 6 的 `exportLibrary.db` 也是 SQLCipher 加密的，`import/rekordbox.rs` 的 `open_encrypted` 靠 `PRAGMA key` 解密，手机上要保留这条功能。vendored 只是把 OpenSSL 静态编进来，功能不变；用 target-specific 依赖挂在 android 下，桌面保持现在的 `bundled-sqlcipher`，不要改 workspace 的默认 features。

链接上有一个真问题：NDK 28 的 libc stub 在 API 21–35 都不导出 `atexit`（21/24/28/30/35 都抽查过），它由 `crtbegin_so.o` 提供给可执行文件；Rust 的 cdylib 不链 crtbegin，vendored OpenSSL 的 `libcrypto-lib-init.o` 又引用它，所以共享库链接默认允许未定义符号、能编过，装机后 `dlopen` 失败：`cannot locate symbol "atexit"`。这不是 Android 16 才有的变化。现在 `crates/bridge/build.rs` 在 Android 下编 `src/android_atexit.c`（`atexit` 转 `__cxa_atexit`）并加 `-Wl,-z,defs`；链接已经通过，`--dyn-syms` 里 `atexit` 不再是 UND，`__cxa_atexit` 由 libc 提供，其余 UND 都落在 NEEDED 的 `libc`/`liblog`/`libOpenSLES`/`libamidi`/`libc++_shared`/`libdl`/`libm` 上。

## 启动与日志

`main()` 已经改成先 `runApp`、再异步 boot：`AppModel.beginEngineStart()` 先显示空 deck，`attachEngine` 成功后换成引擎 deck 并重放订阅、菜单和库加载，失败走 `markEngineFailed`，`AppShell` 顶部显示“Starting engine...”或“Engine offline: ...”。测试注入的 `AppModel` 不置这两个状态，横幅不出现。

Rust 侧已经做了：`bridge/src/logging.rs` 把 boot 阶段（config/audio/library/preference/ready）、panic 和 Flutter 上报的错误写到 `filesDir/pipefader/logs/bridge.log`，每行带毫秒时间戳并立即 flush；`start` 的失败和超时也落盘。打开日志后 stderr 被 `dup2` 到同一文件，cpal/audio 的 `eprintln` 和 panic backtrace 也会进来。Flutter 的 `FlutterError.onError` / `PlatformDispatcher.onError` 通过 `log_client_error` 进同一份文件。菜单 Preferences 底部的 Logs 页通过 `recent_logs` 读最近 400 行，引擎没起来也能读。

`menu.ensureLoaded()` 在 `AppModel` 构造时就会调 `midiPorts()`；ndk-context 初始化后它正常枚举，之前那个 `android_context` panic 已经不在了。真机上的 `adb logcat -s Pipefader` 能看到 boot 和 midi 行。

## 路径与配置

Android app 进程没有 `HOME`，也没有 XDG；`filesDir`（`/data/user/0/<包名>/files`）就是应用自己的目录。现在 `SessionPaths { config, cache, media_home, log_dir }` 在 `app::paths`，MainActivity 通过 `pipefader/session` 把 `filesDir/pipefader`、`/storage/emulated/0` 和日志目录交给 Dart，`frb.start` 接收并安装；`profile::default_path`、`gui_cache_dir`、`home_dir` 都先看这份路径，桌面留空时仍走 `HOME`/XDG。

首启 seed：`profile::seed` 在启动 DTO 的 `seed` 为 true 且 config 不存在时，把内建模板写到 `filesDir/pipefader/config.toml`，同时落一份同目录 `mapping.toml`；桌面不 seed，继续跑内建模板。config 落盘后 `preference` 和 `map_path_for` 都跟着它走，菜单的写操作不再报 read-only。库 DB 在 `filesDir/pipefader/library.sqlite3`，不放 cache；打开失败会写日志，不再被 `.ok()` 吞掉。

## 权限与曲库

曲库只做文件夹路径和 USB，不做 MediaStore。manifest 已经声明 `MANAGE_EXTERNAL_STORAGE`，Android 10 用 `READ/WRITE_EXTERNAL_STORAGE`（maxSdk 29）加 `requestLegacyExternalStorage`（这一档要真机确认，Android 11+ 是全文件访问的主路径）；MainActivity 通过 `pipefader/session` 暴露 `hasStoragePermission` / `requestStoragePermission`，Android 11+ 跳 `ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION`，Android 10 弹旧版运行时权限。AppShell 顶部常驻 “Storage permission needed · Grant”，AppModel 没授权时不加载库，回到前台会重查并在授权后刷新；引擎照常启动，菜单和界面可用。ColorOS 上 `adb shell pm clear` 会被拒（shell 没有 `CLEAR_APP_USER_DATA`），要重 seed 只能用系统设置清数据或卸载重装。授权后 `/storage/emulated/0` 和 USB 卷对 `WalkDir` 就是普通目录，`import/folder.rs`、标签、解码、波形都不用改。代价是 Google Play 会限制，侧载没关系。

USB 已经接上同一个扫描入口：`ScanService` 有 `volume_mounted(root)` / `volume_unmounted(root)`，桌面仍由 `usb::watch`（`/sys/block` + `udisksctl`）喂，Android 由 Kotlin 的 `StorageVolumeCallback`（API 30+）或 media 广播（API 29）拿到卷根，经 `pipefader/session` 的 `volumeMounted` / `volumeUnmounted` 到 Dart `volume_events.dart`，再走 FRB 进同一个 worker；API 30+ 在引擎起来且有存储授权后由 Dart 调 `listVolumes` 枚举一遍已挂载的卷，避免 callback 的首批事件早于 Dart handler 而丢失。两边都落成 `SourceOrigin::Usb`，扫描、列表、分析共用。没上设备，挂载/拔出和权限的组合还没验。rekordbox/Serato/VirtualDJ 的本地库路径在 Android 上不存在，`local_roots` 按存在性过滤即可，不用 `cfg`。

## 音频

cpal 0.15.3 自带 oboe 后端，编出来的 `.so` 已链 `libOpenSLES`。oboe 和 midir 一样要读 `ndk_context`，Flutter embedding 不填它时，音频 producer 会在 cpal 里 panic，producer 线程在回报前退出，表现就是 `the audio thread exited before reporting`。MainActivity 现在先 `System.loadLibrary("bridge")`，再调 `nativeInit(applicationContext)`，由 `crates/bridge/src/android.rs` 把 JavaVM 和全局 Context 交给 ndk-context。JNI 函数名要按 JNI 规则把包名里的 `_` 写成 `_1`（`Java_com_example_pipefader_1gui_MainActivity_nativeInit`）；写成字面下划线会 `No implementation found`，ndk-context 起不来，音频和 MIDI 都会挂；这一步同时让 midir 的端口枚举可用。如果音频仍打不开，bridge 会清空 `[[mixer.output]]` 再启动一次，让菜单、浏览器和 MIDI 可用，只是没声；失败原因留在 logs。内建模板是 44.1k、master `[0,1]` 加 cue `[2,3]`；手机只有立体声时不是“cue 那一路 disable”这么温和：`preferred_config` 按 4 声道找配置，找不到整个 cue output 进 `Disabled`；如果设备只报 48k，44.1k 的 master 也会 `Disabled`，结果完全没声。`profile::seed_android` 已经从同一份模板生成 48k、单 master 的 config，首次启动才写，已有 config 不会覆盖（开发期要删 `filesDir/pipefader/config.toml` 再启动）。手机插上 Party Mix 后 Android 的 media 默认路由会变成它的 USB audio；要听手机扬声器，Output 页把 master 绑到 `OPD2407`（或上机身的设备名）并重启，或者把音箱接在控制器的 master 输出上。

Output 页现在是 Master/Precue 两个大键加输出行，Add 走设备 → 通道 → 确认三级，最后一路 master 也能删。Android 上改输出拓扑不会立刻 reload：oboe 在 producer 线程开关 stream 会卡住音频回调，所以只写配置，后端在 `MenuStateDto.restart_required` 里标出来；关闭菜单时弹确认，点“立即重启”走 MainActivity 的 PendingIntent 重启，点“稍后”保留配置。桌面仍然即时 reload。`output_devices` 会按名字去重，Party Mix 下面那个 `OPD2407` 就是手机扬声器。`channel_pair` 的兜底是 `(0,1)`，留着 cue 还可能在 4 声道设备上让两路写同一对通道。cue 在手机上要么放弃，要么以后做 split cue，那要给 mixer 加输出模式。前台服务、音频焦点、后台播放放后面。

## MIDI

最终目标是 B：Android 全部交给 Kotlin 的 `MidiManager`，桌面继续 midir。当前先用 A 验证：ndk-context 由 MainActivity 的 `nativeInit` 初始化，`controller::list_ports()` 能跑；midir 自己不请求 USB 权限，MainActivity 在启动/USB attach 时对带 MIDI streaming 接口的 `UsbDevice` 调 `UsbManager.requestPermission`，授权后 midir 的 `openDevice` 才有机会成功。真机日志已经能看到 `midi: 1 port(s) ["Numark ..."]`。菜单里的 Controller 页现在能列出端口、进入详情后 Disable，或用 SAF 选一个用户 map；map 以 bytes 交给 Rust 校验并复制进 `filesDir/pipefader`，不依赖 SAF 的路径。

A 还缺热插拔回调、蓝牙 MIDI 和可读的错误信息；这些要 B。B 要把列端口、开端口、收字节、关端口一起抽成 backend（只在 bridge/controller 选实现），字节经 JNI 喂给 `controller::msg::Decoder`；`app::midi` 现在直连 midir 的 `Input`，不能只加一个 `ingest(bytes)`。走 B 后如果 midir 从 Android 依赖里摘掉，`controller::ports` 要按平台条件编译，别让 `libamidi` 继续被链进来。Kotlin↔Rust 的 JavaVM/Application 初始化已经就是 `nativeInit`，别删。

## 预填充数据

`fixtures.dart` 已经删除，`buildPeaks` 和 `AppModel` 里的 `_time`/`_updateMeter`/fixture deck 分支一起清掉了：deck 初值就是 `No Track`，浏览器初始为空，引擎失败显示离线状态，不再退回示例数据。`libraries`/`tracks`/`playlists` 改成空列表；`interaction_test` 的 library 用例改成空库断言，transport 从暂停开始，tempo 拖拽断言改成 `tempo` 而不是 bpm。web 预览现在也是空壳。

曲库文件夹可以在 Preferences › Library 或 browser 的 Add 里加。Android 用 `ACTION_OPEN_DOCUMENT_TREE` 选目录，Kotlin 把 `primary:...` / 卷 ID 转成 `/storage/...` 路径再交给后端；第三方 provider 转不了路径时会提示换本地或可移动卷。Add source 的 Library settings 会直接打开菜单的 Preferences 页。Analyse 分析当前 list，后端单 worker 顺序跑，完成后发 `LibraryChanged`。

## 建议顺序

构建链、`SessionPaths`、首启 seed、bridge 日志、异步 attach、Logs 页、权限引导、删 fixtures、Android 48k 单 master 的 seed、USB 卷事件和输出设备/通道选择都做了（minSdk 29、target-specific openssl、atexit shim、`-z defs`、APK、符号审计、`bridge.log`、离线横幅、空状态）。UI 已按大按钮/四栏 browser/后端设置分组的方案重整；剩下的是没有声时的音频路由/stream 恢复、完整 MIDI B，以及 Android 输出热重建。

## 设备测试

先清应用数据再装，`seed_android` 才会重新写 48k、单 master 的 config（旧 config 不会被覆盖）。ColorOS 的 `pm clear` 会被拒，改用系统设置清数据或 `adb uninstall` 后重装。release APK 不可调试，`run-as` 读不到私有文件，日志走根菜单的 Logs 页，或者：

```sh
adb devices
adb uninstall com.example.pipefader_gui   # 需要重 seed 时
adb install flutter/build/app/outputs/flutter-apk/app-release.apk
adb logcat -d -s Pipefader flutter AndroidRuntime > /tmp/pipefader-logcat.txt
```

要报告的东西：手机型号/Android 版本、启动后是否还显示 offline、Logs 页最后几十行、插上 USB MIDI 后有没有系统授权框、MIDI/Map 里端口数、插 U 盘后浏览器有没有出现 USB 源。

## 控制器映射

内建 map 的来源是 `controllers/numark_partymix_3.toml`（`profile::MAP_TEMPLATE`），首启 seed 也会把它写成 `filesDir/pipefader/mapping.toml`；菜单里显示为 “Numark Party Mix 3”。当前只有一个内建 map；要把 `controllers/` 里更多文件都变成内建候选，需要再做一个注册表/生成步骤。
