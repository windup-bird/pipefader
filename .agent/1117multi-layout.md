# flutter multi-layout方案

当前把tui的底层抽离到了app，准备扩展flutter gui; 后端、行为逻辑全部在app，flutter只负责前端

目标：web做开发时预览，windows/linux/android/web多端统一

- pc/pad -> full
- phone -> landscape(横屏), stacked(竖屏)
- all-in-one's screen -> all-in-one(一体机)

当前仅做前端草案和web预览，不写绑定，控件元素尽量复用便于后期改界面风格、皮肤等

## 界面
无边框无卡片设计，不要显示标题, 全部使用响应式布局而不是写死高度，边界对齐内部元素对齐，匀称美感

### full
---
header
---
deckinfos
---
waveforms
---
control
---
browser
---

maybe 4decks?

deckinfo横向排列，waveform纵向堆叠, control只有两个deck多个切换按钮, 其他布局也是如此

### landscape

---
deckinfo | logo | deckinfo
---
waveform
---
control-phone
---

browser? 通过点击deckinfo->cover呼出

3decks?

---
header(small)
---
deckinfo: 横向排列
---
waveform
---
control-phone
---

### stacked

---
header
---
deckinfo1
waveform
---
deckinfo2
waveform
---
deckinfo3(when 3decks mode)
waveform
---
control-phone
---

### all-in-one

同full，但browser/trans-pannel隐藏, waveform占用空间更大，control仅起提示作用，展示pad/fx，省略fader

## header

logo图标居中, logo：形似'TT'，像两个推子（fader）, 内部无线条，比例匀称协调

点击logo弹出布局切换、controller连接、output选择、settings

菜单设计：靠顶部居中
---
logo(放大)
---
layout1 | layout2 | ...
---
controller
output
settings
---

layout点击后切换，后面的项目点击弹出居中菜单

## deckinfo

空间关系：多行相同名称的意思是元素横跨多行，下同

---
cover | artist | keylock icon | tempo(例如+2.0%) | time已播放
cover | title  | key | bpm(当前而不是原本) | time剩余
overview(半波 算法参考tui)
---

三行比例1:2:3

> !!注意overview的空间关系，改成在cover下方; 加个keylock icon

## waveforms

同tui, 无边框滚动波形，中线对齐，统一缩放，按钮在最左边叠在波形上

> !!右侧(当前左)放缩放按钮，上下排列，+-, 垂直居中

> !!左侧放beatctl, 每个轨道一个

---
toggle() | < | 4 beats | >
---

toggle可选beatloop beatjump manualloop, 样式是对应图标，点击弹窗选择

对应的定义和样式可参考当前的unit:beatctl,不过要带点透明同时保证可视度

beatjump: 同tui
beatloop: - | 4 beats(点击激活/退出) | +
manualloop: in | call | out; 激活状态in/out变-/+调整beats，call变beats点击退出; 未激活点击call激活上一次loop

控制逻辑复杂，但具体逻辑应该在rust侧

## control

> 此部分不需要修改

对称排列(tui目前不是对称，相当于把左边的翻折到右边)，可选不同控件

响应式布局, 内部元件各自对齐

---
trans | unit1 | unit2 | fader | 电平 | fader | ...
---

unit名称在面板下方，可选以下

### pads

同tui, padmode在上方

### tempo

---
sync leader/follower
- | bpm | +
temporange
< | bend | >
---

### beatctl

---
- | 4 loop | +
in | call(点击激活/退出) | out
< | 16 jump | >
---

beats只控制loop，jump的beats通过点击jump按钮弹出菜单设置



### mixer

eq纵向bar+filter

### fx

---
- | {} beats | +
param 1 (bar)
param 2
hold | instant (button)
---
fx name (点击弹出切换菜单)
---


## control-phone

> 此处新增, 目标是优化触屏场景

```text
---
sync 		| ↓
tempo 		| unit | fader |
play | cue 	| ↑
---
```

注意空间关系；landscape时把左边对称到右边，stacked纵向堆叠

tempo显示当前bpm，上下滑动调整bpm, 可以在拖动时展示一个刻度，小格为0.1大格为1; 左右滑动是bend

unit只有一个不同于full，可选pad/mixer-max, 后者新增fx放到filter右边

## browser

---
左栏弹出按钮 | "Browser" | search button | 右栏弹出按钮
library(左栏) | list and tracks | ???
---

左栏: library, 可收起

中栏：list|tracks,list栏和library同宽度

右栏：我还没想好, 可能是临时列表，或者用户可以把某个列表单独从右边打开

## 风格

1. 按照plan方案，不要私自添加元素，除非问我后同意
2. 现代深色，高对比度，主题色蓝，少线条，颜色统一定义统一配置，看着像专业软件不要有ai味
3. 除了封面小角度圆角，其他均不用圆角
4. 无边框沉浸式布局，不要用web常用的卡片设计，web仅测试目标是桌面级专业软件
5. 推子：横向长条＋纵向细槽，按住/拖动后细槽展开成同宽度, 点击拖动的手感是记录相对位置而不是绝对
6. 按钮：无圆角矩形，间距统一，未激活时比背景稍亮模拟真实碟机
7. 推子和按钮可以加一些光影模拟真实设备，显得更有层次
