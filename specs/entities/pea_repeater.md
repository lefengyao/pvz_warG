---
schemaVersion: 1
id: pea_repeater
title: 双重射手
type: character
description: 连发豌豆射手：一轮两发、间隔 0.2 秒，40% 概率追加一轮。
status: draft
version: 1
relations: []
source: agent
components:
  - path: specs/components/character_stats.md
    key: stats
    values:
      attack_object: zombie
      attack_speed_constant_value: 1.8
      character_name: 双重射手
  - path: specs/components/plant_card_cost.md
    key: cost
    values:
      cool_time: 7.5
      cooling: true
      sun_num: 200
scene: scenes/plants/front_yard/pea_repeater/pea_repeater.tscn
parent: category_plants
extends: plant_base
---
# 双重射手

豌豆射手的连发强化版，一轮打出两发，并有概率追加一轮。

## 位置

| 项 | 值 |
|---|---|
| 场景 | `scenes/plants/front_yard/pea_repeater/pea_repeater.tscn` |
| 脚本 | `src/plants/front_yard/pea_reapeater/pea_repeater.gd`（`extends plant_template`） |
| 状态脚本 | `pea_reapeater/attack.gd`、`pea_reapeater/idle.gd` |
| 卡片顺序 | `generate_cards.gd` 第 3 位 |

> 注意路径拼写：**资源目录是 `pea_reapeater`（多一个 `a`）**，场景目录是 `pea_repeater`。两个名字不一致是既有状况，未在本轮改动。

## 数值

| 项 | 值 | 来源 |
|---|---|---|
| 角色名 | 双重射手 | 场景 `character_name` |
| 生命 | 100（默认，未覆盖） | `character_stats` 默认值 |
| 攻击间隔 | 1.8 秒 | 场景 `attack_speed_constant_value` |
| 攻击目标分组 | `zombie` | 场景 `attack_object` |
| 阳光消耗 | 200 | 场景 `sun_num` |
| 卡片冷却 | 7.5 秒 | 场景 `cool_time` |

## 攻击节奏

`attack.gd` 覆写了 `attack()`，逻辑为：

1. `double_attack()`：发射一发 → 等 **0.2 秒** → 再发射一发。
2. 取 `randf_range(0, 1.0)`，**≤ 0.4（40% 概率）** 时再等 0.3 秒并再执行一次 `double_attack()`，也就是一轮最多 4 发。

## 实现观察

- `double_attack()` 内第二发子弹加到了 `Globalmanager`，而不是 `Globalmanager.bullets`；同一次循环的第一发和其他植物都走 `Globalmanager.bullets`。这会让第二发脱离关卡统一的子弹容器，清场与层级管理可能与预期不符。**属既有代码，本资料只记录不改动。**
- `attack.gd` 覆写的 `play_attack()` 播放 `AnimationPlayer2` 的 `attack`，动画事件才真正触发 `attack()`。

## 关系

- 发射物：`scenes/projectiles/pea/ordinary_pea/pean.tscn`（`bullet2`）
