---
schemaVersion: 1
id: plant_base
title: 植物模板
type: character
description: 所有植物的父级模板：Area2D 场景结构、IDLE/ATTACK/DEAD 状态机、dead 信号与射线命中接口。
status: draft
version: 1
relations: []
source: agent
components:
  - path: specs/components/character_stats.md
    key: stats
  - path: specs/components/state_machine.md
    key: main
    values:
      current_state: IDLE
      enabled: true
  - path: specs/components/grid_placement.md
    key: placement
  - path: specs/components/actor_visual.md
    key: visual
    values:
      animation_driver: AnimatedSprite2D
      flip_by_direction: false
      visual_root: AnimatedSprite2D
  - path: specs/components/hitbox.md
    key: hitbox
    values:
      disabled_on_death: false
      scene_group: plant
      shape_node: CollisionShape2D
  - path: specs/components/sight_ray.md
    key: sight
    values:
      border_filter: true
      ray_node: AnimatedSprite2D/RayCast2D
      target_group: zombie
  - path: specs/components/damage_receiver.md
    key: damage
    values:
      damage_route: health
      flash_on_hit: false
      hit_signal: ""
      scale_field: damage_ratio
  - path: specs/components/death_behavior.md
    key: death
    values:
      broadcast_signal: dead
      check_phase: process
      drops_loot: false
      release: immediate
      sfx: ate_sfx
  - path: specs/components/plant_card_cost.md
    key: cost
scene: scenes/plants/template/plant_template.tscn
parent: category_plants
extends: character_base
anchors:
  - name: muzzle
    label: 发射点 / 特效原点 Marker2D
    capacity: 1
signals:
  - dead
stateMachine:
  initialState: IDLE
  states:
    - id: IDLE
      title: 待机
      description: 未发现目标，播放待机动画
    - id: ATTACK
      title: 攻击
      description: 发现目标，由子类状态脚本执行攻击循环
    - id: DEAD
      title: 死亡
      description: 生命归零，发 dead 信号并释放
  transitions:
    - from: IDLE
      event: target_in_range
      to: ATTACK
    - from: ATTACK
      event: target_lost
      to: IDLE
    - from: IDLE
      event: health_depleted
      to: DEAD
    - from: ATTACK
      event: health_depleted
      to: DEAD
---
# 植物模板

所有植物的父级，对应 `src/plants/template/plant_template.gd`（`class_name plant_template`，`extends Area2D`）与 `scenes/plants/template/plant_template.tscn`。

## 继承

`plant_base` → `extends` 角色基准 `character_base`，继承 8 个共有组件与四个基础锚点，再按下表把植物侧取值覆盖上去，并追加卡片费用组件。

## 组件取值

| 组件 | 关键取值 | 含义 |
|---|---|---|
| `stats` | 默认；具体植物覆盖 | 数值 |
| `main`（状态机） | `IDLE` 起步 | 状态机 |
| `placement` | 默认 | 网格位置 |
| `visual` | `AnimatedSprite2D` / `AnimatedSprite2D` / 不翻转 | 帧动画视觉 |
| `hitbox` | `plant` / 死亡不禁用 | 被僵尸射线命中 |
| `sight` | `AnimatedSprite2D/RayCast2D` / 目标 `zombie` / 越界过滤 | 索敌 |
| `damage` | `health` / 无受击信号 / 不闪白 | 直接扣血 |
| `death` | `process` / 立即释放 / 发 `dead` / 无掉落 / `ate_sfx` | 死亡 |
| `cost` | 各植物覆盖 | 阳光与冷却 |

## 场景结构

`plant_template.tscn` 根节点是 `Area2D`，场景分组 `plant`。

| 节点 | 类型 | 作用 |
|---|---|---|
| `AnimatedSprite2D` | AnimatedSprite2D | 帧动画与视觉根 |
| `AnimatedSprite2D/Marker2D` | Marker2D | 发射点/特效原点 |
| `AnimatedSprite2D/RayCast2D` | RayCast2D | 前方命中检测 |
| `CollisionShape2D` | CollisionShape2D | 受击范围 |
| `shadow` | Sprite2D | 地面投影 |
| `StateMachine` | Node | 状态机，`owner_root` 指向根节点 |

模板的 `IDLE` 子节点挂 `normal_idle.gd`，`ATTACK` 挂 `normal_attack.gd`，两者均为 `extends State`。子植物若不覆写这两个节点，就沿用默认脚本（此时 `bullet2` 为空）。

## 状态机

| 状态 | 含义 |
|---|---|
| `IDLE` | 待机，未发现目标 |
| `ATTACK` | 攻击循环，由子类状态脚本接管 |
| `DEAD` | 死亡收尾 |

## 成员

| 成员 | 签名 | 行为 |
|---|---|---|
| `dead` | `signal dead(row, column)` | 死亡广播，`level.gd` 用它清空格子占用 |
| `dead_()` | 无参 | 发 `dead` 信号、播 `ate_sfx`、`queue_free()` |
| `emit_dead()` | 无参 | 只用 `character.row/column` 发信号 |
| `take_damage(attack, ammo_type)` | 2 参 | 直接扣 `current_health`；若 `ammo_type == 2` 且这一击致死，先播 `ate_sfx` |
| `check_attack_ray(ray)` | 1 参 | 返回 `[命中?, body]`；要求 body 在 `character.attack_object` 分组内，且 `x < Globalmanager.right_boder_x` |
| `raycast_body_effect1(body)` | 钩子 | 基类空实现，子类覆写 |
| `raycast_body_effect2()` | 钩子 | 基类空实现，子类覆写 |

## 额外导出字段

| 字段 | 类型 | 说明 |
|---|---|---|
| `ate_sfx` | AudioStream | 被吃/致死的音效，死亡流程与致命中都播它 |
| `sun_num` / `cool_time` / `cooling` | int / float / bool | 已由 `plant_card_cost` 组件表达 |
| `tex` / `tex2` | Texture2D | 卡片贴图，模板内使用 |

## 死亡流程

`_process` 每帧检查 `character.current_health <= 0`，成立即调用 `dead_()`。与僵尸不同，植物没有独立状态脚本处理死亡，扣血到 0 后下一帧就会被释放。

## 子类约定

- 子类脚本 `extends plant_template`，场景根节点实例化 `plant_template.tscn`。
- 行为状态脚本放在植物自己的目录下，`extends normal_idle` 或 `extends normal_attack`。
- 费用与冷却通过 `plant_card_cost` 组件覆盖，不写进脚本。
- 只写与模板不同的组件字段值，不要重复声明全部组件。
