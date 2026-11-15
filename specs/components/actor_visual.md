---
schemaVersion: 1
id: actor_visual
title: 视觉表现
type: component
description: ""
fields:
  - key: visual_root
    label: 视觉根节点
    type: string
    default: AnimatedSprite2D
  - key: animation_driver
    label: 动画驱动节点
    type: string
    default: AnimatedSprite2D
  - key: flip_by_direction
    label: 按朝向翻转
    type: boolean
    default: false
scope: system
appearance:
  icon: character
  color: pink
groupId: group_basic_components
---
# 视觉表现

角色的视觉根与动画驱动方式。植物和僵尸都从这里取「动起来」的入口，但实现不同。

## 字段

| 字段 | 说明 | 植物取值 | 僵尸取值 |
|---|---|---|---|
| `visual_root` | 视觉根节点 | `AnimatedSprite2D` | `Skeleton2D` |
| `animation_driver` | 动画驱动 | `AnimatedSprite2D`（帧动画） | `AnimationPlayer` |
| `flip_by_direction` | 是否按朝向翻转 | 部分植物为真 | 假 |

## 两类角色的差异

| 项 | 植物 | 僵尸 |
|---|---|---|
| 视觉根 | `AnimatedSprite2D` | `Skeleton2D`（骨骼 + 多个 `Sprite2D` 挂件） |
| 动画 | `AnimatedSprite2D.play("idle" / "attack" / ...)` | `AnimationPlayer.play("walk" / "attack" / "dead" / ...)` |
| 附加播放器 | 多数植物另有 `AnimationPlayer2` 播攻击/待机 | 无 |
| 受击染色 | 无 | `Skeleton2D.modulate` 闪白 |
| 阴影 | 根节点下 `shadow: Sprite2D` | 根节点下 `shadow: Sprite2D` |

## 朝向翻转

需要左右转向的植物直接改 `visual_root.scale.x`：

| 角色 | 触发时机 |
|---|---|
| 菜问 | `raycast_body_effect1` 按目标相对位置设 `scale.x = ±1` |
| 窝瓜 | `attack.gd` 中目标在左侧时设 `scale.x = -1` |

僵尸的朝向由 `Skeleton2D` 骨骼固定，不通过缩放翻转。

## 约束

- `visual_root` 只描述根节点名称，具体路径由实体 `anchors.visual` 记录。
- 改视觉根类型会牵动 `zombie_template.be_attack_effect` 与各植物脚本的 `@onready` 缓存，必须先处理引用者。
