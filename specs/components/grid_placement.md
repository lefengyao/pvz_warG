---
schemaVersion: 1
id: grid_placement
title: 场地位置
type: component
description: ""
fields:
  - key: row
    label: 行号
    type: number
    default: 0
  - key: column
    label: 列号
    type: number
    default: 0
scope: system
appearance:
  icon: position
  color: teal
group: 基础组件
---
# 场地位置

角色在关卡网格中的位置，对应 `general_character.gd` 的 `row` / `column` 两个 `@export`。从 `character_stats` 里拆出来，因为位置是**场地事实**，不是战斗数值。

## 字段

| 字段 | 脚本声明 | 说明 |
|---|---|---|
| `row` | `@export var row: int` | 行号，由种植或刷怪逻辑写入 |
| `column` | `@export var column: int` | 列号，同上 |

## 写入时机

| 角色类型 | 写入者 |
|---|---|
| 植物 | `level.gd` 的 `_on_area_2d_input_event`，种植时按点击格子写入 |
| 僵尸 | `zombie_spawner` 生成时写入 |

## 派生规则

网格坐标同时决定渲染层级，两类角色的约定一致：

```
z_index = row * 10 + n
```

| n | 用途 |
|---|---|
| 1 | 植物本体 |
| 3 | 子弹与近战判定（所有 `Globalmanager.bullets` 里的对象） |
| 3 | 草坪机（`lawnmower`） |

同一行内靠 n 值分层，跨行靠 `row` 的十位数分层。`level.gd` 在种植时给植物设 `z_index = row * 10 + 1`；各攻击脚本在生成子弹时设 `row * 10 + 3`。

## 反查

僵尸模板的 `get_column()` 用 `level.get_pos(global_position - Vector2(0, level.cell_height))` 反查当前列，用于触发「到第 N 列做某事」的判断（手枪僵尸的首轮射击、刺客僵尸的冲刺清场）。

## 约束

- 该组件对不落在网格上的对象（子弹、阳光、掉落物）没有意义，不要挂。
- 关卡尺寸来自 `level.gd` 的 `cell_row` / `cell_column` 与四个定位 Marker2D，不在本组件里重复。
