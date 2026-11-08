---
schemaVersion: 1
id: audio
title: 音频
type: system
scope: system
groupId: group_audio
description: 音频总线、音乐交叉淡化、音效池与音量存档的现状说明，含已知问题。
buses:
  - name: master
    volume: 1
    muted: false
    description: All audio routes through here.
  - name: music
    parent: master
    volume: 1
    muted: false
  - name: sfx
    parent: master
    volume: 1
    muted: false
events: []
components:
  - audio_source
  - audio_listener
mounts:
  - id: audio_listener
    key: listener
    values:
      enabled: true
      volume: 1
  - id: audio_source
    key: music
    values:
      bus: music
      loop: true
  - id: audio_source
    key: sfx
    values:
      bus: sfx
---

# 音频

## 实现入口

| 文件 | 作用 |
|---|---|
| `res://src/autoload/audiomanager.gd` | 全局 autoload `Audiomanager`，音乐与音效播放 |
| `res://resources/audio/default_bus_layout.tres` | 总线布局（项目设置里已挂到 `audio/buses/default_bus_layout`） |
| `res://src/ui/draggable_button.gd` | 音量滑条，按 `bus_name` 绑定总线并持久化 |
| `user://audio_settings.tres` | 音量存档（资源类 `musicset`，见 `src/ui/music/music_setting.gd`） |

## 总线

| 索引 | 名称 | 父总线 | 默认 |
|---|---|---|---|
| 0 | Master | — | 内置，不可删除 |
| 1 | music | Master | 0 dB，不静音 |
| 2 | sfx | Master | 0 dB，不静音 |

自定义总线写进 `buses`；事件用 `bus` 字段引用总线，名称在项目内唯一。

## 音乐播放

- 固定 **2 个** `AudioStreamPlayer` 轮换（`music_audio_player_count = 2`），用于交叉淡化
- `play_music(stream)`：如果当前正在放的就是这首，直接返回；否则把新曲放进另一路、淡入，同时把原路淡出并停止，最后切换 `current_music_player_index`
- 淡入淡出时长 `music_fade_duration = 1.0` 秒，用 `Tween` 把 `volume_db` 从 -40 拉到 0，或从当前拉到 -40 后 `stop()`
- 循环方式：监听 `finished` 信号 → `play_same_music()` 重新播放，**不是**设置 `stream.loop`
- 音乐播放器设 `process_mode = ALWAYS`，所以游戏暂停时音乐不会被冻结
- `fade_out_and_stop_current()` 供场景切换时调用（主菜单 `_ready`、选关界面进入时都会调）

## 音效播放

- **12 个** `AudioStreamPlayer` 组成的池（`sfx_audio_player_count = 12`）
- `play_sfx(stream)`：找空闲播放器播放；池满时临时 `new` 一个，播完 `queue_free`
- 防叠音：同一条音效同时播放超过 **3 个**时丢弃新的请求
- 音效播放器不设 `process_mode`，跟随全局暂停

## 音量与持久化

- `draggable_button.gd` 是 `TextureProgressBar`，`bus_name` 取 `music` 或 `sfx`，在 `_ready` 里用 `AudioServer.get_bus_index(bus_name)` 解析
- 值换算：`value_ratio = value / max_value`；`0` 时 `set_bus_mute(true)`，否则 `set_bus_volume_db(linear_to_db(ratio))`
- 松手时 `save_settings()` 写入 `user://audio_settings.tres`；启动时 `load_settings()` 读回
- 存档只有一个资源文件，两个滑条共用：音乐滑条只改 `music_volume`，音效滑条只改 `sfx_volume`，保存前会先读旧文件再覆盖对应字段
- 旧存档里的脚本路径由 `Settings` autoload 的 `_migrate_audio_settings()` 在启动时迁移（见 UI 资料「暂停 / 设置面板」）

## 已知问题

1. **`set_volume(bus_index: Bus, v)` 用枚举当 AudioServer 索引**：`Bus.MASTER/MUSIC/SFX` 恰好是 0/1/2，与当前总线顺序一致；一旦在中间插入自定义总线，这个调用就会写错总线。项目其他地方用的是总线名常量 `MUSIC_BUS` / `SFX_BUS`，两套写法不统一。
2. **音量 UI 里有大量 `print()`**：加载/保存/换算全程打印，正式发布前应移除或降到 debug 级别。
3. **存档存的是整数百分比**，而总线用 dB；换算是单向的，重新读档时用的是 `int(value)`，存在精度损失但可接受。
4. **`events` 为空**：当前所有播放都直接传 `AudioStream`，没有事件 id、并发上限、冷却、优先级、随机变体这些控制。`audio_source` / `audio_listener` 两个组件目前只是概念绑定，代码里没有对应的运行时实现。

## 与组件模型的关系

系统上挂了 `audio_source` / `audio_listener` 组件用来表达「谁在发声、谁在接收」，但实际实现是**两个全局播放器池**，不按实体定位、不做空间化。若要真正做 3D 定位音效，需要把播放器挂到实体上并改用 `AudioStreamPlayer2D/3D`，届时事件表才需要填。
