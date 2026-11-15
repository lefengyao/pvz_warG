---
schemaVersion: 1
id: pole_vaulting_zombie
title: 撑杆僵尸
type: enemy
description: 撑杆僵尸：120 生命，基础速度 -48；RUN 阶段 ×3、DASH 阶段 ×5，跳过植物后降为 ×0.7。
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
      character_name: 撑杆僵尸
      current_health: 120
      max_health: 120
      speed: -48
scene: scenes/zombies/front_yard/pole_vaulting_zombie/pole_vaulting_zombie.tscn
parent: category_zombies
extends: zombie_base
---
# 撑杆僵尸

三阶段僵尸：先冲刺、再撑杆跳过植物、落地后慢速行走。

## 位置

| 项 | 值 |
|---|---|
| 场景 | `scenes/zombies/front_yard/pole_vaulting_zombie/pole_vaulting_zombie.tscn` |
| 脚本 | `src/zombies/front_yard/pole_vaulting_zombie/pole_vaulting_zombie.gd`（`extends zombie_template`） |
| 状态脚本 | `idle.gd`、`run.gd`、`walk.gd`、`dash.gd`、`attack.gd`、`dead.gd` |

## 数值

| 项 | 值 | 来源 |
|---|---|---|
| 角色名 | 撑杆僵尸 | 场景 `character_name` |
| 最大生命 | 120 | 场景 `max_health` / `current_health` |
| 基础速度 | -48 | 场景 `speed` |
| 攻击间隔 | 1.6 秒 | 场景 `attack_speed_constant_value` |
| 攻击目标分组 | `plant`（默认） | `character_stats` 默认值 |
| 冲刺倍率 | 3.0 | `run_speed_multiplier` |
| 落地行走倍率 | 0.7 | `walk_speed_multiplier` |
| 防具 | 无 | — |

## 状态流程

| 状态 | 行为 |
|---|---|
| `RUN` | `_ready` 里 `super._ready()` 后立即切入；速度 = 基础 × 3.0（即 -144），`Sprite2D` 隐藏；射线命中植物时投出撑杆并切 `DASH` |
| `DASH` | 速度 = 基础 × 5.0（即 -240）；射线检测到**自己投出的杆**时执行跳跃 |
| 跳跃 | 播 `pole` 动画，用 Tween 在 1.0 秒内把 x 左移 80，随后速度切换为 基础 × 0.7（即 -33.6），进入 `WALK` |
| `WALK` | 常规左移，命中植物切 `ATTACK` |

- 投出的撑杆是独立 `Area2D`，加入 `level` 而不是子弹容器；`run.gd` 把 `die` 信号连到撑杆的 `dead`，让僵尸死亡时一并带走撑杆。
- `check_dash_ray()` 返回 `{type, body}`，`type` 为 `none` / `pole` / `plant`，用来区分「撞到自己的杆」和「撞到植物」。

## 信号

`die`：覆写 `dead_effect()` 时发出，供撑杆等外部对象联动清理。

## 关系

- 撑杆场景：`scenes/zombies/front_yard/pole_vaulting_zombie/pole.tscn`
- 撑杆掉落：`pole_loot_template.tscn`
