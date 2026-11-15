---
schemaVersion: 1
id: conehead_zombie
title: 路障僵尸
type: enemy
description: 普通僵尸加路障防具：本体 100 生命，路障 100 生命，共 200 点有效伤害量。
status: draft
version: 1
relations: []
source: agent
components:
  - path: specs/components/zombie_armor.md
    key: armor_1
    values:
      armor_scene: scenes/objects/armor/helmet/basic_helmet/路障.tscn
      armor_type: 1
      current_health: 100
      max_health: 100
  - path: specs/components/character_stats.md
    key: stats
    values:
      attack_object: plant
      attack_speed_constant_value: 1.6
      character_name: 路障僵尸
      speed: -28
scene: scenes/zombies/front_yard/conehead_buckthead_zombie/conehead_zombie.tscn
parent: category_zombies
extends: zombie_base
---
# 路障僵尸

普通僵尸加一顶路障，先破防具再扣本体。

## 位置

| 项 | 值 |
|---|---|
| 场景 | `scenes/zombies/front_yard/conehead_buckthead_zombie/conehead_zombie.tscn` |
| 脚本 | 无专属脚本，沿用 `zombie_template` |
| 场景基底 | 继承 `ordinary_zombie.tscn` |

## 数值

| 项 | 值 | 来源 |
|---|---|---|
| 角色名 | 路障僵尸 | 场景 `character_name` |
| 本体生命 | 100（默认，未覆盖） | `character_stats` 默认值 |
| 移动速度 | -28 | 场景 `speed` |
| 攻击间隔 | 1.6 秒 | 场景 `attack_speed_constant_value` |
| 攻击目标分组 | `plant`（默认） | `character_stats` 默认值 |

## 防具

| 槽位 | 场景 | 生命 | 挂载点 |
|---|---|---|---|
| `armor_1` | `scenes/objects/armor/helmet/basic_helmet/路障.tscn` | 100 | `armor_target1`（`一类防具` Marker2D） |

- `armor_type` 未设置，取默认值 1。
- 防具受 1、3 类弹药伤害，2 类弹药直接穿透。
- 路障生命跌破 66%、33% 时依次切到「轻度破损」「重度破损」动画；归零时隐藏并按 `loot_tex` 抛出头盔掉落。

## 掉落

`loot_head` 指向 `scenes/zombies/front_yard/ordinary_zombie/loot_head.tscn`，落点 `Skeleton2D/躯干/头/Sprite2D`。

## 有效生命

本体 100 + 路障 100 = **200 点有效伤害量**（穿透类弹药按 100 计算）。
