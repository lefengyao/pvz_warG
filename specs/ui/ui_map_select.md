---
schemaVersion: 1
id: ui_map_select
title: 选关界面（主菜单）
type: ui
description: 选关主界面：地图卡片布局、关于下拉与自绘确认层、设置面板入口。
---
# 选关界面（主菜单）

## 文件
- 场景：`res://scenes/levels/chose_map.tscn`（项目主场景）
- 脚本：`res://src/levels/general/chose_map.gd`

## 节点结构

```
Control                        1074×809，scale (1.787, 1.334)
├── TextureRect                渐变背景
├── HBoxContainer              地图卡片行：offset 60..1040 × 170..770，separation 40，居中
│   ├── MapCard                → resources/maps/courtyard.tres（庭院，可进入）
│   ├── MapCard2               → resources/maps/forest.tres（森林，锁定）
│   └── MapCard3               → resources/maps/deep_woods.tres（森林深处，锁定）
├── Label                      标题「pvz_warG」，字号 256
├── TextureRect2               左上角药丸底板
├── OptionButton (MenuButton)  顶部「查看」下拉，外观用 button.png 九宫格
├── view                       （visible = false）旧的「查看」按钮，已停用
├── setting                    右下「设置」入口
│   └── setting (NinePatchRect)  音频设置面板，默认隐藏，内含两个音量滑条 + 返回
└── ConfirmLayer               自绘确认层，默认隐藏
    ├── Dim                    ColorRect 全屏，黑色 55% 透明，Mouse Filter = Ignore
    └── Panel                  NinePatchRect 720×360，九宫格贴 button.png 裁剪块
        ├── Title              「确认打开」，44 号
        ├── Message            正文，28 号，自动换行
        ├── OpenButton         「打开」
        └── CancelButton       「取消」
```

## 交互流程

| 触发 | 行为 |
|---|---|
| 点「查看」下拉 | 弹出 PopupMenu，三项：作者 / 美术 / 源代码 |
| 选中某一项 | `id_pressed` → 暂存 `pending_url` → 显示 ConfirmLayer |
| 点「打开」 | `OS.shell_open(pending_url)` → 隐藏确认层 |
| 点「取消」 | 只隐藏，不打开 |
| 点「设置」 | 显示 `setting/setting` 音频面板 |
| 点面板「返回」 | 隐藏音频面板 |
| 点地图卡片 | 由卡片自己处理，本脚本不参与 |

## 数据约定

- 下拉项 id 必须和脚本 `url_map` 的键一致：0 作者、1 美术、2 源代码。改文案不影响跳转，改 id 会让跳转失效。
- 地图卡片的一切数据来自 `resources/maps/*.tres`，本场景只负责摆放实例。

## 样式约定

- 下拉与按钮统一用 `res://assets/textures/ui/button.png` 的裁剪块 `Rect2(34, 112, 229, 71)` 做九宫格底。
- 下拉面板与悬停高亮定义在场景内子资源 `Theme_xxwfl`：`PopupMenu/styles/panel` 用九宫格贴图，`PopupMenu/styles/hover` 用纯色半透明，避免高亮时贴图变形。
- 弹出菜单与确认层都要空白 `Window/styles/embedded_border` + `title_height = 0`，否则 Godot 会画一圈深色窗口边框。

## 已知待办

1. 「森林」「森林深处」两张卡为锁定状态，对应关卡尚未实现。
2. 场景里仍保留若干拆卡片后遗留的无效 ext_resource / sub_resource，Godot 下次保存会自动剔除。
3. 根节点 `scale (1.787, 1.334)` 是历史遗留的手写缩放，尚未规范化。