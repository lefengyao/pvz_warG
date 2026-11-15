@tool
class_name ZombieSpawner
extends VBoxContainer



@export var zombie_entries: Array[ZombieSpawnEntry] = []:
	set(value):
		zombie_entries = value
		_request_rebuild()


@export var total_zombies: int = 10:
	set(value):
		total_zombies = value
		_request_rebuild()


@export var row_weights: Array[float] = []:
	set(value):
		row_weights = value
		_request_rebuild()


@export var is_big_wave: bool = false:
	set(value):
		is_big_wave = value
		_request_rebuild()


var cool_time: float = randf_range(25.0, 31.0)



var zombies: Array = []


func _ready() -> void :

	if not Engine.is_editor_hint():
		_generate_zombie_list()

	_update_ui()



func _request_rebuild() -> void :

	if Engine.is_editor_hint():
		_update_ui()



func _update_ui() -> void :

	for child in get_children():
		child.queue_free()


	var panel: = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL


	var style_box: = StyleBoxFlat.new()
	style_box.bg_color = Color(0.08, 0.08, 0.12, 0.92)
	style_box.border_color = Color(0.4, 0.4, 0.8, 1.0)
	style_box.set_border_width_all(2)
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_top_right = 8
	style_box.corner_radius_bottom_left = 8
	style_box.corner_radius_bottom_right = 8
	style_box.content_margin_left = 12
	style_box.content_margin_right = 12
	style_box.content_margin_top = 10
	style_box.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style_box)


	var inner_vbox: = VBoxContainer.new()
	inner_vbox.add_theme_constant_override("separation", 6)
	panel.add_child(inner_vbox)


	var title_label: = Label.new()
	title_label.text = "🌊 僵尸波次配置"
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	inner_vbox.add_child(title_label)


	var big_wave_label: = Label.new()
	big_wave_label.text = "大型波次: " + ("是" if is_big_wave else "否")
	if is_big_wave:
		big_wave_label.add_theme_color_override("font_color", Color.RED)
	else:
		big_wave_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	inner_vbox.add_child(big_wave_label)


	var sep1: = HSeparator.new()
	inner_vbox.add_child(sep1)


	var species_title: = Label.new()
	species_title.text = "🧟 僵尸种类 (权重浮动):"
	species_title.add_theme_font_size_override("font_size", 15)
	species_title.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	inner_vbox.add_child(species_title)

	if zombie_entries.is_empty():
		var hint: = Label.new()
		hint.text = "（尚未配置僵尸条目）"
		hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		inner_vbox.add_child(hint)
	else:
		for entry in zombie_entries:
			var hbox: = HBoxContainer.new()
			hbox.add_theme_constant_override("separation", 6)

			var tex_rect: = TextureRect.new()
			tex_rect.custom_minimum_size = Vector2(32, 32)
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			if entry.icon:
				tex_rect.texture = entry.icon
			else:
				var placeholder: = PlaceholderTexture2D.new()
				placeholder.size = Vector2(32, 32)
				tex_rect.texture = placeholder
			hbox.add_child(tex_rect)


			var scene_name: = "空场景"
			if entry.zombie_scene:
				scene_name = entry.zombie_scene.resource_path.get_file().get_basename()
			var info_label: = Label.new()
			info_label.text = "%s  权重: %.1f ~ %.1f" % [scene_name, entry.weight_min, entry.weight_max]
			info_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
			hbox.add_child(info_label)

			inner_vbox.add_child(hbox)


	var sep2: = HSeparator.new()
	inner_vbox.add_child(sep2)
	var row_title: = Label.new()
	row_title.text = "📍 行权重:"
	row_title.add_theme_font_size_override("font_size", 15)
	row_title.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	inner_vbox.add_child(row_title)

	if row_weights.is_empty():
		var hint: = Label.new()
		hint.text = "（未配置行权重）"
		hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		inner_vbox.add_child(hint)
	else:
		for i in row_weights.size():
			var row_label: = Label.new()
			row_label.text = "行 %d: 权重 %.2f" % [i, row_weights[i]]
			row_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
			inner_vbox.add_child(row_label)


	var sep3: = HSeparator.new()
	inner_vbox.add_child(sep3)
	var total_label: = Label.new()
	total_label.text = "总僵尸数: %d" % total_zombies
	total_label.add_theme_font_size_override("font_size", 16)
	total_label.add_theme_color_override("font_color", Color(0.9, 1.0, 0.7))
	inner_vbox.add_child(total_label)


	var cool_label: = Label.new()
	if Engine.is_editor_hint():
		cool_label.text = "冷却时间: (运行时随机 25~31 秒)"
	else:
		cool_label.text = "冷却时间: %.1f 秒" % cool_time
	cool_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	inner_vbox.add_child(cool_label)

	add_child(panel)



func _generate_zombie_list() -> void :
	zombies.clear()

	if zombie_entries.is_empty():
		push_warning("ZombieSpawner: zombie_entries 为空，无法生成僵尸。")
		return
	if row_weights.is_empty():
		push_warning("ZombieSpawner: row_weights 为空，无法分配行。")
		return
	if total_zombies <= 0:
		push_warning("ZombieSpawner: total_zombies 为 0，不会生成任何僵尸。")
		return


	var weighted_pool: = []
	for entry in zombie_entries:
		if entry.zombie_scene == null:
			continue
		var weight: = randf_range(entry.weight_min, entry.weight_max)
		weighted_pool.append({"scene": entry.zombie_scene, "weight": weight})

	if weighted_pool.is_empty():
		push_warning("ZombieSpawner: 所有条目的 zombie_scene 都为空。")
		return


	var total_weight_sum: = 0.0
	for item in weighted_pool:
		total_weight_sum += item.weight

	if total_weight_sum > 0:
		for item in weighted_pool:
			item.weight /= total_weight_sum
	else:
		var count: = weighted_pool.size()
		for item in weighted_pool:
			item.weight = 1.0 / count


	var selected_scenes: Array[PackedScene] = []
	for _i in range(total_zombies):
		var roll: = randf()
		var cumulative: = 0.0
		var chosen: PackedScene = weighted_pool[-1].scene
		for item in weighted_pool:
			cumulative += item.weight
			if roll < cumulative:
				chosen = item.scene
				break
		selected_scenes.append(chosen)


	var row_total_weight: = 0.0
	for w in row_weights:
		row_total_weight += w
	if row_total_weight <= 0:
		push_warning("ZombieSpawner: row_weights 总和为 0，将均匀随机选择行。")


	for scene in selected_scenes:
		var row: = _pick_weighted_row(row_total_weight)
		zombies.append([scene, row])


func _pick_weighted_row(total_weight: float) -> int:
	if total_weight <= 0 or row_weights.is_empty():
		if row_weights.is_empty():
			return 0
		return randi() % row_weights.size()

	var roll: = randf() * total_weight
	var cumulative: = 0.0
	for i in row_weights.size():
		cumulative += row_weights[i]
		if roll < cumulative:
			return i
	return row_weights.size() - 1
