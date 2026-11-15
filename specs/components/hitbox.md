---
schemaVersion: 1
id: hitbox
title: 受击碰撞
type: component
description: ""
fields:
  - key: scene_group
    label: 所属场景分组
    type: string
    default: plant
  - key: disabled_on_death
    label: 死亡时禁用碰撞
    type: boolean
    default: true
  - key: shape_node
    label: 碰撞节点
    type: string
    default: CollisionShape2D
scope: system
appearance:
  icon: shield
  color: gray
groupId: group_basic_components
---
# 受击碰撞

角色被子弹与近战判定击中的碰撞体，以及它在场景分组里的归属。

## 字段

| 字段 | 说明 | 植物取值 | 僵尸取值 |
|---|---|---|---|
| `scene_group` | 所属场景分组 | `plant` | `zombie` |
| `disabled_on_death` | 死亡时是否禁用碰撞 | 不适用（立即释放） | 真 |
| `shape_node` | 碰撞节点 | `CollisionShape2D` | `CollisionShape2D` |

## 场景分组

分组名来自 `project.godot` 的 `[global_group]`：

| 分组 | 用途 |
|---|---|
| `plant` | 所有植物，僵尸的攻击目标 |
| `zombie` | 所有僵尸，植物的攻击目标 |
| `melee_type_plant` | 近战植物，刺客僵尸会对其触发 `PARRY` 并调用 `parry()` |
| `defence_plant` | 防御植物，刺客僵尸对其造成 `max_health × 0.6` 并触发零距离 `PARRY` |
| `trap` | 陷阱植物 |

`character_stats.attack_object` 决定**打谁**，本组件的 `scene_group` 决定**自己是谁**，两者必须互补：植物的 `scene_group` 是 `plant`、`attack_object` 是 `zombie`；僵尸反之。

## 碰撞体类型

- 植物：`RectangleShape2D`，在 `plant_template.tscn` 里定义。
- 僵尸：`CollisionShape2D` 跟随骨骼动作，死亡时由 `zombie_template.dead()` 设 `disabled = true`。

## 已知问题

土豆地雷在埋设阶段用 `CollisionShape2D.visible = false` 而不是 `disabled = true` 关闭检测，碰撞仍然生效，只靠 `idle2` 标志拦住提前引爆。见土豆地雷资料。
