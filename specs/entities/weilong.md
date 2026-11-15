---
schemaVersion: 1
id: weilong
title: 威龙
type: enemy
description: 技能僵尸：250 生命，喷气位移 400~500 距离，向命中植物贴 2 个 C4。
status: draft
version: 1
relations: []
source: agent
components:
  - path: specs/components/character_stats.md
    key: stats
    values:
      attack_object: plant
      character_name: 威龙
      current_health: 250
      max_health: 250
      speed: -50
scene: scenes/zombies/front_yard/weilong/weilong.tscn
parent: category_zombies
extends: zombie_base
---
# 威龙

具备位移与投掷技能的僵尸：先喷气绕后，再向命中的植物贴 C4。

## 位置

| 项 | 值 |
|---|---|
| 场景 | `scenes/zombies/front_yard/weilong/weilong.tscn` |
| 脚本 | `src/zombies/front_yard/weilong/weilong.gd`（`extends zombie_template`） |
| 状态脚本 | `idle.gd`、`walk.gd`、`attack.gd`、`jet.gd`、`dead.gd` |

## 数值

| 项 | 值 | 来源 |
|---|---|---|
| 角色名 | 威龙 | 场景 `character_name` |
| 最大生命 | 250 | 场景 `max_health` / `current_health` |
| 移动速度 | -50 | 场景 `speed` |
| 攻击间隔 | 未设置（默认 0） | `character_stats` 默认值 |
| 攻击目标分组 | `plant`（默认） | `character_stats` 默认值 |
| C4 数量 | 2 | `c4_num` 初值 |
| 防具 | 无 | — |

## 喷气（`jet.gd` 与 `jet()`）

- `ready_effect()` 会先按自身所在分组判断 `self_type`（`zombie` 或 `plant`），然后立即切 `JET`。
- `jet(x1, x2)` 播 `jet` 动画与 `jet_sfx`，用 Tween 在 1.0 秒内把 x 左移 `randf_range(400, 500)`。
- 位移结束后若已进入 `DEAD` 就不再切状态，否则切 `WALK`。

## 投掷 C4

- `jet.gd` 每帧调用 `check_attack_ray(ray_cast_2d)`，命中即 `throw_c4(body)`。
- `throw_c4(p)` 在 `c4_num > 0` 时减 1，实例化 `c_4` 场景并挂到命中目标节点下，同时把 `attack_object` 传下去。
- C4 自身 `_ready` 播 `c4_sfx` 并上浮 `(5~15, -50)`；引爆时 `dead()` 生成爆炸子弹加入 `Globalmanager.bullets`。

## 说明

`attack_speed_constant_value` 没有配置，因此模板 `ATTACK` 状态的攻击间隔是 0。该僵尸的实际威胁来自喷气位移与 C4，而不是常规啃咬节奏。

## 关系

- C4 场景：`scenes/zombies/front_yard/weilong/c4.tscn`
- 头部掉落：`loot_weilong_head.tscn`
- 音效：`jet_sfx`、`weilong_voice`、C4 自身的 `c4_sfx`
