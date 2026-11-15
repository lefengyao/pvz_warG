---
schemaVersion: 1
id: loot_drop
title: 掉落产出
type: component
description: ""
fields:
  - key: loot_scene
    label: 掉落场景路径
    type: string
    default: ""
  - key: loot_texture
    label: 掉落纹理路径
    type: string
    default: ""
  - key: drop_point
    label: 掉落起点锚点
    type: string
    default: loot_point
  - key: generic_template
    label: 通用掉落模板
    type: string
    default: scenes/objects/loot/auto_despawn_loot/loot_template.tscn
scope: system
appearance:
  icon: component
  color: orange
groupId: group_basic_components
---
# 掉落产出

僵尸死亡时抛出的战利品，对应 `zombie_template` 的 `loot_head`、`loot_tex`、`loot_node` 三个 `@export` 与 `set_loot()` 流程。

## 字段

| 字段 | 来源 | 说明 |
|---|---|---|
| `loot_scene` | `@export var loot_head: PackedScene` | 专用掉落场景，优先按实例化使用 |
| `loot_texture` | `@export var loot_tex: Texture2D` | 只给纹理时，用通用掉落模板 + 该纹理 |
| `drop_point` | `@export var loot_node: Marker2D` | 掉落起点，`_ready` 时缓存全局坐标 |
| `generic_template` | 代码内 `load(...)` | 通用掉落场景路径 |

## 二选一逻辑

`set_loot()` 的分支：

| 优先级 | 条件 | 行为 |
|---|---|---|
| 1 | `loot_tex` 非空 | 加载通用模板 `scenes/objects/loot/auto_despawn_loot/loot_template.tscn`，把 `tex` 设为该纹理 |
| 2 | 否则 | 直接实例化 `loot_head` |

生成后设 `global_position = loot_head_position.global_position`，把 `loot_position`（掉落终点）传下去，挂到 `Globalmanager.loots`。

## 各僵尸现状

| 僵尸 | `loot_head` | 掉落说明 |
|---|---|---|
| 普通僵尸 | `ordinary_zombie/loot_head.tscn` | 通用头部落点 |
| 路障僵尸 | `ordinary_zombie/loot_head.tscn` | 同上；路障本身另有独立头盔掉落 |
| 铁桶僵尸 | `ordinary_zombie/loot_head.tscn` | 同上；铁桶另有独立头盔掉落 |
| 手枪僵尸 | `pistol_zombie/loot_pisol_zombie.tscn` | 专用掉落场景 |
| 撑杆僵尸 | `pole_vaulting_zombie/pole_loot_template.tscn` | 撑杆掉落 |
| 威龙 | `weilong/loot_weilong_head.tscn` | 专用掉落 |
| 刺客僵尸 | 未使用 | 覆写了 `dead()`，**不产出掉落** |

## 防具带来的额外出

路障、铁桶自身在生命归零时会独立抛出头盔掉落，走的是防具脚本自己的 `loot_tex` 与 `loot_position`，与本组件并行、互不替代。

## 约束

- 该组件只挂在僵尸模板上，植物没有掉落。
- 覆写 `dead()` 的僵尸必须显式决定是否保留 `set_loot()` 调用。
