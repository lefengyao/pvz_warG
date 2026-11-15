---
schemaVersion: 1
id: caiwen
title: 菜问
type: character
description: 近战拳击植物：0.8 秒攻击间隔，按目标位置转向并对低血目标追加斩杀特效。
status: draft
version: 1
relations: []
source: agent
components:
  - path: specs/components/character_stats.md
    key: stats
    values:
      attack_object: zombie
      attack_speed_constant_value: 0.8
      character_name: 菜问
  - path: specs/components/plant_card_cost.md
    key: cost
    values:
      cool_time: 7.5
      cooling: true
      sun_num: 150
scene: scenes/plants/front_yard/caiwen/caiwen.tscn
parent: category_plants
extends: plant_base
---
# 菜问

近战拳击植物，会转向目标并追加斩杀特效。

## 位置

| 项 | 值 |
|---|---|
| 场景 | `scenes/plants/front_yard/caiwen/caiwen.tscn` |
| 脚本 | `src/plants/front_yard/caiwen/caiwen.gd`（`extends plant_template`） |
| 状态脚本 | `caiwen/attack.gd`（`extends normal_attack`）、`caiwen/idle.gd`、`caiwen/slay.gd` |
| 卡片顺序 | `generate_cards.gd` 第 9 位 |

## 数值

| 项 | 值 | 来源 |
|---|---|---|
| 角色名 | 菜问 | 场景 `character_name` |
| 生命 | 100（默认，未覆盖） | `character_stats` 默认值 |
| 攻击间隔 | 0.8 秒 | 场景 `attack_speed_constant_value` |
| 攻击目标分组 | `zombie` | 场景 `attack_object` |
| 阳光消耗 | 150 | 场景 `sun_num` |
| 卡片冷却 | 7.5 秒 | 场景 `cool_time` |

## 行为

- `caiwen.gd` 缓存 `AnimationPlayer2`、近战判定节点 `AnimatedSprite2D/Marker2D/Melee（挂场景上调整使用）`，以及两个 `GPUParticles2D`。
- `parry()` 调用 `gpu_particles_2d.slay()`，供刺客僵尸进入 `PARRY` 时反向触发。
- `attack.gd` 的 `attack()` 复制近战判定节点，按 `attack_object` 过滤，加入 `Globalmanager.bullets`。
- `attack.gd` 的 `raycast_body_effect1(body)` 做两件事：
  1. 按目标相对位置把 `animated_sprite_2d.scale.x` 翻到 ±1，实现左右转向；
  2. 若目标 `current_health < 100`，直接把目标生命置 0，并按朝向播放对应的斩杀粒子。
- `play_attack()` 播 `AnimationPlayer2` 的 `attack`。

## 分组关系

- 该植物在代码里被刺客僵尸的碰撞逻辑当作 `melee_type_plant` 分支处理：刺客会后退 600 距离、耗时 1.0 秒的 `PARRY`，并调用本植物的 `parry()`。
