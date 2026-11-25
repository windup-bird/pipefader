# UI

## 风格

系统字体，不打包字体文件；字号、字距只从 `core/theme.dart` 的 `Ty` 取。正文和标签不做宽字距，只有小号 section label 保留；数字用 tabular figures，但不再靠字距模拟等宽。颜色、间距、圆角仍只从 `T` 取，封面之外不出现圆角。

图标全部在 `core/glyph.dart` 自绘，统一 24 网格、约 1.6px 描边、圆帽圆连接；布局、deck 数、controller、output、mixer、library、folder、usb、analyse、add 都在同一套网格里。返回键是带杆的 ←（不是 chevron），勾选和刷新单独加粗；刷新键只在 glyph 上旋转，键面不转。

按钮统一 `PanelButton` / `GlyphButton`。`PanelButton` 除了文字，还能带 `glyph`、`subLabel` 和 `iconAxis`：横向是图标在左，纵向是图标在上，根菜单的 layout/deck tile 就用纵向。菜单行、设置行、输出行都落在同一张 `keyFace` 上，不再各自画 hover 行。

## 文案

固定文案在 `core/i18n.dart` 的 `L10n` 里，中英跟随系统：`zh*` 走中文，其余走英文。`PipefaderApp` 监听 `didChangeLocales`，通过 `L10nScope` 下发。设备名、map 名、文件路径和 Rust 返回的错误保持原文，不翻译。英文仍用首字母大写；中文不做大小写转换。

## 布局

`LayoutMode` 四种不变：full、landscape、stacked、allInOne；auto 仍是竖屏 stacked、full 放不下 browser 三分之一时 landscape、其余 full。full 的 browser 是四栏：library、playlists、tracks、right 空占位；左右栏 toggle 用宽度动画展开/收起，宽度不够时直接隐藏。phone 仍是 library → lists → tracks 的单列 drill-down。

browser 顶栏宽 44，按列切段：library 段放 rescan 并随 library 收起，lists 段放 library toggle 和当前库名（library 展开后 toggle 自动右移到 lists 左缘），tracks 段放状态、Analyse、搜索和右栏 toggle（右栏展开后 toggle 移到 tracks 右缘），最右是空的 right 段。按钮间隔统一 8–10。搜索仍占满整条 bar，带 library/list 两个范围下拉；Analyse 分析当前 list，后端单 worker 完成后发 `LibraryChanged`。library 栏顶部的 Add 打开来源选择：文件夹、USB/可移动卷、Library settings。

lists 栏是树，不是扁平路径：后端 `app::browser::playlist_tree` 返回 `parent_id` 和 `has_children` 的节点，前端按展开状态缩进渲染；folder 有子节点时点行展开，叶子点行载入 tracks。空 folder 也保留，因为下面可能还有子节点。

## 菜单

所有层级顶部贴边居中，logo 继续用主界面的 `LogoFaders` 从 header rect 飞入，关闭飞回。面板宽 `min(560, screen-24)`，顶部取 safe area，内容过高整体滚动。

根页顺序：四个 layout tile、decks tile、Controller/Output/Mixer/Preferences 四条整行大键。Logs 不再占根页，放在 Preferences 底部。子页共用 `MenuPageHeader` 的 back/title/refresh；header 固定，只有下面内容滚动，logo 也固定。刷新只重新探测设备或重新读盘，不承担“应用”。

Controller 是两级：端口列表，点进某个端口后是 Disable、Choose a user map、map 列表。map 通过系统文件窗口选择，Android 用 SAF 读 bytes，Linux 用 GTK 读 bytes，后端校验后复制到 profile 目录并写回指针。Output 是 Master/Precue 两个大键、当前输出行和 Add；Add 走设备 → 通道 → 确认三级，垃圾桶键与左侧行同高。Controller/Output 不再在底部放状态提示。Mixer 和 Preferences 由后端 `settings` 分组描述渲染，Preferences 内分 Audio / Library / Analysis / Display，字段直接写 profile.toml；设置项一行显示，左侧标签、右侧选项键；sample rate、keylock block、stems provider 用 `*` 标重启项。

## 重载与重启

Mixer 和设置项写入后，桌面由后端即时 reload，不设“应用”键。Android 的输出拓扑仍只写配置，`MenuStateDto.restartRequired` 在关闭菜单时弹确认：Android 可以立即重启，桌面只能提示手动重启。sample rate 等需要新进程的项同样走这个确认。`MenuState.reloadProfile` 在 Preferences 打开时重新读盘，保证浏览器里新增的曲库文件夹能出现在设置页。

## 动画

时长 150–220ms，曲线 `easeOutCubic`/`easeOut`，不弹跳。菜单开 220ms、关 150ms，页面内容淡入 150ms，高度/栏宽 180ms，hover 80–120ms。刷新键在 `MenuState.refreshing` 时只旋转图标，不旋转键面。新增动效优先用 `AnimatedSize` / `AnimatedContainer` / `TweenAnimationBuilder`，不轻易加 controller。

## stacked 的 browser

进入浏览模式时，deck info 的高度仍按“控制带存在时每个 section 的高度”算，只把下方 browser 撑开，不再把 info 改写成 `stackedMaxInfoH`；`DeckInfo` 的字号和行高因此保持不变。
