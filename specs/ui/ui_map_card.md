---
schemaVersion: 1
id: ui_map_card
title: 地图卡片模板
type: ui
description: 地图卡片模板：由 MapInfo 资源驱动背景与文字，带随机相位的正弦漂浮动画。
---
# 地图卡片模板

## 文件
- 场景：`res://scenes/ui/map_card.tscn`
- 脚本：`res://src/ui/map_card.gd`
- 数据类型：`res://src/data/map_info.gd`（`MapInfo`，`extends Resource`）
- 数据文件：`res://resources/maps/*.tres`

## 设计目的

把「一张地图的显示与跳转」从主菜单场景里拆出来：

- 主菜单只摆卡片实例，不关心地图内容
- 每张地图的内容写在自己的 `.tres` 里
- 加地图 = 新建一份 `.tres` + 复制一个卡片实例，**不改场景结构、不改脚本**

## 节点结构

```
MapCard (Control)              custom_minimum_size 300×600（宽高比 1:2）
└── Body (Control)             动画层，满卡尺寸
    ├── Frame (NinePatchRect)  外框底板，九宫格贴 slot.png 裁剪块
    ├── CardButton (TextureButton)  地图背景，四边内缩 16 让出外框
    └── Hover (TextureRect)    悬停高亮，默认隐藏
        ├── NameLabel          地图名，64 号
        └── StatusLabel        状态文字（进入 / 敬请期待），64 号
```

## 为什么动画作用在 Body

`MapCard` 在 `HBoxContainer` 里，位置由容器接管；直接改它的 `position` 会被容器排序覆盖。
`Body` 不受容器管理，所以漂浮动画只动 `Body.position` 与 `Body.rotation`。

## 动画参数（卡片实例的检查器）

| 属性 | 默认 | 说明 |
|---|---|---|
| Float Amplitude | 6.0 | 纵向幅度（场景单位，屏幕上约 ×1.334） |
| Sway Amplitude | 1.8 | 横向幅度，设 0 只上下浮 |
| Tilt Degrees | 0.5 | 倾斜角度，设 0 不旋转 |
| Float Speed | 0.9 | 整体速度倍数 |

三轴都是正弦，横向频率刻意低于纵向，轨迹呈缓慢椭圆 / 8 字。相位、频率、幅度、起始时间在 `_ready` 中用随机种子各自取值，所以多张卡互不同步。

## 数据字段（MapInfo）

| 字段 | 用途 |
|---|---|
| display_name | 卡片显示名，悬停时出现 |
| background | 卡片背景图（整图或 AtlasTexture 裁剪块） |
| target_scene | 点击后跳转的关卡；为空则不跳转 |
| locked | 是否锁定，锁定时点击无反应 |
| locked_text | 锁定时的状态文字，未锁定时显示「进入」 |

## 已知约定与注意

1. **文字只在悬停时可见**：两个 Label 挂在 `Hover` 下面，高亮层默认隐藏。
2. **外框靠内缩露出**：`Frame` 与 `CardButton` 原本同尺寸重合，背景图会盖住外框，因此 `CardButton` 四边各内缩 16。
3. **旋转要设 pivot**：`Body.pivot_offset` 在 `resized` 时同步为尺寸的一半，否则会绕左上角旋转。
4. 卡片背景使用拉伸填满（`stretch_mode = 0`），原图比例约 0.87:1 拉到 1:2 会有明显压窄；若要不变形需单独裁 1:2 素材。