---
schemaVersion: 1
id: squash
title: 窝瓜
type: character
description: 一次性跳砸植物：400 生命，锁定目标后瞬移砸下并自我销毁。
status: draft
version: 1
relations: []
source: agent
components:
  - path: specs/components/character_stats.md
    key: stats
    values:
      attack_object: zombie
      attack_speed_constant_value: 0.4
      character_name: 窝瓜
      current_health: 400
      max_health: 400
  - path: specs/components/plant_card_cost.md
    key: cost
    values:
      cool_time: 23
      cooling: true
      sun_num: 50
scene: scenes/plants/front_yard/squash/squash.tscn
parent: category_plants
extends: plant_base
---
# 窝瓜

一次性跳砸植物，砸下后自身消失。

## 位置

| 项 | 值 |
|---|---|
| 场景 | `scenes/plants/front_yard/squash/squash.tscn` |
| 脚本 | `src/plants/front_yard/squash/squash.gd`（`extends plant_template`） |
| 状态脚本 | `squash/attack.gd`（`extends normal_attack`）、`squash/idle.gd` |
| 卡片顺序 | `generate_cards.gd` 第 7 位 |

## 数值

| 项 | 值 | 来源 |
|---|---|---|
| 角色名 | 窝瓜 | 场景 `character_name` |
| 最大生命 | 400 | 场景 `max_health` / `current_health` |
| 攻击间隔 | 0.4 秒 | 场景 `attack_speed_constant_value` |
| 攻击目标分组 | `zombie` | 场景 `attack_object` |
| 阳光消耗 | 50 | 场景 `sun_num` |
| 卡片冷却 | 23.0 秒 | 场景 `cool_time` |

## 攻击流程

`attack.gd` 的 `enter()` 调用 `play_attack()`：

1. 播 `squash_hmm.wav` 发现音效。
2. 播放 `AnimationPlayer2` 的 `jump` 并等待结束。
3. 记录 `owner_root.enemy` 的 x 坐标；若目标在自身左侧，把 `scale.x` 置为 -1 翻转朝向。
4. 把自身 x 瞬移到目标 x，播放 `fall`，播 `gargantuar_thump.wav` 落地音效。
5. `fall` 播完调用 `owner_root.dead_()`，自身消失。

同脚本的 `attack()` 会复制 `Melee` 子节点生成伤害判定，按 `character.attack_object` 过滤目标，`z_index = row * 10 + 3`，加入 `Globalmanager.bullets`。

## 依赖字段

- `owner_root.enemy`：由 `squash.gd` 的 `var enemy` 保存，外部检测逻辑写入。
- `owner_root.marker_2d`：`AnimatedSprite2D/Marker2D`，即 `muzzle` 锚点。

## 说明

`attack_speed_constant_value = 0.4` 在这个植物上不是射击间隔，而是动作节奏参数；真正的触发时机由 `IDLE → ATTACK` 的状态切换决定。
