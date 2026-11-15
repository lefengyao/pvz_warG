---
schemaVersion: 1
id: character_base
title: 角色基准
type: character
description: 植物与僵尸共用的角色基准：数值容器、节点锚点、状态机骨架与伤害接口；不绑定具体场景。
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
  - path: specs/components/hitbox.md
    key: hitbox
  - path: specs/components/sight_ray.md
    key: sight
  - path: specs/components/damage_receiver.md
    key: damage
  - path: specs/components/death_behavior.md
    key: death
appearance:
  icon: character
  color: teal
parent: category_characters
anchors:
  - name: visual
    label: 视觉根节点：植物为 AnimatedSprite2D，僵尸为 Skeleton2D
    capacity: 1
  - name: hitbox
    label: 受击碰撞体 CollisionShape2D
    capacity: 1
  - name: ray_origin
    label: 命中检测 RayCast2D
    capacity: 1
  - name: state_machine
    label: 状态机节点 StateMachine
    capacity: 1
stateMachine:
  initialState: IDLE
  states:
    - id: IDLE
      title: 待机
      description: 站立等待，不移动、不攻击
    - id: DEAD
      title: 死亡
      description: 生命归零后的收敛状态，之后由各模板处理掉落与释放
  transitions:
    - from: IDLE
      event: health_depleted
      to: DEAD
---
# 角色基准

植物与僵尸的公共父级。它不绑定任何场景，而是把两类角色**在代码里已经共有的结构**逐项拆成组件。基准只放「两边都有且语义相同」的部分，任何一边独有的能力都留到子模板。

## 共有结构矩阵

下表每一行都对应两侧模板脚本里的真实实现，不是设计愿望：

| 维度 | 组件 | 植物实现 | 僵尸实现 | 共有依据 |
|---|---|---|---|---|
| 数值 | `character_stats` | `character.xxx` | `character.xxx` | 同一个 `general_character` Resource |
| 场地 | `grid_placement` | `row` / `column` 写入网格 | 同左，另有 `get_column()` 反查 | 都用 `z_index = row*10+n` |
| 视觉 | `actor_visual` | `AnimatedSprite2D` | `Skeleton2D` + `AnimationPlayer` | 都有视觉根与动画驱动 |
| 碰撞 | `hitbox` | `Area2D` + `CollisionShape2D`，分组 `plant` | 同构，分组 `zombie` | 都靠场景分组被对方射线命中 |
| 索敌 | `sight_ray` | `AnimatedSprite2D/RayCast2D` | `RayCast2D` | 同名 `check_attack_ray()` |
| 受击 | `damage_receiver` | `take_damage(attack, ammo_type)` | 同签名，多防具分流 | 弹药类型 1/2/3 分流 |
| 死亡 | `death_behavior` | `_process` 判死 → `dead_()` | `_physics_process` 判死 → `DEAD` → `dead()` | 都是「生命归零 → 收尾 → 释放」 |
| 状态 | `state_machine` | `IDLE` / `ATTACK` / `DEAD` | `IDLE` / `WALK` / `ATTACK` / `DEAD` | 同一个 `StateMachine` + `State` |

## 节点锚点

| 锚点 | 基准语义 | 植物中的节点 | 僵尸中的节点 |
|---|---|---|---|
| `visual` | 视觉根 | `AnimatedSprite2D` | `Skeleton2D` |
| `hitbox` | 受击碰撞体 | `CollisionShape2D` | `CollisionShape2D` |
| `ray_origin` | 命中检测射线 | `AnimatedSprite2D/RayCast2D` | `RayCast2D` |
| `state_machine` | 状态机 | `StateMachine` | `StateMachine` |

## 状态机骨架

基准只保证 `IDLE` 与 `DEAD`，以及「生命归零 → `DEAD`」这一条收敛路径。

- `src/core/state_machine.gd` 在 `_ready` 时若存在名为 `IDLE` 的子状态会自动切入。
- 只收集 `State` 子类（`src/core/state_base.gd`）作为状态，状态通过 `add_child` 挂载。
- 子模板可追加状态与转移，但不得删除 `DEAD`。

## 为什么不再只有「数值 + 状态机」

此前基准只挂了这两个组件，把碰撞、索敌、受击、死亡、音效、位置全部塞在正文里。结果是：

- 每个角色资料都要重复描述一遍「受击怎么算、死亡怎么走」；
- 无法按维度查询「哪些角色是穿透弹药可穿的」「哪些角色死亡有动画等待」；
- 改一处共用契约时，没有单一落点。

现在每个维度都有独立组件与字段，「共有」本身成为可校验的数据，而不只是文字。

## 明确不放进基准的部分

| 能力 | 归属 | 原因 |
|---|---|---|
| 卡片费用（`sun_num` / `cool_time`） | `plant_base` | 僵尸没有卡片 |
| 防具槽（`armor1` / `armor2`） | `zombie_base` + 具体僵尸 | 植物不会被防具保护 |
| 掉落产出（`loot_head` / `loot_tex`） | `zombie_base` | 植物死后不掉落 |
| 发射点 `muzzle` | `plant_base` | 僵尸的攻击点是 `attack_position`，语义不同 |
| 阴影 `shadow` | 子模板 | 两侧都有节点，但没有可配置数据 |
| `dead` / `be_attack` 信号 | 子模板 | 各自独有，硬提到基准会声明不存在的信号 |

## 继承链

```
character_base（8 组件 + 4 锚点 + IDLE/DEAD）
├── plant_base   → 追加 plant_card_cost、muzzle、dead 信号、ATTACK 状态
└── zombie_base  → 追加 loot_drop、attack_point/loot_point/armor_slot 锚点、be_attack 信号、WALK/ATTACK
```

具体角色只覆盖与模板不同的字段值，不重复声明组件。
