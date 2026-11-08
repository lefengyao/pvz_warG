---
schemaVersion: 1
id: audio_listener
title: 音频监听器
type: component
scope: system
groupId: group_audio_components
description: 音频的接收端；定位音效以监听器位置为基准，音量是最终输出的线性缩放。
fields:
  - key: enabled
    label: 启用
    type: boolean
    default: true
  - key: volume
    label: 监听音量
    type: number
    default: 1
---

# 音频监听器

## 行为契约

- 同一时刻只有挂载了音频监听器的所有者参与定位计算。
- `volume` 是 0~1 的线性缩放，叠加在总线音量之上。
- 未挂载监听器时，项目按非定位音效处理，不报错。
