---
schemaVersion: 1
id: death_behavior
title: 死亡处理
type: component
description: ""
fields:
  - key: check_phase
    label: 判死所在帧回调
    type: string
    default: process
  - key: sfx
    label: 死亡音效
    type: string
    default: ""
  - key: release
    label: 释放方式
    type: string
    default: immediate
  - key: broadcast_signal
    label: 死亡信号
    type: string
    default: ""
  - key: drops_loot
    label: 是否产出掉落
    type: boolean
    default: false
scope: system
appearance:
  icon: health
  color: gray
groupId: group_basic_components
---
# 死亡处理

角色生命归零后的判定时机、表现与释放方式。

## 字段

| 字段 | 说明 | 植物取值 | 僵尸取值 |
|---|---|---|---|
| `check_phase` | 判死所在帧回调 | `process` | `physics_process` |
| `sfx` | 死亡音效 | `ate_sfx` | `fall_sfx` |
| `release` | 释放方式 | `immediate` | `after_animation` |
| `broadcast_signal` | 死亡信号 | `dead` | 空 |
| `drops_loot` | 是否产出掉落 | 假 | 真 |

## 植物的流程

`plant_template` 在 `_process` 里每帧检查：

```
current_health <= 0
└── dead_()
    ├── emit_dead()  → dead 信号（携带 row、column）
    ├── Audiomanager.play_sfx(ate_sfx)
    └── queue_free()
```

没有动画等待，也没有掉落。`level.gd` 用 `dead` 信号清空网格占用。

## 僵尸的流程

`zombie_template` 在 `_physics_process` 里检查，命中后先切 `DEAD` 状态，再调 `dead()`：

```
current_health <= 0 且 not is_loot
└── state_machine.change_state("DEAD")
    └── dead()
        ├── is_loot = true
        ├── CollisionShape2D.disabled = true
        ├── AnimationPlayer.play("dead")
        ├── Audiomanager.play_sfx(fall_sfx)
        ├── set_loot()
        ├── await animation_finished
        ├── dead_effect()      ← 子类钩子
        └── queue_free()
```

有动画等待、有掉落、有子类钩子。`is_loot` 是防重入标志，避免死亡流程被重复触发。

## 子类覆写

| 角色 | 覆写内容 |
|---|---|
| 刺客僵尸 | 完全重写 `dead()`：播 `AnimationPlayer2` 的 `dead`、右移 150 滑步、**不生成掉落**、直接释放 |
| 撑杆僵尸 | 覆写 `dead_effect()` 发 `die` 信号，让撑杆一起消失 |
| 手枪僵尸 / 威龙 / 其余 | 沿用模板，仅改 `dead_effect()` 或音效 |

## 约束

- 调整 `check_phase` 会影响判死延迟：物理帧（默认 60 Hz）与渲染帧不同步，僵尸死亡比植物晚一帧生效。
- 新增会覆写 `dead()` 的僵尸时，必须自行处理 `is_loot` 与碰撞禁用，否则会出现重复死亡或残留碰撞。
