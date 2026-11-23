# Android 构建与适配

只做 arm64-v8a，产物是 `flutter/build/app/outputs/flutter-apk/app-debug.apk`，里面 `lib/arm64-v8a/libbridge.so` 是交叉编译的 Rust 桥。本机 Flutter SDK（`~/flutter`，3.51.0-0.2.pre）在 arm64 Linux 上没有 release 的 `gen_snapshot`，只能出 debug APK（Dart 走 JIT，Rust 是 release），release 得换 x86 主机或 CI。

## 依赖与链接

`crates/library` 的 rusqlite 要用 `bundled-sqlcipher-vendored-openssl` 才能在 Android 上编过：wrapper 的 sysroot 里没有 OpenSSL 头，`bundled-sqlcipher` 会在 `sqlite3.c` 处报 `openssl/crypto.h` 找不到。不能退化成普通 `bundled`，rekordbox 6 的 `exportLibrary.db` 是 SQLCipher 加密的，`import/rekordbox.rs` 的 `open_encrypted` 靠 `PRAGMA key` 解密。vendored 只是把 OpenSSL 静态编进来，功能不变。现在 main 上是临时改、编完还原；应该改成 `[target.'cfg(target_os = "android")'.dependencies]` 里单独开，桌面构建不受拖累。

链接还有一个真问题：Android 16 的 bionic 不再导出 `atexit`，`libc.so` 里只有 `__cxa_atexit`（`/apex/com.android.runtime/lib64/bionic/libc.so` 和 NDK 21–35 的 stub 都核对过），而 vendored OpenSSL 的 `libcrypto-lib-init.o` 仍引用 `atexit`；共享库链接默认允许未定义符号，所以编译能过，装机后 `dlopen` 直接失败：`cannot locate symbol "atexit"`。两条出路：给 bridge 导出一个 Android 下的 `atexit` 转发到 `__cxa_atexit`（试过，`.so` 里符号定义正常、其余导入也都存在），或者给 OpenSSL 配 `no-atexit`（要 patch `openssl-src`，最干净但麻烦）。另外建议给 wrapper 加 `-Wl,-z,defs`，让这类缺符号在链接期就报出来，而不是等到手机上。

目前的状态：只加 atexit shim 之后 dlopen 过了，但 app 反而起不来，根因没定位（没有日志，只能猜是 boot 卡在 cpal/oboe、`menu.ensureLoaded()` 里 midir 的 panic，或原生崩溃），改动已回滚。所以下一步先做日志，再谈功能。

## 启动与日志

`main()` 现在先 `await EngineClient.start()` 再 `runApp`，而 `session::start` 最多等 30 秒；Android 上如果音频或别的 boot 步骤卡住，就是一段白启动画面。应该改成先出界面、异步起引擎，失败时显示明确的离线状态。Rust 侧要有 panic hook 和 boot 错误落盘（`filesDir/pipefader/logs`），Flutter 侧把启动异常和未处理错误也写进去，界面上能看最近几条。没有 adb 的环境里，这是唯一能定位问题的手段。

## 路径与配置

Android app 进程没有 `HOME`，也没有 XDG。这不是「绕开用户目录」的问题：`Context.getFilesDir()`（`/data/user/0/<包名>/files`）就是应用自己的目录，配置放这里是 Android 的常规做法，用户看不到；要让用户改文件只能走 SAF 导入导出，或者用应用内的菜单编辑（我们已经有）。

现状：`profile::default_path()` 返回 `None`，会话跑内建模板，而内建模板是只读的，`settings::set`、`output_*`、`set_midi_port` 都会报 `the built-in profile is read-only`，等于手机上菜单改不了任何设置；`gui_cache_dir()` 也是 `None`，库 DB 打不开，`library_roots()` 返回 `the library is not available`，Flutter 侧就停在预填充数据上。

方案：首次启动把内建模板写到 `filesDir/pipefader/config.toml`（桌面保持现在的「不落盘」），库 DB 也放 `filesDir`，别放 cache（会被系统清掉，清了就得重扫）。路径传递两条路：MainActivity 用 MethodChannel 把 `filesDir`/`cacheDir` 给 Dart，再扩 `frb.start(configPath, cacheDir)`（要重跑 FRB codegen）；或者在 Kotlin 里初始化 `ndk-context`（这个 MIDI 那边也要用），让 Rust 自己 JNI 调 `getFilesDir()`。前者边界清楚，后者一份初始化两个用途，但 Android 细节会渗进 Rust。

多端统一的做法是把平台差异压到三个注入点，`app` 和 `library` 里不出现 `cfg(android)`。第一是会话路径，用 `SessionPaths { config, cache, media_home }`，TUI 从 `PIPEFADER_CONFIG`/`XDG_*`/`HOME` 填，bridge 从 Dart/Kotlin 填；`media_home` 是 `~` 的展开目标，桌面是 `$HOME`，Android 是 `/storage/emulated/0`，于是同一份 `config.toml` 里写 `folders = ["~/Music"]` 两边都成立。第二是卷事件，见下一节。第三是权限，只在 Android 侧有，表现为启动时的一次性授权引导。

