---
schemaVersion: 1
id: category_zombies
title: 僵尸
type: entity
description: 分类节点：僵尸侧资料目录，成员全部继承僵尸模板 zombie_base。
status: draft
version: 1
relations: []
source: agent
components: []
appearance:
  icon: entity
  color: purple
parent: category_characters
---
# 僵尸（分类）

资料目录节点，对应代码中的僵尸侧：`scenes/zombies/`、`src/zombies/`。

## 共同点

本分类下所有角色都继承僵尸模板 `zombie_base`，运行在 `Area2D` 上、加入场景分组 `zombie`。生成由 `zombie_spawner` 的波次数据驱动，生成后挂到 `Globalmanager.zombies`。

## 成员

| 资料 | 场景 | 生命 | 速度 | 特点 |
|---|---|---|---|---|
| 普通僵尸 `ordinary_zombie` | `scenes/zombies/front_yard/ordinary_zombie/ordinary_zombie.tscn` | 100（默认） | -28 | 模板本体、无防具 |
| 路障僵尸 `conehead_zombie` | `scenes/zombies/front_yard/conehead_buckthead_zombie/conehead_zombie.tscn` | 100（默认） | -28 | 路障防具 |
| 铁桶僵尸 `buckthead_zombie` | `scenes/zombies/front_yard/conehead_buckthead_zombie/buckthead_zombie.tscn` | 100（默认） | -28 | 铁桶防具 |
| 手枪僵尸 `pistol_zombie` | `scenes/zombies/front_yard/pistol_zombie/pistol_zombie.tscn` | 200 | -20 | 远距离射击 |
| 撑杆僵尸 `pole_vaulting_zombie` | `scenes/zombies/front_yard/pole_vaulting_zombie/pole_vaulting_zombie.tscn` | 120 | -48 | 撑杆跳过植物 |
| 刺客僵尸 `assassin_zombie` | `scenes/zombies/front_yard/assassin_zombie/assassin_zombie.tscn` | 400 | -48 | 突进与格挡 |
| 威龙 `weilong` | `scenes/zombies/front_yard/weilong/weilong.tscn` | 250 | -50 | 喷气与 C4 |

## 命名注意

`buckthead_zombie.tscn` 内的 `character_name` 当前写作「铁通僵尸」，与目录名 `buckthead`（bucketahead）和目标中文名「铁桶僵尸」不一致，属于已有数据，未在本轮改动。
