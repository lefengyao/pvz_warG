---
schemaVersion: 1
id: pean_shooter
title: 豌豆射手
type: character
description: 基础直线射手：攻击间隔 1.0 秒，发射普通豌豆。
status: draft
version: 1
relations: []
source: agent
components:
  - path: specs/components/character_stats.md
    key: stats
    values:
      attack_object: zombie
      attack_speed_constant_value: 1
      character_name: 豌豆射手
      max_health: 100
  - path: specs/components/plant_card_cost.md
    key: cost
    values:
      cool_time: 7.5
      cooling: true
      sun_num: 100
scene: scenes/plants/front_yard/pean_shooter/pean_shooter.tscn
parent: category_plants
extends: plant_base
---
# 豌豆射手

基础直线射手，一次一发普通豌豆。

## 位置

| 项 | 值 |
|---|---|
| 场景 | `scenes/plants/front_yard/pean_shooter/pean_shooter.tscn` |
| 脚本 | `src/plants/front_yard/pean_shooter/pean_shooter.gd`（`extends plant_template`） |
| 状态脚本 | `attack.gd`（`extends normal_attack`）、`idle.gd`（`extends normal_idle`） |
| 卡片顺序 | `generate_cards.gd` 第 2 位 |

## 数值

| 项 | 值 | 来源 |
|---|---|---|
| 角色名 | 豌豆射手 | 场景 `character_name` |
| 生命 | 100（默认，未覆盖） | `character_stats` 默认值 |
| 攻击间隔 | 1.0 秒 | 场景 `attack_speed_constant_value` |
| 攻击目标分组 | `zombie` | 场景 `attack_object` |
| 阳光消耗 | 100 | 场景 `sun_num` |
| 卡片冷却 | 7.5 秒 | 场景 `cool_time` |

## 行为

- `idle.gd` 的 `idle_code()` 播放 `AnimationPlayer2` 的 `idle`。
- `attack.gd` 覆写 `play_attack()`，播放 `AnimationPlayer2` 的 `attack`；发射由 `normal_attack` 的 `bullet2` 完成。
- 状态切换由 `normal_idle` / `normal_attack` 的射线检测驱动：命中 `zombie` 分组切 `ATTACK`，失去目标切回 `IDLE`。
- 子弹实例化位置取 `AnimatedSprite2D/Marker2D`（`muzzle` 锚点），`z_index = row * 10 + 3`，加入 `Globalmanager.bullets`。

## 关系

- 发射物：`scenes/projectiles/pea/ordinary_pea/pean.tscn`
- 状态机：`StateMachine` 下的 `IDLE` / `ATTACK` 节点，`ATTACK` 内挂 `attack.gd` 实例。
