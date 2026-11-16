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

## header

logo居中, 可能带点监视数据，其他我还没想好

logo：形似'TT'，像两个推子（fader）, 内部无线条，比例匀称协调

## deckinfo

---
cover | artist	| time | key | bpm |
cover | title	| time | key | bpm |
cover | overview |
cover | overview |
---

## waveforms

同tui

左侧放缩放按钮，上下排列，+-

## control

对称排列(tui目前不是对称，相当于把左边的翻折到右边)，可选不同控件，响应式布局

---
trans | unit1 | unit2 | fader | 电平 | fader | ...
---

unit 可选以下

### pads

同tui

### beatctl

---
sync leader/follower
- | bpm | +
temporange
< | bend | >
---

### tempo

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
2. 现代深色，少线条，看着像专业软件不要有ai味
