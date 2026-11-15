class_name LevelCell
extends Control

## 草坪上的一格。四种呈现：
##
##   NONE      没有关卡 —— 显示泥土地块，不显示编号，不可点
##   LOCKED    有关卡但未解锁 —— 拼块压暗 + 「锁」字，不可点
##   UNLOCKED  已解锁未通关 —— 拼块提亮，可点
##   CLEARED   已通关 —— 拼块原色（普通草皮），可重玩
##
## 有编号的格子左上角显示关卡序号；拼块贴图和偏移由 yard_level_select.gd
## 从 atlas.json 读出来后注入（每块的包围盒和相对格子偏移都不一样）。

signal cell_pressed(index: int)

enum State { NONE, LOCKED, UNLOCKED, CLEARED }

@onready var piece: TextureRect = $Piece
@onready var button: Button = $Button
@onready var index_label: Label = $IndexLabel
@onready var lock_label: Label = $LockLabel

## 这一格对应的关卡下标（从 0 开始，行优先）。
var index: int = 0

## 当前状态。用 int 存枚举值，避免 GDScript 把内部 State 与 LevelCell.State 当成两个类型。
var state: int = State.NONE

## 关卡名，作为鼠标悬停提示。
var level_name: String = ""

## 是否被选中（选关模式下点一下只是选中，不直接进关）。
var selected: bool = false

func _ready() -> void :
	button.pressed.connect(_on_button_pressed)
	_refresh()

## 设置选中态：选中的格子提亮并压在其他格子之上。
func set_selected(p_selected: bool) -> void :
	if selected == p_selected:
		return
	selected = p_selected
	_refresh()

## 由外部初始化。
##   p_texture 从图集裁出的一块（AtlasTexture），NONE 状态可以为 null
##   p_size    这一块的原始像素尺寸
##   p_offset  这一块左上角相对格子左上角的偏移（卡扣凸出时为负）
func setup(p_index: int, p_level_name: String, p_state: int,
		p_texture: Texture2D, p_size: Vector2, p_offset: Vector2) -> void :
	index = p_index
	level_name = p_level_name
	state = p_state

	if p_texture != null:
		piece.texture = p_texture
		piece.size = p_size
		piece.position = p_offset

	tooltip_text = p_level_name
	_refresh()

func _refresh() -> void :
	if not is_node_ready():
		return

	var has_level := state != State.NONE

	# 编号：有关卡的格子显示「下标 + 1」；泥土地块不显示
	index_label.text = str(index + 1)
	index_label.visible = has_level

	# 没有关卡的格子整格透明，露出外面那层统一的泥土地
	piece.visible = has_level

	# 锁只在「有关卡但未解锁」时出现
	lock_label.visible = state == State.LOCKED

	# 没有关卡、或关卡未解锁，都不能点
	button.disabled = state == State.NONE or state == State.LOCKED

	match state:
		State.NONE:
			piece.modulate = Color(1, 1, 1, 1)
		State.LOCKED:
			# 压暗但保留可辨识度
			piece.modulate = Color(0.45, 0.45, 0.45, 1)
		State.UNLOCKED:
			# 略微提亮，和已通关的普通草皮区分开
			piece.modulate = Color(1.2, 1.2, 0.85, 1)
		State.CLEARED:
			# 普通草皮（原色）
			piece.modulate = Color(1, 1, 1, 1)

	# 选中态覆盖在上面：更亮，并压到邻格之上（拼块有凸出的卡扣）
	if selected:
		piece.modulate = Color(1.45, 1.45, 1.45, 1)
		z_index = 2
	else:
		z_index = 0

func _on_button_pressed() -> void :
	cell_pressed.emit(index)
