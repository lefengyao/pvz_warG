---
schemaVersion: 1
id: sun_flower
title: 向日葵
type: character
description: 阳光生产植物：首次 6 秒、之后每 23 秒放出阳光；不参与攻击。
status: draft
version: 1
relations: []
source: agent
components:
  - path: specs/components/plant_card_cost.md
    key: cost
    values:
      cool_time: 7.5
      cooling: true
      sun_num: 50
scene: scenes/plants/front_yard/sun_flower/sun_flower.tscn
parent: category_plants
extends: plant_base
---
# 向日葵

阳光经济的第一产出点，不攻击，只按计时器持续放出阳光。

## 位置

| 项 | 值 |
|---|---|
| 场景 | `scenes/plants/front_yard/sun_flower/sun_flower.tscn` |
| 脚本 | `src/plants/front_yard/sun_flower/sun_flower.gd`（`extends plant_template`） |
| 状态脚本 | `src/plants/front_yard/sun_flower/idle.gd` |
| 卡片顺序 | `generate_cards.gd` 第 1 位 |

## 数值

| 项 | 值 | 来源 |
|---|---|---|
| 阳光消耗 | 50 | 场景 `sun_num` |
| 卡片冷却 | 7.5 秒 | 场景 `cool_time` |
| 生命 | 100（默认，未覆盖） | `character_stats` 默认值 |
| 攻击间隔 | 0（不攻击） | 未设置 |

## 阳光生产

- `_ready` 播放 `idle` 动画并启动 `Timer`，**首次等待 6 秒**。
- 首次超时后把 `wait_time` 改为 **23 秒**，之后固定 23 秒一发。
- `spawn_sun()` 流程：播 `attack` 动画 → 等 0.8 秒 → 在 `spawn_potition` 锚点周围、`spawn_radius`（默认 15）半径内按随机角度取偏移 → 实例化 `sun` 场景 → 加入 `Globalmanager.suns` → 切回 `idle`。

## 已知数据缺口

该场景内嵌的 `character` 子资源**只设置了 `bullet = null`**，未写 `character_name`，也未把 `attack_object` 从默认值 `plant` 改为 `zombie`。因此：

- 运行时 `character_name` 是默认的「未知角色」，关卡网格登记名字时用的是这个占位名；
- 向日葵本身不发起攻击，`attack_object` 目前不影响行为，但若后续给它加攻击逻辑会命中错误分组。

本资料按场景实际值记录，未改动工程数据。

## 关系

- 产出物：`scenes/objects/loot/sun/sun.tscn`（阳光掉落）
- 依赖：`Globalmanager.suns` 容器
