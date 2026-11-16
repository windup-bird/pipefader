# 配置的两个来源

profile（config.toml）和 controller-map（mapping.toml）各有内建和用户两个来源。内建是 `include_str!` 嵌进二进制的模板，不落盘；`load_or_create` 删掉了首次启动复制模板到用户目录的行为，没有用户文件就用内建在内存里起（`audio::reference_toml()` / `profile::MAP_TEMPLATE`）。

实现用的是“保留来源 id 的字符串”而非新类型，免得改遍 Session/Dispatcher 的字段。两个哨兵 id 在 `app::config::profile`：`BUILTIN_PROFILE = "<built-in>/config.toml"`、`BUILTIN_MAP = "<built-in>/mapping.toml"`。`is_builtin` 判断，`source_label` 显示成 `built-in`，`read_profile_text` / `read_map_text` 把来源解析成文本（map 还要带 include 的 base）。`map_path_for(BUILTIN_PROFILE)` 特意返回 `BUILTIN_MAP`，这样内建会话默认就用内建 map。所有读配置文件的地方都走这两个 resolver，`read_live_config`、`config/mixer reload`、`read_map_pair`、settings 的 `read_doc` 都改了。

TUI 这边 `FilePicker::with_builtin(filename, source)` 在目录列表顶部加虚拟行，选中返回哨兵 id；视图里内建行显示 `<built-in> <filename>`、用户文件显示 `<user> <filename>`，所以内建后面是具体文件名（config.toml / mapping.toml），后期加多个内建只要多挂几行。settings 根节点并成三行 controller / output / profile：mixer/live/preference 全删，统一成 profile 一个选择器（挂 `BUILTIN_PROFILE`），controller map 仍挂 `BUILTIN_MAP`。`Outcome` 用 `profile: Option<String>`，选中后 `input.rs::switch_profile` 一次重载四项——mixer 拓扑/text、live、preference 主题、从新 profile 的 `[[controller]]` 重建 session 并重连 MIDI（app::config::profile::load_source / sessions_from）。字段写入（output 设备绑定）对内建拒绝并提示只读。analysis/auto_analyse 和时钟类维持原样（启动读一次、下次启动生效），没动。

`--guide` 不再预先把 MAP_TEMPLATE 写盘；传进来的是内建标记或路径不存在时，guide 用 `Guide::open_text` 从内建文本打开且保持未保存，显式 Save 才写文件。路径不存在但不传标记时维持旧行为（空 guide + 提示），测试 `test_session()` 依赖这个。

踩坑：guide 测试用相对路径 `does-not-exist.toml` 当 fixture，早期版本曾把它写成真实文件污染了 `crates/tui/`，导致“文件存在”分支被触发、两个测试挂掉。删掉该文件即可。改这块时留意别让测试往 crate 根写文件。
