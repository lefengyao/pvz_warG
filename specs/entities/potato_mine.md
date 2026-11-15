---
schemaVersion: 1
id: potato_mine
title: 土豆地雷
type: character
description: 埋设陷阱：18 秒准备时间，就绪后接触僵尸即引爆并自我销毁。
status: draft
version: 1
relations: []
source: agent
components:
  - path: specs/components/character_stats.md
    key: stats
    values:
      attack_object: zombie
      attack_speed_constant_value: 18
      character_name: 土豆地雷
  - path: specs/components/plant_card_cost.md
    key: cost
    values:
      cool_time: 23
      cooling: true
      sun_num: 25
scene: scenes/plants/front_yard/potato_mine/potato_mine.tscn
parent: category_plants
extends: plant_base
---
# 土豆地雷

埋设式陷阱，需要一段起爆准备时间。

## 位置

| 项 | 值 |
|---|---|
| 场景 | `scenes/plants/front_yard/potato_mine/potato_mine.tscn` |
| 脚本 | `src/plants/front_yard/potato_mine/potatomine.gd`（`extends plant_template`） |
| 卡片顺序 | `generate_cards.gd` 第 11 位 |

## 数值

| 项 | 值 | 来源 |
|---|---|---|
| 角色名 | 土豆地雷 | 场景 `character_name` |
| 生命 | 100（默认，未覆盖） | `character_stats` 默认值 |
| 攻击间隔字段 | 18.0 | 场景 `attack_speed_constant_value` |
| 攻击目标分组 | `zombie` | 场景 `attack_object` |
| 阳光消耗 | 25 | 场景 `sun_num` |
| 卡片冷却 | 23.0 秒 | 场景 `cool_time` |

> `attack_speed_constant_value` 在这里是**埋设准备时间**，不是射击间隔：`_ready` 直接把它赋给 `Timer.wait_time` 并启动。

## 生命周期

| 阶段 | 表现 |
|---|---|
| 种下 | `shadow` 隐藏，播 `idle1`，`Timer` 开始 18 秒倒计时 |
| 计时到 | `CollisionShape2D.visible = false`，播 `ermerge`，等 0.5 秒 |
| 就绪 | `shadow` 显示，播 `idle2`，把 `idle2` 标志置为 `true`，碰撞可见 |
| 触发 | `area_entered` 且目标属于 `attack_object` 分组、`idle2` 为真 → `attack()` |

`attack()` 实例化 `bullet1`，把 `attack_object` 传给子弹，`z_index = row * 10 + 3`，加入 `Globalmanager.bullets`，随后立即 `dead_()` 自我销毁。

## 实现观察

埋设阶段用 `CollisionShape2D.visible = false` 关闭显示，而不是 `disabled = true`。碰撞形状仍然参与检测，只是靠 `idle2` 标志挡住提前触发。若将来有其他逻辑直接改 `idle2`，埋设中的地雷可能被提前引爆。

## 关系

- 发射物：`bullet1`，在场景 `ATTACK` 节点上配置
