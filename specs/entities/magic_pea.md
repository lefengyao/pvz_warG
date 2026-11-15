---
schemaVersion: 1
id: magic_pea
title: 魔炮
type: character
description: 高费炮击植物：攻击间隔 2.8 秒，发射魔炮子弹。
status: draft
version: 1
relations: []
source: agent
components:
  - path: specs/components/character_stats.md
    key: stats
    values:
      attack_object: zombie
      attack_speed_constant_value: 2.8
      character_name: 魔炮
  - path: specs/components/plant_card_cost.md
    key: cost
    values:
      cool_time: 7.5
      cooling: true
      sun_num: 400
scene: scenes/plants/front_yard/magic_pea/magic_pea.tscn
parent: category_plants
extends: plant_base
---
# 魔炮

高费用、慢节奏的单发炮击植物。

## 位置

| 项 | 值 |
|---|---|
| 场景 | `scenes/plants/front_yard/magic_pea/magic_pea.tscn` |
| 脚本 | `src/plants/front_yard/magic_pea/magic_pea.gd`（`extends plant_template`） |
| 状态脚本 | `magic_pea/attack.gd`（`extends normal_attack`）、`magic_pea/idle.gd`（`extends normal_idle`） |
| 卡片顺序 | `generate_cards.gd` 第 5 位 |

## 数值

| 项 | 值 | 来源 |
|---|---|---|
| 角色名 | 魔炮 | 场景 `character_name` |
| 生命 | 100（默认，未覆盖） | `character_stats` 默认值 |
| 攻击间隔 | 2.8 秒 | 场景 `attack_speed_constant_value` |
| 攻击目标分组 | `zombie` | 场景 `attack_object` |
| 阳光消耗 | 400 | 场景 `sun_num` |
| 卡片冷却 | 7.5 秒 | 场景 `cool_time` |

## 行为

- `magic_pea.gd` 只缓存 `AnimationPlayer2`。
- `attack.gd` 覆写 `attack_effect()`，子弹生成后播 `attack_sfx`。
- `idle.gd` 覆写 `idle_code()`。
- 攻击间隔 2.8 秒是现有植物里最长的常规射手节奏（樱桃炸弹、土豆地雷的数值另有含义，见各自资料）。

## 关系

- 发射物：`scenes/projectiles/魔炮/魔炮子弹.tscn`（`bullet2`）
- 音效：`attack_sfx`，在 `ATTACK` 状态节点上配置
