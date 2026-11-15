---
schemaVersion: 1
id: ice_shooter
title: 寒冰射手
type: character
description: 减速射手：攻击间隔 1.0 秒，命中后使僵尸减速；当前场景缺少 ATTACK 子弹配置。
status: draft
version: 1
relations: []
source: agent
components:
  - path: specs/components/character_stats.md
    key: stats
    values:
      attack_object: zombie
      attack_speed_constant_value: 1
      character_name: 寒冰射手
  - path: specs/components/plant_card_cost.md
    key: cost
    values:
      cool_time: 7.5
      cooling: true
      sun_num: 175
scene: scenes/plants/front_yard/ice_shooter/ice_shooter.tscn
parent: category_plants
extends: plant_base
---
# 寒冰射手

豌豆射手的减速变体，发射冰豌豆。

## 位置

| 项 | 值 |
|---|---|
| 场景 | `scenes/plants/front_yard/ice_shooter/ice_shooter.tscn` |
| 脚本 | `src/plants/front_yard/ice_shooter/ice_shooter.gd`（`extends plant_template`） |
| 状态脚本 | 未覆写，沿用模板的 `normal_idle` / `normal_attack` |
| 卡片顺序 | `generate_cards.gd` 未登记 |

## 数值

| 项 | 值 | 来源 |
|---|---|---|
| 角色名 | 寒冰射手 | 场景 `character_name` |
| 生命 | 100（默认，未覆盖） | `character_stats` 默认值 |
| 攻击间隔 | 1.0 秒 | 场景 `attack_speed_constant_value` |
| 攻击目标分组 | `zombie` | 场景 `attack_object` |
| 阳光消耗 | 175 | 场景 `sun_num` |
| 卡片冷却 | 7.5 秒 | 场景 `cool_time` |

## 行为

- `ice_shooter.gd` 只有两个覆写：`play_attack()` 播 `AnimationPlayer2` 的 `attack`，`idle_code()` 播 `idle`。
- 状态机沿用 `plant_template.tscn` 自带的 `IDLE`（`normal_idle`）与 `ATTACK`（`normal_attack`）。
- 减速效果来自冰豌豆（`scenes/projectiles/pea/ice_pea/ice_pean.tscn`）命中后调用僵尸的 `set_slow_down()`。

## 待确认的配置缺口

`normal_attack.attack()` 依赖 `bullet2` 实例化子弹，而**寒冰射手场景没有覆写 `ATTACK` 节点，也没有设置 `bullet2`**；场景里只有内嵌 `character` 子资源上的 `bullet` 属性，但 `general_character.gd` 已经没有 `bullet` 字段，该属性属于陈旧序列化数据。

因此这条发射链路缺少有效的子弹配置。实际表现取决于 `AnimationPlayer2` 的 `attack` 动画是否带方法轨道调用 `attack()`：若调用，会因 `bullet2` 为空而失败；若不调用，则不会射出冰豌豆。本资料只记录配置现状，未做运行验证，也未改动工程。

## 关系

- 预期发射物：`scenes/projectiles/pea/ice_pea/ice_pean.tscn`
