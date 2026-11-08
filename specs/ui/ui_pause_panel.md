---
schemaVersion: 1
id: ui_pause_panel
title: 暂停 / 设置面板
type: ui
description: 全局暂停/设置面板：场景 autoload 结构、关卡冻结方式与音量存档迁移。
---
# 暂停 / 设置面板

## 文件
- 全局入口场景：`res://scenes/ui/settings.tscn`（autoload 名 `Settings`）
- 入口脚本：`res://src/autoload/settings.gd`
- 面板场景：`res://scenes/ui/in_game_setting.tscn`
- 面板脚本：`res://src/ui/in_game_setting.gd`

## 结构

```
/root/Settings (CanvasLayer, layer = 10, 脚本 settings.gd)
└── InGameSetting (Control, 默认隐藏, 脚本 in_game_setting.gd)
    ├── TextureRect            面板背景（plant_slot.png 裁剪块）
    ├── DraggableProgressBar   音量滑条（master）
    ├── DraggableProgressBar2  音量滑条（sfx）
    ├── Button                 「返回主菜单」
    └── Button2                「返回游戏」
```

## 为什么是「场景 autoload」

`project.godot` 里 `Settings` 指向的是 **`.tscn` 场景**，不是脚本文件。
脚本只是那个场景根节点的挂载脚本，面板作为子节点随场景一起加载，因此不需要在代码里手写 `load` + `instantiate`。

## 对外接口

| 成员 | 说明 |
|---|---|
| `Settings.ingameset` | 面板实例，关卡通过它调用下列方法 |
| `pause_game()` | 把注入的 `game_control.process_mode` 设为 `DISABLED`，冻结整棵关卡子树，并显示面板 |
| `resume_game()` | 恢复 `process_mode` 为 `INHERIT`，隐藏面板 |
| `go_to_main_menu()` | 先恢复 `process_mode` 再切换回选关界面，最后隐藏面板 |

暂停不是「挡住输入」，而是停掉关卡的整个处理流程（物理、动画、计时器全部冻结）。

## `game_control` 的注入

关卡在 `_ready` 阶段把自己（关卡根节点）赋给 `Settings.ingameset.game_control`，
面板才有对象可以冻结。未注入时面板方法会判空跳过，不会报错。

## 音量存档与迁移

- 音量设置持久化在 `user://audio_settings.tres`
- 由 `src/ui/draggable_button.gd` 读写
- 旧版本存档里记录的脚本路径是搬家前的 `res://UI/UI/music/music_setting.gd`
- `settings.gd` 的 `_migrate_audio_settings()` 在启动时把它改写成新路径 `res://src/ui/music/music_setting.gd`，流程是：检查 → 备份 `.before_layout_migration.bak` → 写临时文件 → 改名原子替换
- **必须在任何音量读写之前执行**，否则旧存档加载失败、音量静默回默认值且不报错

## 已知注意

1. 面板挂在 `layer = 10` 的 CanvasLayer 上，保证盖住关卡 UI。
2. `in_game_setting.gd` 里已移除未使用的 `resume_control` 导出字段。
3. 面板的按钮是 `flat` 纯文字，底图由 TextureRect 提供，不使用主题样式。