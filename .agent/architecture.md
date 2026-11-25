# 架构

TUI 和 Flutter 共用同一个 Rust 后端。分界很简单：会同时被两个前端用到的行为放 `crates/app`，引擎和纯数据放更底层，前端只负责输入和绘制。新增功能先想清楚属于哪一层，再决定落点。

## crates

`protocol` 是命令、配置、输出状态、波形提示这些跨 crate 的数据类型。`audio` 是实时引擎：推子、EQ、FX、time-stretch、mixer 和多输出，自己不做文件 IO。`library` 管曲库、扫描、分析和波形缓存。`controller` 管 MIDI 端口、map、router 和 guide 的数据模型。`media` 解音频和封面，`stems` 是可选分离。

`app` 是前端共用层：一份 config.toml 的读取/写回、命令解析与分派、会话状态、MIDI 连接、浏览器模型、波形投影，以及 `config::{profile, output, map, settings}`、`devices` 和 `paths`。`paths` 是前端注入的 `SessionPaths { config, cache, media_home, log_dir }`（FRB DTO 里仍叫 `log`），桌面留空时仍走 `HOME`/XDG；TUI 和 bridge 只调用这里，不复制这些逻辑。

`tui` 是终端前端，包含主界面、REPL 和 controller guide/settings；它只做终端输入、布局和绘制。`bridge` 是唯一的 FFI 边界，只做 FRB DTO、动作转发和会话线程。`flutter` 是 GUI，不直接读配置、不拼业务状态。

## 数据流

TUI 直接拿 `app` 的会话和引擎命令通道。Flutter 走 `EngineClient → crates/bridge → 会话线程/引擎`；动作不经过会话线程，所以慢查询不会卡 UI。会话线程存在的理由是 `AppState` 持有 `MidiSession`，而 midir 的连接不是 `Send`。

状态走一条 `Stream<SessionEvent>`：`Tick` 约 60Hz，带 deck transport、通道电平、波形提示列；`Loaded`、`WaveformReady`、`CoverReady`、`LibraryChanged`、`Log` 是低频事件。FX 参数附在 tick 里降频发送。滚动波形峰值走单独的 `waveform_strip` 查询，带 overscan，不在 tick 里重复传。

## 日志

bridge 把 boot 阶段、panic 和 Flutter 侧上报的错误写到 `SessionPaths.log_dir` 下的 `bridge.log`，每行带毫秒时间戳并立即 flush；没有 log 路径时只把 error 打到 stderr。打开日志后还会把进程的 stderr `dup2` 到同一个文件，cpal/audio 的 `eprintln` 和 panic backtrace 一起落盘。Flutter 的 `FlutterError.onError` 和 `PlatformDispatcher.onError` 通过 `log_client_error` 落到同一个文件；Android 上同一行还会镜像到 logcat 的 `Pipefader` 标签，`adb logcat -s Pipefader` 就能看。

## 配置

配置来源是一个字符串：真实文件路径，或内建哨兵 `BUILTIN_PROFILE = "<built-in>/config.toml"` / `BUILTIN_MAP = "<built-in>/mapping.toml"`。内建内容编译进二进制，不落盘，所有读取都经过 `profile::read_profile_text` / `read_map_text`；内建 profile 和 map 只读。Flutter 在 Android 上通过 `pipefader/session` MethodChannel 拿到 `filesDir/pipefader`，`frb.start` 把这四个路径装进 `app::paths`，并让 `profile::seed` 在首次启动时把内建 config 和 `mapping.toml` 写到私有目录（Android 用 `seed_android`，同一份模板改成 48k、单 master）；桌面不 seed，继续跑内建模板。

写配置统一用 `toml_edit`，保留注释和键顺序。`profile` 管 controller 指针和整体 profile，`output` 管 `[[mixer.output]]` 的增删/绑定，`map` 枚举 controller map 并能把用户选中的 map 校验后装进 profile 目录，`preference` 读写曲库文件夹，`settings` 管可编辑项。`settings::pages` 直接描述 Mixer / Audio / Analysis / Display 的分组和选项，GUI 只渲染；新增字段改 Rust 和 i18n，不改 Flutter DTO。GUI 通过 bridge 的 `menu_state`、`output_*`、`midi_*`、`set_midi_*`、`import_midi_map`、`disable_controller`、`library_*`、`analyse_list`、`set_setting` 调它们；TUI 直接调同一批 app 函数。

map 候选是内建 map 加 profile 同目录下能解析成 controller map 的 `.toml`，当前 map 即使不在目录里也会出现在列表。内建 map 的内容来自 `controllers/numark_partymix_3.toml`，菜单名是 “Numark Party Mix 3”；写 map 前先验证，内建哨兵写入 profile 时原样保留，不能当相对路径拼。`app::browser::playlist_tree` 是曲库树的后端来源：返回 `parent_id` 和 `has_children`，bridge 只做 DTO 映射，不再自己扁平化路径。

## Flutter

`flutter/lib` 分 `core`（theme、glyph、layout mode、logo）、`controls`（受控原子）、`units`（业务面板）、`layout`（页面编排和菜单）、`model`、`state`。`AppModel` 持有 deck 运行态、曲库和 `MenuState`；菜单的 profile/output/MIDI/settings 快照在 `MenuState`，无引擎时用一份本地默认值（一个 master、一个 `mapping.toml`）。

Flutter 不引第三方 pub 依赖，Material 用 SDK 拆出的 `material_ui`，图标全部在 `glyph.dart` 自绘。真实引擎由 `EngineClient` 接管；web 不启动引擎，界面是空状态（fixtures 已删除），本地 MenuState 仍给菜单默认值。Android 的私有路径由 `core/device_paths.dart` 通过 `pipefader/session` 取得，其余平台返回 null 让 Rust 走桌面规则；MainActivity 先 `System.loadLibrary("bridge")` 再 `nativeInit(applicationContext)`，把 JavaVM/Context 交给 ndk-context（cpal oboe 和 midir 都依赖它）；存储权限走同一个 channel，没授权时 AppModel 不加载库，AppShell 顶部给 Grant 提示并在回到前台时重查。

## 菜单现状

logo 菜单所有层级顶部贴边居中，菜单 logo 用主界面的 `LogoFaders`，从 header 的 rect 平移进来。面板宽 560（窄屏减 24），内容可滚。根页是四个 layout tile、decks tile、Controller/Output/Mixer/Preferences 四条整行大键；Logs 移到 Preferences 底部。Controller 是端口列表和端口详情（Disable、Choose a user map、map 列表），map 通过系统文件窗口选择，Android 用 SAF 读字节、Linux 用 GTK 读字节，后端校验并复制到 profile 目录。Output 是 Master/Precue 两个大键、当前输出行和两级的 Add 流程，最后一路也能删，Android 改拓扑只写配置并要求重启。Mixer/Preferences 渲染后端 `settings::pages` 的分组：Mixer 对应 `[mixer]`，Preferences 分 Audio/Library/Analysis/Display；sample rate、keylock block、stems provider 需要重启。曲库文件夹可以在 Preferences 或 browser 的 Add 里增删，后者写 `[preference.library].folders` 并触发重扫。Analyse 分析当前 list，由后端单 worker 顺序跑。Logs 读 `bridge.log` 最近 400 行，引擎没起来也能用。内建 profile 的写操作禁用。

无引擎预览只有一个 master；Android 首启 seed 也只有一个 master（48k），桌面的内建模板仍是 `main(master) + headphones(cue)`。输出拓扑改动在 Android 上由后端 `restart_required` 标记要求重启，桌面即时 reload。
