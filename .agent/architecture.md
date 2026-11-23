# 架构

TUI 和 Flutter 共用同一个 Rust 后端。分界很简单：会同时被两个前端用到的行为放 `crates/app`，引擎和纯数据放更底层，前端只负责输入和绘制。新增功能先想清楚属于哪一层，再决定落点。

## crates

`protocol` 是命令、配置、输出状态、波形提示这些跨 crate 的数据类型。`audio` 是实时引擎：推子、EQ、FX、time-stretch、mixer 和多输出，自己不做文件 IO。`library` 管曲库、扫描、分析和波形缓存。`controller` 管 MIDI 端口、map、router 和 guide 的数据模型。`media` 解音频和封面，`stems` 是可选分离。

`app` 是前端共用层：一份 config.toml 的读取/写回、命令解析与分派、会话状态、MIDI 连接、浏览器模型、波形投影，以及 `config::{profile, output, map, settings}` 和 `devices`。TUI 和 bridge 只调用这里，不复制这些逻辑。

`tui` 是终端前端，包含主界面、REPL 和 controller guide/settings；它只做终端输入、布局和绘制。`bridge` 是唯一的 FFI 边界，只做 FRB DTO、动作转发和会话线程。`flutter` 是 GUI，不直接读配置、不拼业务状态。

## 数据流

TUI 直接拿 `app` 的会话和引擎命令通道。Flutter 走 `EngineClient → crates/bridge → 会话线程/引擎`；动作不经过会话线程，所以慢查询不会卡 UI。会话线程存在的理由是 `AppState` 持有 `MidiSession`，而 midir 的连接不是 `Send`。

状态走一条 `Stream<SessionEvent>`：`Tick` 约 60Hz，带 deck transport、通道电平、波形提示列；`Loaded`、`WaveformReady`、`CoverReady`、`LibraryChanged`、`Log` 是低频事件。FX 参数附在 tick 里降频发送。滚动波形峰值走单独的 `waveform_strip` 查询，带 overscan，不在 tick 里重复传。

## 配置

配置来源是一个字符串：真实文件路径，或内建哨兵 `BUILTIN_PROFILE = "<built-in>/config.toml"` / `BUILTIN_MAP = "<built-in>/mapping.toml"`。内建内容编译进二进制，不落盘，所有读取都经过 `profile::read_profile_text` / `read_map_text`；内建 profile 和 map 只读。

写配置统一用 `toml_edit`，保留注释和键顺序。`profile` 管 controller 指针和整体 profile，`output` 管 `[[mixer.output]]` 的增删/绑定，`map` 枚举可选的 controller map，`settings` 管采样率、crossfader、cue blend、autogain 这类可编辑项。GUI 的 Menu 通过 bridge 的 `menu_state`、`output_*`、`midi_ports`、`midi_maps`、`set_midi_*`、`set_setting` 调它们；TUI 直接调同一批 app 函数。

map 候选是内建 map 加 profile 同目录下能解析成 controller map 的 `.toml`，当前 map 即使不在目录里也会出现在列表。写 map 前先验证；内建哨兵写入 profile 时原样保留，不能当相对路径拼。

## Flutter

`flutter/lib` 分 `core`（theme、glyph、layout mode、logo）、`controls`（受控原子）、`units`（业务面板）、`layout`（页面编排和菜单）、`model`、`state`。`AppModel` 持有 deck 运行态、曲库和 `MenuState`；菜单的 profile/output/MIDI/settings 快照在 `MenuState`，无引擎时用一份本地默认值（一个 master、一个 `mapping.toml`）。

Flutter 不引第三方 pub 依赖，Material 用 SDK 拆出的 `material_ui`，图标全部在 `glyph.dart` 自绘。真实引擎由 `EngineClient` 接管；web 直接不启动引擎，继续用 fixtures 和本地 MenuState。

## 菜单现状

logo 菜单所有层级顶部贴边居中，菜单 logo 用主界面的 `LogoFaders`，从 header 的 rect 平移进来。根页是 layout 选择、两个居中的 deck 数按钮、MIDI/Map、Output、Settings。Output 是 Master/Precue 分类加 CH 列表，支持刷新、增删，最后一个 Master 不能删；MIDI 页有端口列表、map 文件列表和共享刷新键；Settings 编辑 profile、采样率、crossfader、cue blend、autogain。内建 profile 的写操作禁用。

默认只有一个 master 只适用于无引擎预览；真实启动按 profile 显示，自带模板目前仍是 `main(master) + headphones(cue)`。
