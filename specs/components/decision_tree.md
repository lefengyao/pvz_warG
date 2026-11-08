---
schemaVersion: 1
id: decision_tree
title: 决策树
type: component
scope: system
groupId: group_basic_components
description: 引用一棵决策树规范，用行为决策驱动实体或系统；同一所有者可挂多棵，用 key 区分。
fields:
  - key: enabled
    label: 启用
    type: boolean
    default: true
  - key: tree
    label: 决策树
    type: string
    default: ""
---

# 决策树

## 行为契约

- `values.tree` 填写决策树 ID，例如 `values: { tree: guard_patrol }`；不要填写文件路径。对应资料保存在 `specs/decision_trees/<id>.md`，由实现按树结构执行。
- 同一实体或系统可挂多个决策树实例，用 `key` 区分。
- 决策树只描述选择逻辑，具体条件与动作由实现解释。
