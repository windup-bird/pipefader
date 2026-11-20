# flutter 前端设计

flutter/ 是 GUI 的前端草图，包名 `pipefader_gui`，不进 Cargo workspace。不引第三方 pub 依赖，Material 用 SDK 拆出的 `material_ui`。数据全部来自 `model/fixtures.dart` 和 `state/app_model.dart` 的假数据，不碰 app crate。当前只做前端草案和 web 预览，不写后端绑定；控件尽量拆成可复用件，方便后期换皮肤。

---

## 目录

```
lib/
  main.dart            入口：MaterialApp + 透明 Material 包 AppShell
  core/                 无业务依赖的基础层
    theme.dart          T（颜色/几何）+ Ty（字号），唯一来源
    format.dart         clock / shortClock / bpmText / tempoText
    theme_scope.dart    DeckTheme / DeckThemeScope / deckColors
    layout_mode.dart    LayoutMode 枚举 + autoLayout
    layout_metrics.dart 布局分段尺寸的唯一来源：full 定死，其余 flex
    device.dart         keyFace / slotFace / panelFace + FaderHandle
    glyph.dart          自绘 Glyph / GlyphKind
    logo.dart           LogoMark / LogoFaders TT 标
  controls/             纯受控原子，不引用 model/state，只吃值和回调
    buttons.dart        PanelButton / GlassKey / GlyphButton / HoldKey / ModeTabs
    bar_fader.dart      BarFader 竖向推子（通道、EQ 共用）
    fader.dart          Crossfader 横向交叉推子
    pad.dart            Pad 单键
    param_bar.dart      ParamBar 横向参数推子
    meter.dart          LevelMeter 电平
    cover.dart          CoverArt 封面占位（seed 决定构图）
  units/                吃 model/state 的业务组合件
    unit_header.dart    面板上方的 unit tab + 齿轮
    unit_menu.dart      showChoiceMenu / showUnitMenu 扁平弹层
    unit_body.dart      UnitKind → 面板的分派
    pad_grid.dart       2x4 八宫格 PadGrid
    tempo_control.dart  TempoControl + TempoRuler
    deck_picker.dart    DeckPicker / DeckButton
    transport_keys.dart TransportKeys + PlayButton
    waveform.dart       Waveform 滚动波形（业务封装）
    panels/             pads / tempo / mixer / fx / mixer_max / fx_name
  layout/               只做编排：四种布局 + deck_info / header / control 等
    app_shell.dart      页面骨架，按 LayoutMode 分派四种布局
    browser_view.dart   phone 系共用的 browsing 页面
  model/
    deck.dart           DeckView / UnitKind / PadMode
    library.dart        LibEntry / ListEntry / TrackRow
    peaks.dart          波形峰值数据
    fixtures.dart       两组 deck、library、playlist、tracks 假数据
  state/
    app_model.dart      AppModel（ChangeNotifier）+ DeckRuntime
```

---

## 数据

DeckView 是静态快照：artist / title / album / key / bpm / sampleRate / totalFrames / firstBeat / peaks / coverSeed / tempoRange。

DeckRuntime 是运行态：frame / playing / tempo / nudge / sync / padMode / hotCues / loopIndex / jumpIndex / unitInner / 四段 EQ / fader / fx / meter。

AppModel 持有两个 deck、clock（ValueNotifier<int>，逐帧通知）、库列表、选中项、framesPerPixel、crossfader，方法名即行为（togglePlay、cue、toggleSync、adjustTempo、bend、tapPad、stepLoop、jumpBy、setUnit、setEq、zoom、toggleLibrary/Search…）。只有依赖时间的控件监听 clock，browser 和 control 不逐帧重建。

---

## 控件类型

按钮：PanelButton 平面矩形，无圆角无边框；未激活比背景稍亮，激活用 accent。GlyphButton 方形自绘图标键。ModeTabs 一排小标签，选中 accent、其余 faint。

推子：BarFader 竖向，未按 2px 细槽 + 已走长度高亮，按住槽展开到手柄宽度，手柄宽度随列宽，相对拖动。Crossfader 横向，从中心向两边点亮，同样相对拖动。

Pad：PadGrid 两行四列，Pad 无圆角，lit 用 accent，其余 surface。

Meter：LevelMeter，CustomPaint，线性输入转 -48dB 刻度，顶部一条 peak 线。

Waveform：Waveform 滚动波形，双声道围绕中线，三层色带 + 节拍网格 + 固定中线播放头。Overview 是整轨概览，已播放亮、未播放暗。

CoverArt：seed 三种抽象构图，全 app 唯一带圆角的地方（T.radiusCover）。Glyph 全部自绘，不引 icon font。

字号和颜色只允许来自 theme.dart 的 T / Ty，别处不写死。

---

## 布局

分派：app_shell 用 LayoutBuilder 拿 maxWidth，>=760 走宽屏，<760 走窄屏（当前叫 phone）。没有任何设备或平台判断，纯按空间。

宽屏 full 的纵向分配：

```
header 44
deckinfo 两行并排 60
波形 72 + 72
control 单行 144
browser 吃剩余高度
```

剩余高度不足 110 时整页纵向滚动。control 九段：

```
transport(54) | pads | unit | centre(120) | unit | pads | transport(54)
```

两侧对称，中间是两条柱状推子 + 电平 + 交叉推子；pads 和 unit 用 Expanded 收缩。

窄屏 phone 的堆叠顺序：

```
header
deck1 info
deck1 波形
deck2 info
deck2 波形
control（写死 980 宽，横向滚动 + 3px 提示）
browser
```

固定高度合计约 476，高度不够就整页滚动。

deckinfo 内部：上区占 60%，artist/title 按 1:2 两行，右侧依次 key、tempo/bpm、time（time 在最右），下区 40% 是 overview。宽度阈值：<560 紧凑，>=486 显示 tempo，>=420 显示 key。

颜色分三段通栏：band #1b1b1b（header/deck/control）、wave #0b0b0b（波形）、browser #131313，段间靠色阶分隔，不留空隙。

---

## 布局演进（方向，未实现）

目标四种布局。判断用方向 + 尺寸，all_in_one 用显式开关优先，不靠平台识别：

```
allInOne 开关        -> all_in_one
竖屏 且 宽 <600      -> phone_narrow
横屏 且 高 <520      -> phone_wide
其余                 -> full
```

browser 只在 full 出现，后三种都隐藏。

full 同现状。phone_wide（手机横屏）核心矛盾是高度不够：两个 deckinfo 并排压低，两条波形左右并排，control 紧凑单行，无 browser。phone_narrow（手机竖屏）沿用上下堆叠，control 改三行重排 deck1 / centre / deck2，删掉 980 横向滚动和提示条，Expanded 吃满宽度。all_in_one（一体机）只留两个 pad 网格 + 各自 padmode 标签 + 最小 transport，header、deckinfo、波形、browser 全隐藏。

代码落点：新增 `layout/mode.dart` 放 LayoutMode 和纯函数 pickLayout(Size, {allInOne})，AppShell 按 switch 分派到四个 builder，共用现有子控件；ControlBand 加模式参数决定单行还是三行。golden 扩成 full / phoneWide / phoneNarrow / allInOne 四张。

待定：PC 小窗跟空间走还是跟设备走；600 和 520 两个阈值；all_in_one 的 padmode 提示样式、transport 保留哪些键。
