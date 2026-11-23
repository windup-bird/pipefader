# Flutter 绑定（FRB）

`crates/bridge` 是唯一的 FFI 边界，Flutter 只依赖它，不直接碰 `protocol::Command`。引擎命令仍是原来的 47 个 variant，桥接层收敛成约二十个动作和几个查询；字符串 dispatch 留给 TUI/REPL，GUI 不走它。

## 结构

```
Flutter EngineClient (lib/bridge/engine.dart)
  → 生成的 RustLib / api.dart
  → crates/bridge (cdylib)
       ├─ 会话线程：AudioPipeline + Dispatcher + AppState + MIDI
       └─ 查询：LibraryDb / waveform 缓存 / cover 缓存
```

会话线程不是多此一举：`app::AppState` 里有 `MidiSession`，midir 的连接是 `!Send`，不能塞进全局 `Mutex` 给 FRB 的工作线程。因此可变状态只住在那一个线程，FFI 线程只发 `StateRequest` 或直接往引擎命令通道塞动作。动作不经过会话线程，所以波形/扫描慢的时候 UI 输入不会被卡住。

状态走一条 `Stream<SessionEvent>`：`Tick` 60Hz（每 deck 的 transport + 通道电平 + 波形提示列），`Loaded`/`WaveformReady`/`CoverReady`/`LibraryChanged`/`Log` 是低频事件。FX 槽只在每 6 个 tick（10Hz）附带一次，避免 60Hz 时把整套参数表重复推过去。滚动波形的峰值列走单独的 `waveform_strip` 请求（带 overscan），不占 tick；整轨峰值只在概览/兼容路径取一次，仍是 16384 列六个 u8 带；封面是 48px RGBA。

滚动波形的 beat/bar、cue、hot cue、loop 起止和 loop-armed 列都由 Rust 按 UI 最后一次上报的宽度/缩放算好，放在 `DeckTick.wave` 里。Flutter 只在布局或缩放变化时调用 `set_wave_view`，不在每帧做投影。`WaveHints.start_frame` 是投影的左边界，波形和标记共用它，避免本地插值让两者错位。概览的 loop/cue 标记在 Flutter 里按总帧比例画，数据来自同一份 `DeckTick`。

浏览器行是 `LongPressDraggable`，拖到任意 `DeckInfo` 上载入；点按只做选择，不再挂 `onDoubleTap`（双击识别会把单击拖慢一个超时）。

## 生成

```
~/.cargo/bin/flutter_rust_bridge_codegen generate --config-file flutter_rust_bridge.yaml
```

生成物 `crates/bridge/src/frb_generated.rs`、`flutter/lib/bridge/generated/` 都提交。改 `api.rs` 后必须重跑；Rust 和 Dart 的 `flutter_rust_bridge` 版本锁在 2.13.0。

`SessionEvent` 故意是“扁平 struct + 简单 enum”而不是带负载的 enum，否则 FRB 会要求 Flutter 项目引入 `freezed`。以后要加复杂事件，优先加字段。

## 波形的统一后端

`app::waveform` 是 TUI 和 GUI 共用的唯一投影层：`WaveViewport`（宽度、frames/pixel、playhead）进去，`WaveFrame`（六组峰值列 + beat/bar/loop/cue/hot cue 列）和 `WavePalette` 出来。TUI 的 braille 和 Kitty raster 都已改成消费这个 frame；Flutter 的滚动波形改成向桥接要一条带一屏 overscan 的 `WaveStrip`，自己只画 Canvas，不再做 16384 列的全轨二次采样。

这样滚动波形的分辨率就是当前 `frames_per_pixel`：默认 340，最细 256（`library::Waveform` 最细 bucket，TUI 的缩放下限也是它）。长轨不会再因为全轨固定列而变成 512/1024 帧一列。概览的 folded/normalised profile 也来自 `app::waveform::overview_profiles`。

颜色只从 `app::waveform::WavePalette` 来：低/中/高读 `[preference.waveform]`，beat/bar/loop/center/playhead/cue/hot cue 是同一组固定 RGB。TUI 把 `Rgb` 转 ratatui `Color`，Flutter 通过 `wave_palette` 取 ARGB；两边不再各自维护一套常量。

`WaveStrip` 带一屏 overscan，Flutter 在 playhead 还处在中间一半时不重取；缩放或窗口宽度变化才清空缓存。`app::waveform::markers` 单独存在，60Hz tick 只取提示列，不重复算峰值。

## 构建

Linux 的 `flutter/linux/CMakeLists.txt` 会执行 `cargo build --release -p bridge`，把工作区 `target/release/libbridge.so` 拷到 bundle 的 `lib/`；runner 的 `$ORIGIN/lib` rpath 让 Dart 的 `DynamicLibrary.open('libbridge.so')` 找到它。不要用 `frb integrate` 生成 `flutter/rust/`，那会出现第二份 workspace。

Android 还没接线：需要 SDK/NDK、`cargo-ndk`，并把 `.so` 放进 `jniLibs`。web 构建能过，但 `main.dart` 在 web 上直接跳过引擎，继续用 fixtures。

## 几个行为选择

- GUI 的曲库缓存放在 `$XDG_CACHE_HOME/pipefader`（或 `~/.cache/pipefader`），不是 TUI 的相对 `.cache`，否则从 bundle 启动会把缓存写进应用目录。`PIPEFADER_CACHE` 仍可覆盖。
- 没有 `[[controller]]` 时不连 MIDI；配置了的控制器由会话线程自动 attach，失败只记一条日志。
- 配置的拓扑没有用户 FX 槽时，桥接给每个 deck 补 `echo` + `reverb`（初始 disabled），否则 Flutter 的 FX 面板没有东西可画。unit 1 只开 pad 单元，unit 2 只开 mixer/tempo/fx。
- GUI 没有单独的“分析”按钮，所以浏览器加载一轨且没有导入/缓存 grid 时，后台自动跑一次分析；TUI 仍按配置的 `auto_analyse`。
- 曲库扫描完成通过 `AppState.library_dirty` 通知，Dart 收到 `LibraryChanged` 后保留当前列选择刷新。文件夹源会拍平成“有曲目的列表”，因为 sketch 的 browser 只有一列 list。

## 验证

`cargo run -p bridge --example probe` 是无头冒烟：起引擎、拿 meta/logs、关掉。Flutter 侧跑 `flutter test test/interaction_test.dart test/widget_test.dart`；golden 测试因为仓库里缺 `test/goldens/*.png` 本来就会失败，与绑定无关。
