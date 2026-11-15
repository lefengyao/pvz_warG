---
schemaVersion: 1
id: category_plants
title: 植物
type: entity
description: 分类节点：植物侧资料目录，成员全部继承植物模板 plant_base。
status: draft
version: 1
relations: []
source: agent
components: []
appearance:
  icon: entity
  color: green
parent: category_characters
---
# 植物（分类）

资料目录节点，对应代码中的植物侧：`scenes/plants/`、`src/plants/`。

## 共同点

本分类下所有角色都继承植物模板 `plant_base`，并且都运行在 `Area2D` 上、加入场景分组 `plant`。种植由 `level.gd` 完成：点击网格 → 实例化卡片关联的植物场景 → 写入 `character.row/column` → 挂到 `Globalmanager.plants`。

## 成员

| 资料 | 场景 | 定位 |
|---|---|---|
| 向日葵 `sun_flower` | `scenes/plants/front_yard/sun_flower/sun_flower.tscn` | 阳光生产 |
| 豌豆射手 `pean_shooter` | `scenes/plants/front_yard/pean_shooter/pean_shooter.tscn` | 直线单发 |
| 双重射手 `pea_repeater` | `scenes/plants/front_yard/pea_repeater/pea_repeater.tscn` | 直线连发 |
| 寒冰射手 `ice_shooter` | `scenes/plants/front_yard/ice_shooter/ice_shooter.tscn` | 减速弹 |
| 激光豆 `laser_bean` | `scenes/plants/front_yard/laser_bean/laser_bean.tscn` | 激光 |
| 魔炮 `magic_pea` | `scenes/plants/front_yard/magic_pea/magic_pea.tscn` | 慢速高伤 |
| 樱桃炸弹 `cherry_bomb` | `scenes/plants/front_yard/cherry_bomb/cherry_bomb.tscn` | 范围爆炸 |
| 土豆地雷 `potato_mine` | `scenes/plants/front_yard/potato_mine/potato_mine.tscn` | 延迟陷阱 |
| 窝瓜 `squash` | `scenes/plants/front_yard/squash/squash.tscn` | 单格跳砸 |
| 坚果 `nut` | `scenes/plants/front_yard/nut/nut.tscn` | 纯肉盾 |
| 地刺 `spikeweed` | `scenes/plants/front_yard/spikeweed/spikeweed.tscn` | 地面持续伤害 |
| 菜问 `caiwen` | `scenes/plants/front_yard/caiwen/caiwen.tscn` | 近战拳击 |
| 悟空 `wukong` | `scenes/plants/front_yard/wukong/wukong.tscn` | 棍棒近战（直接实例化模板场景） |

## 场景分组

- `plant`：所有植物。
- `melee_type_plant`、`defence_plant`、`trap`：由 `project.godot` 的 `[global_group]` 声明，供射线与碰撞按类别筛选，具体挂载见各植物资料。
