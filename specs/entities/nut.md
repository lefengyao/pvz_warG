---
schemaVersion: 1
id: nut
title: 坚果
type: character
description: 肉盾植物：2000 生命、不攻击，按血量切换三档破损外观。
status: draft
version: 1
relations: []
source: agent
components:
  - path: specs/components/character_stats.md
    key: stats
    values:
      character_name: 坚果
      current_health: 2000
      max_health: 2000
  - path: specs/components/plant_card_cost.md
    key: cost
    values:
      cool_time: 23
      cooling: true
      sun_num: 50
scene: scenes/plants/front_yard/nut/nut.tscn
parent: category_plants
extends: plant_base
---
# 坚果

纯肉盾植物，生命远高于常规植物且不攻击。

## 位置

| 项 | 值 |
|---|---|
| 场景 | `scenes/plants/front_yard/nut/nut.tscn` |
| 脚本 | `src/plants/front_yard/nut/nut.gd`（`extends plant_template`） |
| 卡片顺序 | `generate_cards.gd` 第 6 位 |

## 数值

| 项 | 值 | 来源 |
|---|---|---|
| 角色名 | 坚果 | 场景 `character_name` |
| 最大生命 | 2000 | 场景 `max_health` / `current_health` |
| 攻击间隔 | 未设置（不攻击） | — |
| 攻击目标分组 | 默认 `plant`（未覆盖） | `character_stats` 默认值 |
| 阳光消耗 | 50 | 场景 `sun_num` |
| 卡片冷却 | 23.0 秒 | 场景 `cool_time` |

## 行为

- `_ready` 播放 `AnimationPlayer2` 的 `swing` 出场动画。
- `_process` 按生命比例切换外观：

| 生命区间 | 动画 |
|---|---|
| `current_health <= 0` | 调用 `dead_()` |
| `< max_health × 0.33` | `idle3` |
| `< max_health × 0.66` | `idle2` |
| 其余 | `idle1` |

- 没有 `ATTACK` 行为脚本覆写，`bullet` 为 `null`，靠 2000 点生命拖住僵尸。

## 说明

该场景未把 `attack_object` 从默认值 `plant` 改成 `zombie`。坚果不发起攻击，目前不影响行为。

## 关系

- 与 `defence_plant` 分组配合：刺客僵尸的碰撞逻辑会对 `defence_plant` 分组的植物造成 `max_health × 0.6` 的伤害并进入 `PARRY` 状态。
