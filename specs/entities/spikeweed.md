---
schemaVersion: 1
id: spikeweed
title: 地刺
type: character
description: 地面持续伤害植物：每帧射线检测目标，命中即复现 Melee 判定；场景角色名写作「刺客」。
status: draft
version: 1
relations: []
source: agent
components:
  - path: specs/components/character_stats.md
    key: stats
    values:
      attack_object: zombie
      attack_speed_constant_value: 0.5
      character_name: 刺客
  - path: specs/components/plant_card_cost.md
    key: cost
    values:
      cool_time: 15
      cooling: true
      sun_num: 25
scene: scenes/plants/front_yard/spikeweed/spikeweed.tscn
parent: category_plants
extends: plant_base
---
# 地刺

地面持续伤害植物，靠每帧射线检测驱动攻击动画。

## 位置

| 项 | 值 |
|---|---|
| 场景 | `scenes/plants/front_yard/spikeweed/spikeweed.tscn` |
| 脚本 | `src/plants/front_yard/spikeweed/spikeweed.gd`（`extends plant_template`） |
| 卡片顺序 | `generate_cards.gd` 第 8 位 |

## 数值

| 项 | 值 | 来源 |
|---|---|---|
| 角色名 | **刺客** | 场景 `character_name` |
| 生命 | 100（默认，未覆盖） | `character_stats` 默认值 |
| 攻击间隔 | 0.5 秒 | 场景 `attack_speed_constant_value` |
| 攻击目标分组 | `zombie` | 场景 `attack_object` |
| 阳光消耗 | 25 | 场景 `sun_num` |
| 卡片冷却 | 15.0 秒 | 场景 `cool_time` |

> 场景里的 `character_name` 写的是「刺客」，与资料标题「地刺」不一致。这个值会作为关卡网格的占用登记名使用，属于既有数据，未改动。

## 行为

- 覆写 `_process`，每帧调用 `check_attack_ray(ray_cast_2d)`：
  - 命中 → `play_attack()` 播 `AnimationPlayer` 的 `attack`
  - 未命中 → `idle_code()` 播 `idle`
- 不依赖 `StateMachine` 的状态切换，状态机里的 `IDLE` / `ATTACK` 对它不生效。
- `attack()` 复制 `AnimatedSprite2D/Marker2D/Melee（挂场景上调整使用）` 生成伤害判定，按 `attack_object` 过滤，加入 `Globalmanager.bullets`。

## 关系

- 攻击判定节点：`AnimatedSprite2D/Marker2D/Melee（挂场景上调整使用）`
- 动画：`AnimationPlayer`
