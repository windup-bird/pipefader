# 项目指令

## 工作方式
动手写代码或改文件之前，先把方案说出来：改哪些文件、大致怎么做、有什么取舍。方案我确认后再执行。遇到难点、命令执行异常久、拿不准的细节、或者有多种合理做法时，停下来问我，不要自己挑一个方向就往下走。宁可多问一句，也不要事后返工。不确定的事情不要猜。

## 架构与边界
`crates/app` 是 TUI 和 Flutter 共用的业务层，配置、会话、命令分派、设备/输出/map、MIDI 连接和波形投影都放这里。`crates/tui` 只做终端输入和绘制，`crates/bridge` 只做 FRB DTO 和动作转发，`flutter/` 只做界面和交互。新增跨前端行为先落 app，再让两边调用；不要在 tui 或 bridge 里复制配置解析、设备枚举、输出或 map 写入这类逻辑。

配置统一走 `app::config`：`profile` 管一份 config.toml 和 controller 指针，`output` 管 `[[mixer.output]]`，`map` 管 map 候选，`settings` 管可编辑项。内建 profile/map 只读，写文件用 `toml_edit` 保留注释；内建哨兵不要当普通相对路径拼坏。

## 代码与 UI
简洁高效，复用优先。颜色、字号、间距只取 `core/theme.dart` 的 `T` / `Ty`，自绘图标走 `glyph.dart`，不引第三方 pub 依赖。做按钮、推子、菜单前先看 `controls/`、`units/`、`layout/menu/` 里有没有现成的；菜单共用 `MenuChoice`、`MenuPageHeader`、`MenuRefreshButton`、`MenuSelectRow`。

菜单所有层级顶部贴边居中，logo 沿用主界面的 `LogoFaders` 并做平移；标题和标签首字母大写，不整句全大写（trans 的 `CUE` 等既有约定除外）。新菜单行为通过 `MenuState` / `EngineClient` 走 app API，不在页面里拼配置。

## 命令边界
本机默认使用`fish` `pnpm`而不是`bash` `npm`。

需要 sudo 的命令一律给我来运行，不要尝试绕开。不要改文件权限、不要用用户目录里的变通做法规避权限问题。装不了系统包就直说，把需要装的东西列出来。

`git`不执行 `push`，不私自 `commit`、`switch`、`merge`、`rebase`。不改 remote URL，不改 git config，不加 `Co-authored-by` 或其他署名。需要提交时把命令给我，由我来跑。commit message 用中文，简短直白。

工作区外的文件可读不要编辑，除非询问后我同意。

## 测试
先 `cargo check` / `dart analyze`，再跑受影响用例；完整的 `cargo test -p app -p tui` 和 Flutter 两个 widget 测试放到收尾。菜单、文案这类局部改动优先用 `--plain-name` 过滤，不主动生成 golden 或截图。测试命令、本机 Flutter SDK 只读环境的处理、FRB 重生成见 `.agent/testing.md`。

## 文档
`.agent/` 只留三份现状文档：`architecture.md`、`ui.md`、`testing.md`。它们供 agent 自查，简明扼要，节省 token；旧的方案稿和过期计划直接删，不在这里堆历史。

不要主动更新 README、docs、wiki，除非我明确要求。需要写时用自然段说清楚，简明扼要，别铺开分点列表和表格，加粗能不用就不用。读起来像人写的笔记，不要像模板生成的说明书。
