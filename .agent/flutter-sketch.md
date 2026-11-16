# Flutter 草图（web 预览）

`flutter/` 是 Flutter GUI 的前端草图，包名 `pipefader_gui`，不进 Cargo workspace。草图阶段不引第三方 pub 依赖，Material 用的是 flutter 拆出来的 `material_ui` 包（SDK 自带，不是我们的选择），其余全用 SDK 控件。数据全是 `lib/model/fixtures.dart` 和 `lib/state/app_model.dart` 里的假数据，没有碰 app crate。

预览走静态构建，不跑 chrome（chroot 里没有）：`flutter build web --release`，然后 `python3 -m http.server 8080 --bind 127.0.0.1 --directory build/web`，宿主浏览器开 127.0.0.1:8080。改代码要重新 build，手机上 release build 大概 65 秒。

`flutter run -d web-server` 也行，但那个设备默认隐藏，要 `--show-web-server-device`；没有 Chrome 就接不上 DWDS，只能终端按 R 重建再手动刷新，调试构建在这台机器上更慢，所以日常还是 build + 刷新。

没有浏览器只能靠 golden 看界面：`flutter test --update-goldens test/` 会把 1440/1024/390 三个宽度、unit 菜单、搜索、library 收起、各 unit 面板画到 `test/goldens/`。测试里从 `~/flutter/bin/cache/artifacts/material_fonts` 加载 Roboto，否则全是 Ahem 方块；换机器改 `test/support.dart` 里的路径。goldens 是二进制，嫌占地方可以整个删掉，测试只留断言也能跑。

踩坑：

- MaterialApp 外面必须有 `Material`（我们在 `main.dart` 的 home 包了 transparent Material），否则文字会用 `_errorTextStyle`，黄色双下划线，看起来像字体坏了。
- 窄屏（<760）是上下堆叠，控制条宽 980 横向滚，底部有 3px 的滚动提示；浏览器左栏在 <560 自动隐藏。
- 假数据的波形是按拍生成的衰减脉冲，不是真音频；接入 app 时 `AppState` 还缺 artist/album/cover（现在只有 titles + DeckState），这需要先在 app 侧补快照。
- 主题、间距、字号只在 `lib/theme.dart` 里定义，其它文件不许写死颜色。

宽屏高度按 deckinfo : 两条波形 : control = 1 : 2 : 2，browser 吃剩下的高度（所以改 deckH 一处，波形和 control 跟着走）。页面底色是 `theme.dart` 里的 bgTop→bgBottom 渐变，控件再往上抬两阶（surface / surfaceHi / track），不要退回纯黑。推子和 mixer 共用 `widgets/bar_fader.dart`：未按时 2px 细槽 + 高亮已走长度，按住后细槽展开到手柄宽度，手柄宽度跟着列宽走。

宽屏现在是分段灰度，不再是一张渐变：header + deckinfo + control 用 `T.band` (#1b1b1b)，waveform 条带用 `T.wave` (#0b0b0b)，browser 用 `T.browser` (#131313) 夹在中间；每一段都是通栏 ColoredBox，段与段之间不留空隙靠色阶分隔。beatctl 按 1116flutter.md 的新设计：loop 行 `- 4 loop +`、`in | call | out` 行、jump 行 `< 16 jump >`，jump 的数字是个按键，点开选 1/2/4/8/16/32；loop 的 -/+ 只改 loop 长度。unit1 固定 pads 没有名字，unit2 的名字在顶部和 padmode 同一行。

宽屏高度：deckinfo 72、两条波形各 72、control 144（合计 72:144:144 = 1:2:2），browser 吃剩余；矮视口才滚动。deckinfo 字体：artist 10 / title 18，已播放/剩余 12，tempo 10 / bpm 15，key 15，key 和 sync 跨前两行。beatctl 是一个三列网格（左键列 28–44：减/in/小于；中间值列 56–140：值/call/jump；右键列：加/out/大于），三行共用一份列宽，数字变长不会挪按键；jump 的数值键点开选 1/2/4/8/16/32。波形区只有一对缩放键，叠在第一条波形左上，后面两条共用。
