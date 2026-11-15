---
schemaVersion: 1
id: wukong
title: 悟空
type: character
description: 原型近战植物：三段蓄力棍法，武器伤害 250/150 乘以蓄力段数；未进选卡列表。
status: draft
version: 1
relations: []
source: agent
components:
  - path: specs/components/character_stats.md
    key: stats
    values:
      attack_object: plant
      character_name: 未知角色
      max_health: 100
scene: scenes/plants/front_yard/wukong/wukong.tscn
parent: category_plants
extends: plant_base
---
# 悟空

原型阶段的近战植物，直接实例化植物模板场景并额外挂载棍法与武器子系统。

## 位置

| 项 | 值 |
|---|---|
| 场景 | `scenes/plants/front_yard/wukong/wukong.tscn` |
| 根节点 | 实例化 `scenes/plants/template/plant_template.tscn`，未挂专属根脚本 |
| 子系统脚本 | `src/plants/front_yard/wukong/staff_stance.gd`、`weapon.gd`、`weapon/rotate_stick.gd` |
| 卡片顺序 | `generate_cards.gd` 未登记 |

## 数值

该场景**没有内嵌 `character` 子资源**，因此全部取 `character_stats` 默认值：

| 项 | 值 |
|---|---|
| 角色名 | 未知角色（默认） |
| 最大生命 | 100（默认） |
| 攻击目标分组 | `plant`（默认） |
| 阳光消耗 / 冷却 | 未设置 |

## 蓄力棍法（`staff_stance.gd`）

| 参数 | 值 |
|---|---|
| `PHASE_COSTS` | `[40, 60, 80]`，三段蓄力各段所需能量 |
| `REGEN_RATE` | 8.0 /秒，自动回复 |
| `current_phase` | 0 到 3 |
| 音效 | 每段完成播 `xuli`，第三段播 `xuli3` |

- 自动蓄力由 `_process` 驱动，`is_auto_charging` 默认为真。
- 两个 `TextureProgressBar`（`pigun`、`pigun2`）显示当前段能量百分比；三个 `Sprite2D` 表示已达成的段数。
- 切换棍型由 `switch_state()` / `toggle_gun()` 完成，`pigun` 与 `chuogun` 二选一显示。
- 信号：`pigun_fired(gun_type, charged_phases)`、`chuogun_fired(gun_type, charged_phases)`、`gun(0|1)`。

## 武器伤害（`weapon.gd`）

| 棍型 | 基础伤害 | 实际伤害 |
|---|---|---|
| `pigun` | 250 | `250 × current_phase` |
| `chuogun` | 150 | `150 × current_phase` |

命中判定为 `area.is_in_group(attack_object)`，随后调用 `area.take_damage(伤害, ammo_type)`，`ammo_type` 默认 1。

## 旋转棍（`rotate_stick.gd`）

| 参数 | 值 |
|---|---|
| `speed` | 100（向右位移/秒） |
| `attack` | 20 |
| `max_hits` | 3 |
| `rotation_speed` | 1080 度/秒 |

命中 3 次后释放；飞出 `x > 1500` 或 `x < -500` 也释放。

## 状态

未覆写 `IDLE` / `ATTACK`，沿用模板的 `normal_idle` / `normal_attack`，而 `bullet2` 未配置。该植物的攻击实际由 `weapon` 子系统的 `Area2D` 与蓄力按钮驱动，常规射手链路对它没有意义。整体处于原型状态，尚未进入选卡列表。
