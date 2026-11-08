---
schemaVersion: 1
id: map_c56ea442e2e0
title: 地图：庭院
type: map
description: 第一张地图，目前唯一可进入；卡片数据与关卡目录现状。
status: draft
version: 1
relations: []
source: agent
components: []
scene: scenes/levels/front_yard/yard_level_select.tscn
---
# 地图：庭院

## 定位

游戏的第一张地图，也是目前**唯一可进入**的地图。玩家从选关界面点这张卡片，进入庭院的关卡选择。

## 选关界面表现

| 项 | 值 |
|---|---|
| 卡片实例 | `chose_map.tscn` 里的 `HBoxContainer/MapCard`（最左） |
| 数据资源 | `res://resources/maps/courtyard.tres` |
| 显示名 | 庭院 |
| 状态文字 | 进入（`locked = false`） |
| 点击行为 | 跳转 `res://scenes/levels/front_yard/yard_level_select.tscn` |

## 背景素材

- 图源：`res://assets/textures/levels/front_yard/b70160bc76ad1d896a66838bb3b12428.png`
- 卡片裁剪区：`Rect2(14.467987, 178.97171, 426.82663, 492.34128)`（以 `AtlasTexture` 形式写进 `.tres`）
- 卡片内以拉伸填满方式显示（`stretch_mode = 0`），原图比例约 0.87:1 被拉到 1:2，会有明显压窄

## 关卡内容现状

`scenes/levels/front_yard/` 下已有：

| 场景 | 说明 |
|---|---|
| `yard_level_select.tscn` | 庭院内部的关卡选择界面（卡片跳转目标） |
| `level/level1.tscn` | 关卡场景 |
| `level/normal_front_yard_level.tscn` | 普通关卡的通用场景 |
| `level_logic/level_logic1.tscn` ~ `level_logic4.tscn` | 4 份关卡逻辑数据 |

## 扩展方式

改这张地图的内容（名字、背景、跳转目标、是否锁定）只需要编辑 `resources/maps/courtyard.tres`，
不需要动主界面场景或脚本。

## 待办

1. 卡片背景按 1:2 拉伸会变形，若要更准确需要单独裁一版 1:2 素材。
2. 关卡内的完整流程尚未在此资料中记录，可后续补充关卡列表与解锁规则。