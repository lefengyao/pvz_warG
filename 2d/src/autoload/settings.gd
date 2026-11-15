extends CanvasLayer

## 全局「设置」节点（autoload 名：Settings）。
##
## 注意：project.godot 里 Settings 指向的是 **场景** res://2d/scenes/ui/settings.tscn，
## 不是这个脚本文件。本脚本是那个场景根节点的脚本，场景结构是：
##   /root/Settings          ← CanvasLayer（本脚本，layer = 10）
##   └── InGameSetting       ← in_game_setting.tscn 的实例（暂停 / 设置面板）
##
## 它对外只提供一个入口：Settings.ingameset，
## 关卡里用 Settings.ingameset.pause_game() 之类的方式调用面板方法。
##
## 另外还负责一段历史存档兼容（见 _migrate_audio_settings）。

## 面板实例。启动时隐藏，等关卡里按下暂停按钮才显示。
@onready var ingameset: Control = $InGameSetting

func _enter_tree() -> void:
	# 必须在任何地方读写音量存档之前执行：
	# 旧存档记录的是搬家前的脚本路径，不先改写的话加载会失败，
	# 玩家的音量设置会静默回到默认值（不报错，很难查）。
	# 父节点先进入场景树，保证子滑块在 _ready() 读取前完成迁移。
	_migrate_audio_settings()


func _ready() -> void :
	ingameset.visible = false


## 迁移 user://audio_settings.tres 里记录的旧脚本路径。
##
## 兼容 UI/UI/music/ 和 src/ui/music/ 两代不含 UID 的脚本路径，
## 统一迁移到 shared/src/audio/music_setting.gd，保留原有音量值。
##
## 处理流程：
##   1. 文件不存在 / 已经是新路径 → 直接返回，什么都不做；
##   2. 备份一份 .before_layout_migration.bak（已存在就不覆盖）；
##   3. 把旧路径字符串替换成新路径，写到临时文件；
##   4. 用改名的方式原子替换原文件，避免写一半损坏存档。
func _migrate_audio_settings(save_path: String = "user://audio_settings.tres") -> void:
	# Older saves serialize the script path without a UID. Preserve their values
	# and a backup before ResourceLoader sees the moved resource.
	const CURRENT_SCRIPT := "res://shared/src/audio/music_setting.gd"
	if not FileAccess.file_exists(save_path):
		return
	var contents := FileAccess.get_file_as_string(save_path)
	var migrated_contents := contents
	for legacy_script in [
		"res://" + "UI/UI/music/music_setting.gd",
		"res://" + "src/ui/music/music_setting.gd",
	]:
		migrated_contents = migrated_contents.replace(legacy_script, CURRENT_SCRIPT)
	if migrated_contents == contents:
		return
	var backup_path := save_path + ".before_layout_migration.bak"
	if not FileAccess.file_exists(backup_path):
		var copy_error := DirAccess.copy_absolute(
			ProjectSettings.globalize_path(save_path),
			ProjectSettings.globalize_path(backup_path)
		)
		if copy_error != OK:
			push_error("Cannot back up legacy audio settings: ", copy_error)
			return
	var migrated_path := save_path + ".migration_tmp"
	var migrated_file := FileAccess.open(migrated_path, FileAccess.WRITE)
	if migrated_file == null:
		push_error("Cannot write migrated audio settings: ", FileAccess.get_open_error())
		return
	migrated_file.store_string(migrated_contents)
	migrated_file.close()
	var rename_error := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(migrated_path),
		ProjectSettings.globalize_path(save_path)
	)
	if rename_error != OK:
		push_error("Cannot replace migrated audio settings: ", rename_error)
