---
schemaVersion: 1
id: audio_source
title: 音频源
type: component
scope: system
groupId: group_audio_components
description: 播放一个音频事件：引用总线，并描述音量、音高、并发、冷却、循环与定位。
fields:
  - key: enabled
    label: 启用
    type: boolean
    default: true
  - key: bus
    label: 总线
    type: string
    default: sfx
  - key: volume_db
    label: 音量（分贝）
    type: number
    default: 0
  - key: pitch
    label: 音高浮动
    type: number
    default: 0
  - key: max_concurrent
    label: 并发上限
    type: number
    default: 3
  - key: cooldown
    label: 冷却（秒）
    type: number
    default: 0
  - key: priority
    label: 优先级
    type: number
    default: 0
  - key: loop
    label: 循环
    type: boolean
    default: false
  - key: positional
    label: 定位音效
    type: boolean
    default: false
---

# 音频源

## 行为契约

- `bus` 指向音频系统里已存在的总线；引用不存在的总线时保存失败。
- 同一实体或系统可挂多个音频源实例，用 `key` 区分。
- `volume_db`、`pitch`、`max_concurrent`、`cooldown`、`priority` 与音频事件字段同名同义。
- `positional` 为真时，播放位置取挂载者的位置，输出以音频监听器为基准。
