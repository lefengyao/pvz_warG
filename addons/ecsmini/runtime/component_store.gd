class_name EcsComponentStore
extends RefCounted

## Internal sparse-set store for one component type. [EcsWorld] owns these stores;
## application code normally uses the world API instead.[br][br]
## [codeblock]
## var store := EcsComponentStore.new()
## store.add(42, Vector2.ZERO)
## store.set_value(42, Vector2.RIGHT)
## var value: Vector2 = store.get_value(42, Vector2.ZERO)
## [/codeblock]
##
## @tutorial(GDScript documentation comments): https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_documentation_comments.html

## 单一类型组件的存储容器（ECS 架构核心数据结构之一）。
##
## 采用经典的"稀疏集合"（Dense-Sparse Set）模式：
## - 用字典实现 O(1) 的按实体 ID 增 / 删 / 改 / 查
## - 用稠密数组保持组件的连续存储，遍历时代码缓存友好
## - 用反向索引字典记录每个实体在稠密数组中的位置，
##   使删除操作可以通过"交换删除"达到 O(1)
##
## 注意：删除操作会打乱数组顺序（交换删除），本容器不保证遍历顺序稳定。

# ---------------------------------------------------------------------------
# 内部数据结构（三表联动）
# ---------------------------------------------------------------------------

## 稀疏表：entity_id（实体 ID）-> 组件值
## 负责按实体 ID 快速存取组件数据，查询复杂度 O(1)。
var _values: Dictionary = {}

## 稠密数组：按插入顺序存放所有拥有该组件的实体 ID。
## 系统遍历组件时直接迭代此数组，内存连续、缓存命中率高。
var _entities: Array[int] = []

## 反向索引：entity_id -> 该实体在 _entities 数组中的下标。
## 用于删除时 O(1) 定位元素位置，是"交换删除"的关键。
var _indices: Dictionary = {}


# ---------------------------------------------------------------------------
# 增
# ---------------------------------------------------------------------------

## 为指定实体添加一个组件值。
## @param entity_id 目标实体 ID
## @param value     要存储的组件值（任意类型）
## @return bool     成功返回 true；若该实体已拥有此组件则返回 false（不覆盖）
## Example: [code]store.add(entity_id, 100)[/code].
func add(entity_id: int, value: Variant) -> bool:
	# 已存在则拒绝添加，避免破坏索引一致性
	if _values.has(entity_id):
		return false

	# 1. 记录组件值（稀疏表）
	_values[entity_id] = value

	# 2. 记录该实体在稠密数组中将要占据的下标（即当前数组末尾位置）
	_indices[entity_id] = _entities.size()

	# 3. 将实体 ID 追加到稠密数组末尾
	_entities.append(entity_id)
	return true


# ---------------------------------------------------------------------------
# 改
# ---------------------------------------------------------------------------

## 覆盖指定实体的已有组件值（不改变其在数组中的位置和顺序）。
## @param entity_id 目标实体 ID
## @param value     新的组件值
## @return bool     成功返回 true；若实体没有此组件则返回 false（不会自动添加）
## Example: [code]store.set_value(entity_id, 75)[/code].
func set_value(entity_id: int, value: Variant) -> bool:
	# 实体必须已拥有该组件，否则视为失败
	if not _values.has(entity_id):
		return false

	# 仅更新稀疏表中的值，稠密数组和索引不受影响
	_values[entity_id] = value
	return true


# ---------------------------------------------------------------------------
# 删
# ---------------------------------------------------------------------------

## 移除指定实体的组件，使用"交换删除"策略，复杂度 O(1)。
##
## 原理：用数组最后一个元素覆盖被删除位置，再弹出末尾，
## 避免了普通数组删除中间元素时 O(n) 的整体搬移。
## 副作用：会改变剩余元素在数组中的相对顺序。
##
## @param entity_id 目标实体 ID
## @return bool     成功返回 true；若实体没有此组件则返回 false
## Example: [code]store.remove(entity_id)[/code].
func remove(entity_id: int) -> bool:
	# 实体不存在此组件，无需删除
	if not _values.has(entity_id):
		return false

	# 通过反向索引找到待删除元素在稠密数组中的下标
	var removed_index: int = _indices[entity_id]

	# 数组最后一个元素的下标
	var last_index: int = _entities.size() - 1

	# 数组最后一个元素对应的实体 ID
	var last_entity: int = _entities[last_index]

	# 若被删的不是末尾元素，则用末尾元素"顶替"被删位置
	if removed_index != last_index:
		# 末尾实体搬到被删除的位置
		_entities[removed_index] = last_entity
		# 同步更新该实体的反向索引
		_indices[last_entity] = removed_index

	# 弹出数组末尾（此时末尾已是被删元素或已搬空的占位）
	_entities.pop_back()

	# 清理被删实体的索引记录和组件值
	_indices.erase(entity_id)
	_values.erase(entity_id)
	return true


# ---------------------------------------------------------------------------
# 查
# ---------------------------------------------------------------------------

## 判断指定实体是否拥有此组件。
## @param entity_id 目标实体 ID
## @return bool 拥有返回 true
## Example: [code]if store.has(entity_id): pass[/code].
func has(entity_id: int) -> bool:
	return _values.has(entity_id)


## 获取指定实体的组件值。
## @param entity_id     目标实体 ID
## @param default_value 实体不存在此组件时返回的默认值（默认 null）
## @return Variant      组件值或默认值
## Example: [code]var health: int = store.get_value(entity_id, 0)[/code].
func get_value(entity_id: int, default_value: Variant = null) -> Variant:
	return _values.get(entity_id, default_value)


## 返回所有拥有此组件的实体 ID 列表（按当前内部顺序）。
##
## 注意：返回的是内部数组的【副本】，外部修改不会影响内部数据，
## 代价是每次调用都有 O(n) 的拷贝开销，热路径中慎用。
##
## @return Array[int] 实体 ID 数组副本
## Example: [code]for entity_id in store.entities(): pass[/code].
func entities() -> Array[int]:
	return _entities.duplicate()


## 返回当前拥有此组件的实体数量。
## @return int 组件数量
## Example: [code]if store.size() == 0: pass[/code].
func size() -> int:
	return _entities.size()


# ---------------------------------------------------------------------------
# 清空
# ---------------------------------------------------------------------------

## 清空所有数据，将容器恢复到初始状态。
## 三个结构必须同时清空，以保持一致性。
## Example: [code]store.clear()[/code].
func clear() -> void:
	_values.clear()   # 清空组件值表
	_entities.clear() # 清空稠密实体数组
	_indices.clear()  # 清空反向索引表
