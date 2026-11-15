---
schemaVersion: 1
id: ordinary_zombie
title: 普通僵尸
type: enemy
description: 僵尸模板本体：100 生命、速度 -28、攻击间隔 1.6 秒，无防具。
status: draft
version: 1
relations: []
source: agent
components:
  - path: specs/components/character_stats.md
    key: stats
    values:
      attack_object: plant
      attack_speed_constant_value: 1.6
      character_name: 普通僵尸
      speed: -28
scene: scenes/zombies/front_yard/ordinary_zombie/ordinary_zombie.tscn
parent: category_zombies
extends: zombie_base
---
# 普通僵尸

僵尸模板本体，也是其余僵尸的继承起点。没有防具、没有特殊技能。

## 位置

| 项 | 值 |
|---|---|
| 场景 | `scenes/zombies/front_yard/ordinary_zombie/ordinary_zombie.tscn` |
| 脚本 | `src/zombies/front_yard/ordinary_zombie/ordinary_zombie.gd`（`class_name zombie_template`） |
| 状态脚本 | `ordinary_zombie/idle.gd`、`walk.gd`、`attack.gd`、`dead.gd` |

## 数值

| 项 | 值 | 来源 |
|---|---|---|
| 角色名 | 普通僵尸 | 场景 `character_name` |
| 最大生命 | 100（默认，未覆盖） | `character_stats` 默认值 |
| 移动速度 | -28（向左） | 场景 `speed` |
| 攻击间隔 | 1.6 秒 | 场景 `attack_speed_constant_value` |
| 攻击目标分组 | `plant`（默认，未覆盖） | `character_stats` 默认值 |
| 防具 | 无 | 未配置 `armor1` / `armor2` |
| 掉落 | `loot_head` 或 `loot_tex` | 场景配置 |

## 行为

继承 `zombie_base` 的全部流程，没有额外覆写：

- `_ready` 缓存 `level`、给速度乘 `randf_range(1, 1.2)`、连接 `be_attack` 闪白、切 `WALK`。
- 行走时按 `speed × speed_ratio` 左移，射线命中植物切 `ATTACK`。
- 死亡走模板的 `dead()`：禁碰撞、播 `dead` 动画与 `fall_sfx`、生成掉落、等动画结束释放。

## 说明

由于本场景就是模板场景，其他僵尸的场景通常以它为基底继承。改这个文件等于同时改所有僵尸的默认值。

## 关系

- 被 `zombie_spawner` 的波次配置引用
- 掉落物：`scenes/objects/loot/auto_despawn_loot/loot_template.tscn`（使用 `loot_tex` 时）
