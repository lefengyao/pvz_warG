---
schemaVersion: 1
id: plant_card_cost
title: 植物卡片费用
type: component
description: ""
fields:
  - key: sun_num
    label: 阳光消耗
    type: number
    default: 0
  - key: cool_time
    label: 卡片冷却（秒）
    type: number
    default: 0
  - key: cooling
    label: 启用冷却
    type: boolean
    default: true
scope: system
appearance:
  icon: component
  color: orange
group: 基础组件
---
# 植物卡片费用

对应 `src/plants/template/plant_template.gd` 中的三个 `@export`，决定这张植物卡片在选卡栏里的价格与冷却。数值写在每个植物场景上，不在卡片 UI 里另存。

## 字段映射

| 字段 | 脚本声明 | 说明 |
|---|---|---|
| `sun_num` | `@export var sun_num: int` | 种植消耗的阳光数 |
| `cool_time` | `@export var cool_time: float` | 卡片冷却秒数，种下后从冷却恢复开始计时 |
| `cooling` | `@export var cooling: bool = true` | 是否走冷却流程；默认开启 |

## 现有取值

| 植物 | sun_num | cool_time |
|---|---|---|
| 向日葵 | 50 | 7.5 |
| 豌豆射手 | 100 | 7.5 |
| 双重射手 | 200 | 7.5 |
| 寒冰射手 | 175 | 7.5 |
| 激光豆 | 175 | 7.5 |
| 魔炮 | 400 | 7.5 |
| 坚果 | 50 | 23.0 |
| 窝瓜 | 50 | 23.0 |
| 土豆地雷 | 25 | 23.0 |
| 地刺 | 25 | 15.0 |
| 樱桃炸弹 | 150 | 23.0 |
| 菜问 | 150 | 7.5 |
| 悟空 | 未设置 | 未设置 |

## 约束

- 该组件只对植物有意义，不要挂到僵尸上。
- `sun_num` 在种植成功时从 `Globalmanager.suns.sun_num` 扣减（`level.gd`）。
- 卡片顺序由 `src/autoload/generate_cards.gd` 的 `plant_cards` 数组决定，与费用无关。
