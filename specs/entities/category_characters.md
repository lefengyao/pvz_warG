---
schemaVersion: 1
id: category_characters
title: 角色
type: entity
description: 分类节点：全部角色的最上层入口，向下分为植物与僵尸两支。仅用于组织资料层级，不对应任何场景。
status: draft
version: 1
relations: []
source: agent
components: []
appearance:
  icon: entity
  color: gray
---
# 角色（分类）

资料目录节点，不对应 `scenes/` 中的任何文件。

## 结构

```
角色
├── 植物（植物模板 + 13 个植物）
└── 僵尸（僵尸模板 + 7 个僵尸）
```

## 基准与目录的分工

- **分类**用 `parent` 表达，回答「它属于哪一类」。
- **模板继承**用 `extends` 表达，回答「它复用哪套结构与行为」。

因此植物模板既 `parent` 到本目录下的植物分类，又 `extends` 角色基准 `character_base`；两个维度分开记录，不要用父级代替继承。

## 代码中的对应物

| 概念 | 实际脚本/场景 |
|---|---|
| 角色共用数据 | `src/core/general_character.gd` |
| 植物模板 | `src/plants/template/plant_template.gd`、`scenes/plants/template/plant_template.tscn` |
| 僵尸模板 | `src/zombies/front_yard/ordinary_zombie/ordinary_zombie.gd`（`class_name zombie_template`） |
| 状态机 | `src/core/state_machine.gd`、`src/core/state_base.gd` |
