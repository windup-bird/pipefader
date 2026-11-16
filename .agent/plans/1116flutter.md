# flutter gui方案

当前把tui的底层抽离到了app，准备扩展flutter gui; 后端、行为逻辑全部在app，flutter只负责前端

目标：web做开发时预览，windows/linux/android/web多端统一

当前仅做前端草案和web预览，不写绑定，控件元素尽量复用便于后期改界面风格、皮肤等

## 界面

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

无边框无卡片设计，不要显示标题, 全部使用响应式布局，边界对齐内部元素对齐，匀称美感

## header

logo图标居中,不显示名称, 可能带点监视数据，其他我还没想好

logo：形似'TT'，像两个推子（fader）, 内部无线条，比例匀称协调

## deckinfo

空间关系：多行相同名称的意思是元素横跨多行，下同

---
cover | artist	| 已播放时间 | key | tempo(例如+2.0%) | sync
cover | title	| 剩余时间 | key | bpm(当前而不是原本) | sync
cover | overview |
---

三行比例1:2:3

## waveforms

同tui, 无边框滚动波形，中线对齐，统一缩放，按钮在最左边叠在波形上

左侧放缩放按钮，上下排列，+-

## control

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
7. 
