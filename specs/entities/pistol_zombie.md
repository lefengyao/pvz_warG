---
schemaVersion: 1
id: pistol_zombie
title: 手枪僵尸
type: enemy
description: 远程僵尸：200 生命、速度 -20，到倒数第二列先连开两枪，之后持续射击。
status: draft
version: 1
relations: []
source: agent
components:
  - path: specs/components/character_stats.md
    key: stats
    values:
      attack_object: plant
      attack_speed_constant_value: 2
      character_name: 手枪僵尸
      current_health: 200
      max_health: 200
      speed: -20
scene: scenes/zombies/front_yard/pistol_zombie/pistol_zombie.tscn
parent: category_zombies
extends: zombie_base
---
# 手枪僵尸

远程僵尸，会在指定列停下先打两枪，之后持续射击。

## 位置

| 项 | 值 |
|---|---|
| 场景 | `scenes/zombies/front_yard/pistol_zombie/pistol_zombie.tscn` |
| 脚本 | `src/zombies/front_yard/pistol_zombie/pistol_zombie.gd`（`extends zombie_template`） |
| 状态脚本 | `idle.gd`、`walk.gd`、`attack.gd`、`dead.gd` |

## 数值

| 项 | 值 | 来源 |
|---|---|---|
| 角色名 | 手枪僵尸 | 场景 `character_name` |
| 最大生命 | 200 | 场景 `max_health` / `current_health` |
| 移动速度 | -20 | 场景 `speed` |
| 攻击间隔 | 2.0 秒 | 场景 `attack_speed_constant_value` |
| 攻击目标分组 | `plant`（默认） | `character_stats` 默认值 |
| 防具 | 无 | 未配置 `armor1` / `armor2` |

## 行为

- 场景额外挂载 `gun_position`（枪口 Marker2D）、`RayCast2D/RayCast2D2`（远程射线）、`Timer`、`GunBullet` 模板与 `gun_sfx`。
- `set_attack()` 复制 `GunBullet` 生成子弹，把 `attack_object` 传下去，`is_run = true`，加入 `Globalmanager.bullets`。
- `walk.gd` 的首次射击逻辑：当自身进入关卡左右边界之间、且所在列等于 `level.cell_column - 2` 时，连续播放两次 `gunshot` 动画，并置 `first_shoot = true`。
- 之后每帧左移，射线命中植物切 `ATTACK`。
- `Timer` 超时且处于行走时，用第二条射线 `RayCast2D2` 再检测一次，命中则再播 `gunshot`。
- `attack.gd`（近战分支）：用 `Melee` 复制攻击判定，位于 `attack_position`，命中条件仍是 `attack_object` 分组。

## 说明

普通僵尸的速度是 -28，手枪僵尸是 -20，比普通僵尸更慢；配合 200 点生命与远程攻击形成差异化。

## 关系

- 子弹：`scenes/projectiles/gun/gun_bullet.tscn`
- 近战判定：`scenes/projectiles/melee_bullet/melee_template/melee.tscn`
