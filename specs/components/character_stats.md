---
schemaVersion: 1
id: character_stats
title: 角色属性
type: component
description: ""
fields:
  - key: character_name
    label: 角色显示名
    type: string
    default: 未知角色
  - key: max_health
    label: 最大生命
    type: number
    default: 100
  - key: current_health
    label: 当前生命
    type: number
    default: 100
  - key: attack_speed_constant_value
    label: 攻击间隔（秒）
    type: number
    default: 0
  - key: attack_speed_ratio
    label: 攻速倍率
    type: number
    default: 1
  - key: speed
    label: 移动速度（像素/秒，负值向左）
    type: number
    default: 0
  - key: speed_ratio
    label: 移速倍率
    type: number
    default: 1
  - key: damage_ratio
    label: 受击伤害倍率
    type: number
    default: 1
  - key: attack_object
    label: 攻击目标分组
    type: string
    default: plant
scope: system
appearance:
  icon: character
  color: teal
group: 基础组件
---
# 角色属性

植物与僵尸共用的战斗数值容器，对应 `src/core/general_character.gd`（`extends Resource`，`class_name general_character`）。字段与脚本中的 `@export` 一一对应，不在此组件外另行复制一份数值。

**场地位置已拆到 `grid_placement`**：`row` / `column` 虽然同在这个脚本里，但属于场地事实而非战斗数值，单独建组件更清晰。

## 字段映射

| 字段 | 脚本声明 | 说明 |
|---|---|---|
| `character_name` | `String = "未知角色"` | 关卡网格按此名登记占用格子（`level.gd` 的 `two_d_array`） |
| `max_health` | `int = 100` | 生命上限 |
| `current_health` | `int = 100` | 当前生命；`<= 0` 时模板触发死亡流程 |
| `attack_speed_constant_value` | `float` | 攻击间隔，秒 |
| `attack_speed_ratio` | `float = 1.0` | 攻速倍率，叠乘在间隔上 |
| `speed` | `float` | 移动速度，僵尸用负值表示向左 |
| `speed_ratio` | `float = 1.0` | 移速倍率；减速状态由僵尸模板改写 |
| `damage_ratio` | `float = 1.0` | 受击伤害倍率；`zombie_template.take_damage` 中乘在扣血值上 |
| `attack_object` | `@export_enum("plant", "zombie") String = "plant"` | 攻击目标所在的场景分组，用于射线命中筛选 |

## 字段的非常规用法

有几个字段在不同角色上承担了不同语义，读数值时要注意：

| 字段 | 常规语义 | 变体用法 |
|---|---|---|
| `attack_speed_constant_value` | 攻击间隔 | 樱桃炸弹：引信 0.8 秒；土豆地雷：埋设 18 秒 |
| `speed` | 移动速度 | 植物恒为 0；僵尸为负值（左移） |
| `damage_ratio` | 受击倍率 | 目前所有角色都是 1.0，没有实际减伤配置 |

## 使用约定

- 该资源作为子资源内嵌在角色 `.tscn` 里（`character = SubResource(...)`），不单独存 `.tres`。
- `attack_object` 的默认值是 `plant`，因此**僵尸场景通常不写该字段**，植物场景显式写 `zombie`。
- 改字段名会同时影响全部角色场景的序列化属性，必须先处理引用者。

## 已知问题

`general_character.gd` 已不再声明 `bullet` 字段，但多个植物场景的内嵌 `character` 子资源里仍序列化着 `bullet = ExtResource(...)`。这是陈旧属性，读入时被忽略，容易被误认为「子弹配置在这里」。真正的子弹配置在 `ATTACK` 状态节点的 `bullet2`（`normal_attack`）或植物的 `bullet1`（炸弹类）。
