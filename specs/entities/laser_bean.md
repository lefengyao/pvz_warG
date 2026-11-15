---
schemaVersion: 1
id: laser_bean
title: 激光豆
type: character
description: 激光射手：攻击间隔 1.0 秒，发射 laser 场景并播放激光音效。
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
      character_name: 激光豆
  - path: specs/components/plant_card_cost.md
    key: cost
    values:
      cool_time: 7.5
      cooling: true
      sun_num: 175
scene: scenes/plants/front_yard/laser_bean/laser_bean.tscn
parent: category_plants
extends: plant_base
---
# 激光豆

直线激光射手，攻击时播放独立音效。

## 位置

| 项 | 值 |
|---|---|
| 场景 | `scenes/plants/front_yard/laser_bean/laser_bean.tscn` |
| 脚本 | `src/plants/front_yard/laser_bean/laser_pean.gd`（`extends plant_template`） |
| 状态脚本 | `laser_bean/attack.gd`（`extends normal_attack`）、`laser_bean/idle.gd`（`extends normal_idle`） |
| 卡片顺序 | `generate_cards.gd` 第 4 位 |

## 数值

| 项 | 值 | 来源 |
|---|---|---|
| 角色名 | 激光豆 | 场景 `character_name` |
| 生命 | 100（默认，未覆盖） | `character_stats` 默认值 |
| 攻击间隔 | 1.0 秒 | 场景 `attack_speed_constant_value` |
| 攻击目标分组 | `zombie` | 场景 `attack_object` |
| 阳光消耗 | 175 | 场景 `sun_num` |
| 卡片冷却 | 7.5 秒 | 场景 `cool_time` |

## 行为

- `laser_pean.gd` 只缓存 `AnimationPlayer2`。
- `attack.gd` 覆写 `attack_effect()`，在子弹生成之后播放 `laser_sfx`；发射逻辑仍由 `normal_attack.attack()` 执行。
- `idle.gd` 覆写 `idle_code()` 播放待机动画。
- 状态切换沿用 `normal_idle` / `normal_attack` 的射线检测。

## 关系

- 发射物：`scenes/projectiles/laser/laser.tscn`（`bullet2`）
- 音效：`laser_sfx`，在 `ATTACK` 状态节点上配置
