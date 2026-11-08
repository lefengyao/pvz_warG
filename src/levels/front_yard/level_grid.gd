class_name LevelGrid
extends GridContainer

## 草坪网格：挂在这个 GridContainer 上，负责生成所有拼图格子，
## 并按关卡数据和通关进度推导每一格的状态。
##
## 主脚本只需要调用 build() 传入数据，然后监听 level_selected。

signal level_selected(index: int)

const ATLAS_IMAGE := "res://assets/textures/lawn/lawn_atlas.png"
const ATLAS_DATA := "res://resources/lawn/atlas.json"

## 拼图底图尺寸，用来换算单格大小。
const BASE_SIZE := Vector2(578, 360)

const CELL_SCENE := preload("res://scenes/levels/front_yard/level_cell.tscn")

## 网格尺寸，必须与拼图切分一致：默认 9 列 × 5 行 = 45 块。
@export var grid_columns: int = 9
@export var grid_rows: int = 5

var _levels: Array[LevelResource] = []
var _cleared: int = 0
var _cells: Array[LevelCell] = []

## 当前选中的关卡下标，-1 表示没有选中。
var selected_index: int = -1

func _ready() -> void :
	columns = grid_columns

## 重建整张网格。
##   levels  关卡数据，下标即格子顺序
##   cleared 已通关的关卡数，用来推导每格状态
func build(levels: Array[LevelResource], cleared: int) -> void :
	_levels = levels
	_cleared = cleared
	columns = grid_columns
	_rebuild()

func _rebuild() -> void :
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_cells.clear()
	selected_index = -1

	var atlas_tex: Texture2D = load(ATLAS_IMAGE)
	if atlas_tex == null:
		push_warning("找不到拼图图集: " + ATLAS_IMAGE)

	var entries: Dictionary = _load_piece_entries()
	var cell_size := Vector2(BASE_SIZE.x / float(grid_columns), BASE_SIZE.y / float(grid_rows))

	var total_cells: int = grid_columns * grid_rows
	for i in total_cells:
		var cell: LevelCell = CELL_SCENE.instantiate()
		add_child(cell)
		_cells.append(cell)

		# 行优先：i → (row, col)，拼图坐标表用的是 1 起始
		var row: int = i / grid_columns + 1
		var col: int = i % grid_columns + 1
		var entry: Dictionary = entries.get("r%dc%d" % [row, col], {})

		var piece_tex: Texture2D = null
		var piece_size := cell_size
		var piece_offset := Vector2.ZERO
		if not entry.is_empty() and atlas_tex != null:
			var r: Array = entry["region"]
			var o: Array = entry["source_offset"]
			var at := AtlasTexture.new()
			at.atlas = atlas_tex
			at.region = Rect2(r[0], r[1], r[2], r[3])
			piece_tex = at
			piece_size = Vector2(r[2], r[3])
			# 拼块左上角在图集坐标里是相对整张草坪的，这里减去格子左上角
			piece_offset = Vector2(o[0], o[1]) - Vector2((col - 1) * cell_size.x, (row - 1) * cell_size.y)

		var has_level: bool = i < _levels.size()
		var level_name: String = ""
		var state: int = LevelCell.State.NONE
		if has_level and _levels[i] != null:
			level_name = _levels[i].level_name
			if i < _cleared:
				state = LevelCell.State.CLEARED
			elif i == _cleared:
				state = LevelCell.State.UNLOCKED
			else:
				state = LevelCell.State.LOCKED

		cell.setup(i, level_name, state, piece_tex, piece_size, piece_offset)
		cell.cell_pressed.connect(_on_cell_pressed)

## 读 atlas.json，按 "r{row}c{col}" 建索引，方便按格子下标取。
func _load_piece_entries() -> Dictionary:
	var out: Dictionary = {}
	if not FileAccess.file_exists(ATLAS_DATA):
		push_warning("找不到拼图坐标表: " + ATLAS_DATA)
		return out

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ATLAS_DATA))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("atlas.json 解析失败")
		return out

	for e: Dictionary in parsed.get("entries", []):
		out["r%dc%d" % [int(e["row"]), int(e["col"])]] = e
	return out

## 格子被点击：先更新选中态，再把下标交给上层（上层用它更新标题，不直接进关）。
func _on_cell_pressed(index: int) -> void :
	select(index)
	level_selected.emit(index)

## 选中某一格：标记 selected_index，并刷新所有格子的高亮。
func select(index: int) -> void :
	selected_index = index
	for cell in _cells:
		cell.set_selected(cell.index == index)
