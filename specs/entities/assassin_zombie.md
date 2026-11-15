---
schemaVersion: 1
id: assassin_zombie
title: 刺客僵尸
type: enemy
description: 刺客僵尸：400 生命，冲刺阶段速度 -2304，冲到最内列直接清空本行植物；死亡无掉落。
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
      character_name: 刺客僵尸
      current_health: 400
      max_health: 400
      speed: -48
scene: scenes/zombies/front_yard/assassin_zombie/assassin_zombie.tscn
parent: category_zombies
extends: zombie_base
---
# 刺客僵尸

高生命、带位移技能的特殊僵尸：撞到植物会前进或后撤，冲刺到最内列直接清场。

## 位置

| 项 | 值 |
|---|---|
| 场景 | `scenes/zombies/front_yard/assassin_zombie/assassin_zombie.tscn` |
| 脚本 | `src/zombies/front_yard/assassin_zombie/assassin_zombie.gd`（`extends zombie_template`） |
| 状态脚本 | `idle.gd`、`walk.gd`、`attack.gd`、`dash.gd`、`parry.gd`、`dead.gd` |

## 数值

| 项 | 值 | 来源 |
|---|---|---|
| 角色名 | 刺客僵尸 | 场景 `character_name` |
| 最大生命 | 400 | 场景 `max_health` / `current_health` |
| 移动速度 | -48 | 场景 `speed` |
| 攻击间隔 | 1.6 秒 | 场景 `attack_speed_constant_value` |
| 攻击目标分组 | `plant`（默认） | `character_stats` 默认值 |
| 攻击类型 | 1 | `ready_effect` 中覆写 `attack_type` |
| 防具 | 无 | — |

## 碰撞分支

`_on_ordinary_zombie_area_entered(area)` 按目标分组决定反应：

| 目标分组 | 反应 |
|---|---|
| `defence_plant` | 目标扣 `max_health × 0.6`，自身进入 `PARRY`，位移 0、时长 0 |
| `melee_type_plant` | 自身进入 `PARRY`，后退 600 距离、耗时 1.0 秒，并调用目标植物的 `parry()` |
| 其他 | 目标生命直接减到 0，播 `slay_sfx` |

## 冲刺（`dash.gd`）

- `enter` 播 `dash` 动画、开粒子，把速度临时改为 `-48 × 48 = -2304`。
- 每帧左移；一旦进入关卡边界且**所在列等于 1**，遍历 `get_overlapping_areas()`，把命中 `attack_object` 分组的目标生命直接清空，播 `slay_sfx`，切回 `WALK`。
- `exit` 把速度还原为 -48。

## 后撤（`parry.gd`）

`pull_back(distance, duration)` 用 Tween 在给定时长内把 x 右移指定距离，完成后发 `pull` 信号并切回 `WALK`。`enter` 会先播 `parry_sfx` 与 `parry` 动画。

## 死亡（覆写 `dead()`）

与其他僵尸不同，刺客僵尸**不走模板的掉落流程**：

- 置 `is_loot`、禁用碰撞、播 `AnimationPlayer2` 的 `dead`。
- `death_walk()` 用 Tween 在 1.5 秒内把 x 右移 150，形成滑步。
- 播 `fall_sfx`，等动画结束直接 `queue_free()`，不生成掉落。
