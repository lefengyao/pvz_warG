---
schemaVersion: 1
id: buckthead_zombie
title: 铁桶僵尸
type: enemy
description: 普通僵尸加铁桶防具：本体 100 生命，铁桶 300 生命，共 400 点有效伤害量。
status: draft
version: 1
relations: []
source: agent
components:
  - path: specs/components/zombie_armor.md
    key: armor_1
    values:
      armor_scene: scenes/objects/armor/helmet/basic_helmet/铁桶.tscn
      armor_type: 1
      current_health: 300
      max_health: 300
  - path: specs/components/character_stats.md
    key: stats
    values:
      attack_object: plant
      attack_speed_constant_value: 1.6
      character_name: 铁通僵尸
      speed: -28
scene: scenes/zombies/front_yard/conehead_buckthead_zombie/buckthead_zombie.tscn
parent: category_zombies
extends: zombie_base
---
# 铁桶僵尸

普通僵尸加铁桶防具，有效生命远高于路障僵尸。

## 位置

| 项 | 值 |
|---|---|
| 场景 | `scenes/zombies/front_yard/conehead_buckthead_zombie/buckthead_zombie.tscn` |
| 脚本 | 无专属脚本，沿用 `zombie_template` |
| 场景基底 | 继承 `ordinary_zombie.tscn` |

## 数值

| 项 | 值 | 来源 |
|---|---|---|
| 角色名 | **铁通僵尸** | 场景 `character_name` |
| 本体生命 | 100（默认，未覆盖） | `character_stats` 默认值 |
| 移动速度 | -28 | 场景 `speed` |
| 攻击间隔 | 1.6 秒 | 场景 `attack_speed_constant_value` |
| 攻击目标分组 | `plant`（默认） | `character_stats` 默认值 |

> 场景里的 `character_name` 写的是「铁通僵尸」，与目录名 `buckthead`（应为 buckethead）和通称「铁桶僵尸」都不一致。这属于既有数据，本轮未改动；本资料标题按通称写「铁桶僵尸」，并在数值表里标出场景原值。

## 防具

| 槽位 | 场景 | 生命 | 挂载点 |
|---|---|---|---|
| `armor_1` | `scenes/objects/armor/helmet/basic_helmet/铁桶.tscn` | 300 | `armor_target1`（`一类防具` Marker2D） |

- `armor_type` 未设置，取默认值 1。
- 铁桶破坏动画分三档（66%、33%），归零时抛出头盔掉落。
- 铁桶收到 1、3 类弹药伤害；2 类弹药穿透。

## 掉落

`loot_head` 指向 `scenes/zombies/front_yard/ordinary_zombie/loot_head.tscn`，落点 `Skeleton2D/躯干/头/Sprite2D`。

## 有效生命

本体 100 + 铁桶 300 = **400 点有效伤害量**（穿透类弹药按 100 计算）。
