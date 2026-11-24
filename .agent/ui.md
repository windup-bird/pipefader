# UI

## 风格

深色、高对比、无卡片、无边框，只有封面用 `T.radiusCover` 的小圆角。颜色、字号、间距只从 `core/theme.dart` 的 `T` / `Ty` 取；需要新色值先加 token，不在控件里写死。图标全部 `glyph.dart` 自绘，不引 icon font，也不加第三方 pub 依赖。

按钮统一 `PanelButton`：无圆角，idle 比背景稍亮，active 用 `T.lit`，hover/pressed 有轻微光影。方形图标键用 `GlyphButton`，推子用 `BarFader` / `Crossfader` / `ParamBar`，电平用 `LevelMeter`。做新控件前先查 `controls/`、`units/`、`layout/menu/`，能复用就不复制。

菜单里的英文标题和标签用首字母大写，不用全大写。`core/format.dart` 的 `titleCaseWords` 不做 deck 控制的例外；`PanelButton.rawLabel` 让菜单键保留标题大小写，所以 Settings 里的 `Cue` 不会变成 transport 的 `CUE`。`capitalizeWords` 仍然留给 deck 的 `CUE`/`BPM`/`PAD`/`TAB`。

## 布局

`LayoutMode` 四种：full、landscape、stacked、allInOne。auto 规则是竖屏走 stacked；否则 full 放不下 browser 三分之一高度时走 landscape；其余 full。allInOne 只由显式布局选择触发。full 用两个 deck、可切 2/4；phone 系 2/3。页面分派集中在 `app_shell.dart`，各布局只组合已有控件。

full 的纵向顺序是 header、deck info、waveform、control、browser；phone 是 header、逐 deck 的 info + waveform、control、browser。尺寸不要散落在页面里，优先进 `layout_metrics.dart` 或由父级 constraints 决定。

## 菜单

所有层级都在屏幕顶部贴边居中，子页共用同一个 frame 和同一块 logo，不另开悬浮层。面板宽度约 440（窄屏减 24），顶部取 safe area，内容过高时整体滚动。打开是 scrim 淡入 + 面板下移淡入，关闭反向；页面切换是 `AnimatedSize` + 内容单向淡入/位移，不做回退堆叠。

根菜单是 layout 四选一、居中的 `2 Decks` / `4 Decks`、`Midi / Map`、`Output`、`Settings`、`Logs`。菜单 logo 从主界面 `LogoFaders` 的全局 rect 平移到顶部目标 rect，关闭飞回；尺寸用 `LogoFaders.widthFor`，拿不到 rect 时退回淡入。

子页面共用 `MenuPageHeader`、`MenuRefreshButton`、`MenuSelectRow`、`MenuChoice`、`MenuSectionLabel`、`MenuStatusLine`。Output 用左侧 Master/Precue 分类键和右侧通道列表，通道行显示名称、CH/设备、删除键，底部先选 Device 和 Channels 再 Add；最后一路 master 也能删。Android 改拓扑只写配置，页脚用 `Restart app to apply output changes` 提示重启。MIDI 用同样的 header/刷新/选择行，端口和 map 都是列表，map 当前项打勾。Settings 是可编辑行列表，行控件继续用 `MenuChoice`，文案由页面传成标题大小写，不再二次转换。

菜单的状态都在 `MenuState`：outputs、devices、当前角色、待添加的 device/channels、端口、map 列表、settings、busy/error、`restartRequired`（来自后端 DTO）。页面只读它和回调 `EngineClient`，不在控件里写配置文件。

## 动画

时长控制在 150–220ms，曲线 `easeOutCubic`/`easeOut`，不要弹跳。菜单打开 220ms、关闭 150ms，页面内容淡入 150ms，高度过渡 180ms，hover 80–120ms。刷新键在 `MenuState.refreshing` 期间旋转，结束后停回 0。新增动画先考虑是否能由 `AnimatedSize` / `AnimatedContainer` / `TweenAnimationBuilder` 完成，不轻易引入 controller。
