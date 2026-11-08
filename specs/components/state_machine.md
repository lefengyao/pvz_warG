---
schemaVersion: 1
id: state_machine
title: 状态机基类
type: component
scope: system
groupId: group_basic_components
group: 基础组件
description: Reusable state-machine lifecycle data and behavior contract.
fields:
  - key: enabled
    label: 启用
    type: boolean
    default: true
  - key: current_state
    label: 当前状态
    type: string
    default: idle
---

# 状态机基类

## 行为契约

- `on_enter(state)`：进入状态时调用。
- `on_update(state, delta)`：状态持续期间每帧更新。
- `on_exit(state)`：离开状态时调用。
