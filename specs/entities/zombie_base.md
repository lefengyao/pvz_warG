---
schemaVersion: 1
id: zombie_base
title: 僵尸模板
type: enemy
description: 所有僵尸的父级模板：骨骼视觉、WALK/ATTACK/DEAD 状态机、防具与掉落流程、减速与受击闪白。
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
      animation_driver: AnimationPlayer
      flip_by_direction: false
      visual_root: Skeleton2D
  - path: specs/components/hitbox.md
    key: hitbox
    values:
      disabled_on_death: true
      scene_group: zombie
      shape_node: CollisionShape2D
  - path: specs/components/sight_ray.md
    key: sight
    values:
      border_filter: true
      ray_node: RayCast2D
      target_group: plant
  - path: specs/components/damage_receiver.md
    key: damage
    values:
      damage_route: armor_then_health
      flash_on_hit: true
      hit_signal: be_attack
      penetrating_ammo_type: 2
      scale_field: damage_ratio
  - path: specs/components/death_behavior.md
    key: death
    values:
      broadcast_signal: ""
      check_phase: physics_process
      drops_loot: true
      release: after_animation
      sfx: fall_sfx
  - path: specs/components/loot_drop.md
    key: loot
scene: scenes/zombies/front_yard/ordinary_zombie/ordinary_zombie.tscn
parent: category_zombies
extends: character_base
anchors:
  - name: attack_point
    label: 攻击判定位置 Marker2D attack_position
    capacity: 1
  - name: loot_point
    label: 掉落物落点 Marker2D 掉落物位置
    capacity: 1
  - name: armor_slot_1
    label: 一类防具挂载点 armor_target1
    capacity: 1
  - name: armor_slot_2
    label: 二类防具挂载点 armor_target2
    capacity: 1
signals:
  - be_attack
stateMachine:
  initialState: IDLE
  states:
    - id: IDLE
      title: 待机
      description: 初始化瞬间状态，_ready 后立即切到 WALK
    - id: WALK
      title: 行走
      description: 向左侧行进，速度取 character.speed × speed_ratio
    - id: ATTACK
      title: 攻击
      description: 啃咬前方植物，攻击间隔取 attack_speed_constant_value
    - id: DEAD
      title: 死亡
      description: 播放死亡动画、生成掉落并释放
  transitions:
    - from: IDLE
      event: level_ready
      to: WALK
    - from: WALK
      event: target_in_front
      to: ATTACK
    - from: ATTACK
      event: target_gone
      to: WALK
    - from: WALK
      event: health_depleted
      to: DEAD
    - from: ATTACK
      event: health_depleted
      to: DEAD
---
# 僵尸模板

所有僵尸的父级，对应 `src/zombies/front_yard/ordinary_zombie/ordinary_zombie.gd`（`class_name zombie_template`，`extends Area2D`）。注意：脚本名是 `ordinary_zombie`，但 `class_name` 才是全局模板类名，普通僵尸场景直接使用这个模板本体。

## 继承

`zombie_base` → `extends` 角色基准 `character_base`，继承 8 个共有组件与四个基础锚点，再按下表覆盖僵尸侧取值，并追加掉落组件。

## 组件取值

| 组件 | 关键取值 | 含义 |
|---|---|---|
| `stats` | 默认；具体僵尸覆盖 | 数值 |
| `main`（状态机） | `IDLE` 起步，`_ready` 立即切 `WALK` | 状态机 |
| `placement` | 默认，另有 `get_column()` 反查 | 网格位置 |
| `visual` | `Skeleton2D` / `AnimationPlayer` / 不翻转 | 骨骼视觉 |
| `hitbox` | `zombie` / 死亡时禁用碰撞 | 被植物射线命中 |
| `sight` | `RayCast2D` / 目标 `plant` / 越界过滤 | 索敌 |
| `damage` | `armor_then_health` / 发 `be_attack` / 闪白 / 穿透类型 2 | 先防具后本体 |
| `death` | `physics_process` / 等动画 / 无信号 / 有掉落 / `fall_sfx` | 死亡 |
| `loot` | 各僵尸覆盖 | 掉落产出 |