## 曲库

曲库只做文件夹路径和 USB，不做 MediaStore，`MANAGE_EXTERNAL_STORAGE` 作为必需权限：manifest 声明，首次启动用 `ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION` 引导去设置里授权，没授权时界面明说并停止扫描；授权后 `/storage/emulated/0` 和 USB 卷对 `WalkDir` 就是普通目录，`import/folder.rs`、标签、解码、波形都不用改。代价是这个特殊权限上 Google Play 会被限制，侧载没关系。

USB 那块把 `ScanService` 拆出 `volume_mounted(root)` / `volume_unmounted(root)` 两个入口：桌面由 `usb::watch`（`/sys/block` + `udisksctl`）喂，Android 由 Kotlin 的 `StorageManager.getStorageVolumes()` + `StorageVolume.getDirectory()`（API 30+）或 `ACTION_MEDIA_MOUNTED` 拿到卷根后喂同一个入口，两边都落成 `SourceOrigin::Usb`，后面的扫描、列表、分析完全共用。rekordbox/Serato/VirtualDJ 的本地库路径在 Android 上不存在，`local_roots` 按存在性过滤即可，不用 `cfg`。

## MIDI

midir 0.11 确实有 Android 后端（JNI + AMidi），能力不是问题，缺的是几块只有 Kotlin 能给的东西。第一个是身份：`MidiInput::new` 走 `jni_min_helper`，`jni_get_vm()` 最后落到 `ndk_context::android_context()`，而这个全局在 Flutter embedding 里没人填，`expect("android context was not initialized")` 直接 panic；`controller::list_ports()` 在菜单加载时就会调用，所以现在这一步必炸。补法是在 MainActivity 里 `System.loadLibrary("bridge")` 后调一个 JNI 入口，把 `JavaVM` 和 `Application` 交给 Rust，里面执行 `ndk_context::initialize_android_context`。

第二个是 USB 权限：`MidiManager.openDevice` 要求 app 已持有该 USB 设备权限，权限框只能由 Activity 用 `UsbManager.requestPermission(device, PendingIntent)` 弹，midir 在 Rust 线程里弹不出来；没授权时它只会把失败报成 `InvalidPort`，看不出是权限问题。第三个是热插拔：midir 全平台都没有设备增删回调，只能重新枚举，Android 的 `MidiManager.registerDeviceCallback` 才有真正的插拔事件。第四个是蓝牙 MIDI：只有 `MidiManager.openBluetoothDevice` 支持。另外 `libamidi` 是 API 29+，`.so` 直接 NEEDED 它，等于 minSdk 从 24 抬到 29。

两条路。A，Kotlin 补 ndk-context 初始化、USB 权限和插拔通知，剩下的枚举和读取继续交给 midir；改动最小，USB 控制器能先跑通，缺点是错误信息糊、没有蓝牙、minSdk 29。B，Android 侧全部交给 Kotlin 的 `MidiManager`：找设备、弹权限、听插拔、读字节，字节经 JNI 直接喂给 `controller::msg::Decoder`，桌面仍然走 midir。不管选哪条，先把 `app::midi` 的边界统一成 `ingest(bytes)`（解码、映射、往 dispatcher 发命令都在这），桌面 midir 的回调和 Android 的字节来源都调它，将来换实现上层不用动。A 只适合 USB + Android 10+ 的快速验证，MIDI 是必备功能的话最终按 B 收口。

## 音频

cpal 0.15.3 自带 oboe 后端，编出来的 `.so` 已链 `libOpenSLES`，理论上有声，但还没在设备上验证。内建模板是两路输出：master `[0,1]` 加 cue `[2,3]`；手机只有立体声，cue 那路会被判成不支持然后 disable（不致命），master 正常。Android 应该用单独的模板：`sample_rate = 48000`（AAudio 上 44.1k 经常打不开），只留一个 master `[0,1]`。cue 在手机上要么放弃，要么以后做 split cue，那要给 mixer 加输出模式。前台服务、音频焦点、后台播放都放后面。

## 预填充数据

`flutter/lib/model/fixtures.dart` 是预填充数据的唯一来源，可以整体删掉：连同 `AppModel` 里的 `live` 分支、`_time`/`_updateMeter` 模拟推子和 `buildDecks()`，deck 初值就是 `No Track`，浏览器初始为空，引擎失败就显示离线状态，不再退回示例数据。影响面：`interaction_test` 只有一处用到 fixtures 的 `'USB'` 文本，其余是布局用例；`golden_test` 本来缺参考图；web 预览会变空壳，因为 web 上本来就没有引擎。

## 建议顺序

先做最小可启动：SessionPaths 注入、配置落盘、All files access 授权引导、MIDI 的 panic 兜底（Android 上 `list_ports` 先返回空或走 A 的初始化）、atexit、日志落文件、删 fixtures 的空状态，验证引擎 tick、波形和菜单；然后验音频、加 Android 模板；再补文件夹扫描和 USB 卷事件；最后做 MIDI（先 A 验证，再按 B 收口）。
