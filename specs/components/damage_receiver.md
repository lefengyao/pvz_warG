---
schemaVersion: 1
id: damage_receiver
title: 受击结算
type: component
description: ""
fields:
  - key: damage_route
    label: 伤害去向
    type: string
    default: health
  - key: scale_field
    label: 伤害缩放字段
    type: string
    default: damage_ratio
  - key: hit_signal
    label: 受击信号
    type: string
    default: ""
  - key: flash_on_hit
    label: 受击闪白
    type: boolean
    default: false
  - key: penetrating_ammo_type
    label: 穿透弹药类型
    type: number
    default: 2
scope: system
appearance:
  icon: health
  color: red
groupId: group_basic_components
---
# 受击结算

角色如何接收伤害。植物与僵尸的入口签名一致，分流规则不同。

## 字段

| 字段 | 说明 | 植物取值 | 僵尸取值 |
|---|---|---|---|
| `damage_route` | 伤害去向 | `health` | `armor_then_health` |
| `scale_field` | 伤害缩放字段 | `damage_ratio` | `damage_ratio` |
| `hit_signal` | 受击信号 | 空 | `be_attack` |
| `flash_on_hit` | 受击闪白 | 假 | 真 |
| `penetrating_ammo_type` | 完全穿透的弹药类型 | — | 2 |

## 统一切口

两个模板都实现同名方法：

```gdscript
func take_damage(attack, ammo_type) -> void
```

调用方是子弹与近战判定的命中回调，`ammo_type` 由弹药自身携带：

| `ammo_type` | 含义 |
|---|---|
| 1 | 普通弹药，打防具也打本体 |
| 2 | 穿透弹药，绕过防具直击本体 |
| 3 | 另一类普通弹药，与 1 同规则 |

## 植物的分流

`plant_template.take_damage` 直接扣本体：

```gdscript
character.current_health -= attack
```

唯一例外：`ammo_type == 2` 且这一击会致死时，先播 `ate_sfx` 再扣血。

## 僵尸的分流

`zombie_template.take_damage` 走三段：

1. 有 `a1`（armor1 实例）时把伤害交给防具，防具返回溢出值；
2. 否则有 `a2`（armor2）时交给第二件防具；
3. 剩余伤害乘 `damage_ratio` 扣本体，随后发 `be_attack`。

防具对 `ammo_type == 2` 直接返回全额伤害，自身不掉血 —— 这就是穿透弹药的实现方式。

## 受击反馈

- 僵尸：`be_attack` 在 `_ready` 里连到自身 `be_attack_effect`，用 0.01 秒 Tween 把 `Skeleton2D.modulate` 刷到 `Color(255, 255, 255, 0.3)` 再还原。
- 植物：没有受击反馈，只有致死时的音效。

## 约束

- `scale_field` 目前均指向 `character_stats.damage_ratio`，改字段名要同时改模板。
- 减伤/护盾类效果若将来加入，应扩展本组件而不是散落到各角色脚本。