## 场景结构

根节点 `Area2D`，场景分组 `zombie`。

| 节点 | 类型 | 作用 |
|---|---|---|
| `Skeleton2D` | Skeleton2D | 骨骼视觉根，`be_attack` 闪白作用在它的 `modulate` |
| `AnimationPlayer` | AnimationPlayer | 行走、攻击、死亡动画 |
| `CollisionShape2D` | CollisionShape2D | 受击范围，死亡时 `disabled = true` |
| `attack_position` | Marker2D | 攻击判定位置 |
| `掉落物位置` | Marker2D | 掉落物落点，`_ready` 时缓存到 `loot_position` |
| `RayCast2D` | RayCast2D | 前方目标检测 |
| `StateMachine` | Node | 状态机，`owner_root` 指向根节点，自带 `IDLE` / `ATTACK` / `WALK` / `DEAD` |

## 状态机

| 状态 | 含义 |
|---|---|
| `IDLE` | 模板存在但 `_ready` 立即切走 |
| `WALK` | 向场地左侧行进 |
| `ATTACK` | 啃咬/攻击植物 |
| `DEAD` | 死亡动画、掉落与释放 |

`_ready()` 的顺序是：`StateMachine` 先切入 `IDLE`，紧接着 `zombie_template` 调用 `change_state("WALK")`。因此实际运行态是 `WALK`。

## 成员

| 成员 | 签名 | 行为 |
|---|---|---|
| `be_attack` | `signal` | 受击时发出，`_ready` 中连接自身 `be_attack_effect` 做 0.01 秒闪白 |
| `take_damage(attack, ammo_type)` | 2 参 | 先交给 `a1`（armor1）→ 再 `a2`（armor2）→ 剩余伤害乘 `damage_ratio` 扣本体，最后发 `be_attack` |
| `dead()` | 无参 | 置 `is_loot`、禁用碰撞、播 `dead` 动画与 `fall_sfx`、生成掉落、等动画结束再 `queue_free()` |
| `set_loot()` | 无参 | 用 `loot_tex` 或 `loot_head` 生成掉落物，挂到 `Globalmanager.loots` |
| `ready_armor()` | 无参 | 实例化 `armor1` / `armor2`，挂到 `armor_target1` / `armor_target2` |
| `set_slow_down(time, ratio)` | 2 参 | 叠加减速层数，改写 `speed_ratio` 与全部 `AnimationPlayer.speed_scale`，染色 `Color(0, 0, 128, 0.7)` |
| `check_attack_ray(ray, object)` | 2 参 | 与植物同名接口，目标分组默认取 `character.attack_object` |
| `get_column()` | 无参 | 由关卡 `get_pos()` 反查当前列 |

## 初始化行为

- `_ready` 从 `get_tree().root` 找名为 `level` 的节点缓存为 `level`。
- 速度在 `_ready` 中乘 `randf_range(1, 1.2)`，所以同一只僵尸每局移动速度略有随机差异。
- 掉落位置缓存自 `掉落物位置` 锚点的全局坐标。
- `ready_effect()` 是子类钩子，可追加动画播放器列表与状态切换（刺客重设 `attack_type`、威龙切 `JET`）。

## 防具与掉落

防具通过 `zombie_armor` 组件的两个槽位配置（`armor_1` / `armor_2`），掉落通过 `loot_drop` 组件配置。无防具的僵尸（普通、手枪、撑杆、刺客、威龙）不挂防具槽。

## 子类约定

- 子类脚本 `extends zombie_template`，场景根节点继承本模板场景。
- 状态脚本放在角色目录下、`extends State`；子类可追加状态（如刺客的 `DASH`、`PARRY`，撑杆的 `RUN`，威龙的 `JET`）。
- 覆写 `dead()` 时必须自行处理 `is_loot`、碰撞禁用与掉落取舍。
- 只写与模板不同的组件字段值，不要重复声明全部组件。
