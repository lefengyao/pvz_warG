---
schemaVersion: 1
id: sight_ray
title: 索敌射线
type: component
description: ""
fields:
  - key: target_group
    label: 目标分组
    type: string
    default: ""
  - key: ray_node
    label: 射线节点
    type: string
    default: RayCast2D
  - key: border_filter
    label: 越界过滤
    type: boolean
    default: true
  - key: target_position_x
    label: 射线长度
    type: number
    default: 0
scope: system
appearance:
  icon: move
  color: blue
groupId: group_basic_components
---
# 索敌射线

角色向前方做命中检测的射线，以及把命中结果筛成「有效目标」的规则。

## 字段

| 字段 | 说明 | 植物取值 | 僵尸取值 |
|---|---|---|---|
| `target_group` | 目标分组 | `character.attack_object` | `character.attack_object` |
| `ray_node` | 射线节点 | `AnimatedSprite2D/RayCast2D` | `RayCast2D` |
| `border_filter` | 越界过滤 | 是 | 是 |
| `target_position_x` | 射线朝向长度 | 默认 | 默认；撑杆僵尸 `DASH` 时改为 -50 |

## 命中判定

两侧模板都有一个同名接口，返回 `[命中?, body]`：

```gdscript
# plant_template.gd
func check_attack_ray(ray: RayCast2D) -> Array:
    if ray.is_colliding():
        var body = ray.get_collider()
        if body != null:
            if body.global_position.x < Globalmanager.right_boder_x and body.is_in_group(character.attack_object):
                return [true, body]
    return [false, null]

# zombie_template.gd（多一个 object 参数，默认取 character.attack_object）
func check_attack_ray(ray: RayCast2D, object: String = character.attack_object) -> Array:
    ...
```

共同条件：

1. 射线必须处于碰撞状态；
2. 命中体不能为空；
3. 命中体的 x 必须小于 `Globalmanager.right_boder_x`（越界过滤，防止右侧场外目标被锁定）；
4. 命中体必须在 `attack_object` 分组内。

## 状态机如何使用

| 脚本 | 行为 |
|---|---|
| `normal_idle.gd` | 每帧 `update` 检测，命中切 `ATTACK` |
| `normal_attack.gd` | 每帧检测，未命中切回 `IDLE` |
| 僵尸 `walk.gd` | 命中切 `ATTACK` |
| 僵尸 `attack.gd` | 未命中切回 `WALK` |
| 地刺 `spikeweed.gd` | 绕过状态机，每帧直接检测并切动画 |

## 特例

撑杆僵尸另有 `check_dash_ray()`，返回 `{type, body}` 字典，`type` 区分 `none` / `pole` / `plant`，用来识别「撞到自己投出的撑杆」并触发跳跃。
