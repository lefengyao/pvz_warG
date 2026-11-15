---
schemaVersion: 1
id: cherry_bomb
title: 樱桃炸弹
type: character
description: 延时炸弹：0.8 秒引信后引爆并自我销毁，2000 生命。
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
      character_name: 樱桃炸弹
      current_health: 2000
      max_health: 2000
  - path: specs/components/plant_card_cost.md
    key: cost
    values:
      cool_time: 23
      cooling: true
      sun_num: 150
scene: scenes/plants/front_yard/cherry_bomb/cherry_bomb.tscn
parent: category_plants
extends: plant_base
---
# 樱桃炸弹

延时引爆的范围炸弹，引爆后自身消失。

## 位置

| 项 | 值 |
|---|---|
| 场景 | `scenes/plants/front_yard/cherry_bomb/cherry_bomb.tscn` |
| 脚本 | `src/plants/front_yard/cherry_bomb/cherry_bomb.gd`（`extends plant_template`） |
| 卡片顺序 | `generate_cards.gd` 第 10 位 |

## 数值

| 项 | 值 | 来源 |
|---|---|---|
| 角色名 | 樱桃炸弹 | 场景 `character_name` |
| 最大生命 | 2000 | 场景 `max_health` / `current_health` |
| 引信时长 | 0.8 秒 | 场景 `attack_speed_constant_value` |
| 攻击目标分组 | `zombie` | 场景 `attack_object` |
| 阳光消耗 | 150 | 场景 `sun_num` |
| 卡片冷却 | 23.0 秒 | 场景 `cool_time` |

> `attack_speed_constant_value` 在这里是**引信时间**：`_ready` 把它赋给 `Timer.wait_time` 并启动，而不是射击间隔。

## 行为

1. `_ready` 播 `attack` 动画，`Timer.wait_time = 0.8`，先 `stop()` 再 `start()`。
2. 超时触发 `attack()`：实例化 `bullet1`，设 `attack_object` 与 `z_index = row * 10 + 3`，用 `call_deferred` 加入 `Globalmanager.bullets`。
3. 随即 `dead_()`，发 `dead` 信号并释放自身。

## 关系

- 爆炸判定：`bullet1`，在场景上配置
- 场景内另有 `9_cell_bomb.tscn` 与 `1_cell_bomb.tscn` 两种炸弹模板，分别在 `scenes/projectiles/bomb/` 下
