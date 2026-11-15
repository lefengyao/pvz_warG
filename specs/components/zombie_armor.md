---
schemaVersion: 1
id: zombie_armor
title: 僵尸防具槽
type: component
description: ""
fields:
  - key: armor_type
    label: 防具类别
    type: number
    default: 1
  - key: armor_scene
    label: 防具场景路径
    type: string
    default: ""
  - key: max_health
    label: 防具生命上限
    type: number
    default: 100
  - key: current_health
    label: 防具当前生命
    type: number
    default: 100
scope: system
appearance:
  icon: shield
  color: gray
group: 基础组件
---
# 僵尸防具槽

对应 `src/objects/armor/armor.gd`（`extends Resource`，`class_name armor`）与 `zombie_template` 中的 `armor1` / `armor2` 两个 `@export`。这是一个**槽位**组件：同一只僵尸可以挂两个实例，用 `key` 区分。

## 字段映射

| 字段 | 来源 | 说明 |
|---|---|---|
| `armor_type` | `armor.armor_type: int = 1` | 防具类别 |
| `armor_scene` | `armor.armor_scence: PackedScene` | 防具场景路径（字段只能存字符串） |
| `max_health` | 防具实例脚本 `@export var max_health` | 防具生命上限 |
| `current_health` | 防具实例脚本 `@export var current_health` | 防具当前生命；归零时隐藏并抛出头盔掉落 |

## 现有防具

| 防具 | 场景 | 生命 | 破损分级 |
|---|---|---|---|
| 路障 | `scenes/objects/armor/helmet/basic_helmet/路障.tscn` | 100 | 初始 / 轻度 / 重度（66%、33% 阈值） |
| 铁桶 | `scenes/objects/armor/helmet/basic_helmet/铁桶.tscn` | 300 | 初始 / 轻度 / 重度（66%、33% 阈值） |

## 伤害判定

`zombie_template.take_damage` 把伤害先交给 `a1`（armor1 实例），没有则交给 `a2`，最后才扣本体生命。防具的 `take_damage` 按弹药类型分流：

| `ammo_type` | 行为 |
|---|---|
| 1、3 | 防具扣血，返回溢出伤害（`-current_health`），溢出部分继续打本体 |
| 2 | 完全穿透，防具不掉血，伤害全部返回给本体 |
| 其他 | 不造成伤害 |

防具归零时在 `current_health` 的 setter 里隐藏自身、把 `loot_tex` 生成的头盔掉落加入 `Globalmanager.loots`，然后 `queue_free()`。

## 约束

- 槽位实例的 `key` 必须是 `armor_1` / `armor_2`，与模板中的 `armor1` / `armor2` 对应。
- 没有防具的僵尸不挂该组件。
- `armor_target1` / `armor_target2` 是挂载防具节点的锚点，不是本组件字段。
