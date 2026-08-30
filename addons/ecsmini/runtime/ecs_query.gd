class_name EcsQuery
extends RefCounted

## Cached component query created by [method EcsWorld.query]. A query refreshes only
## after entity or component membership changes in its world.[br][br]
## [codeblock]
## var movers := world.query({"all": [&"position", &"velocity"], "none": [&"dead"]})
## for entity_id in movers.entities():
##     print(entity_id)
## [/codeblock]
##
## @tutorial(GDScript documentation comments): https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_documentation_comments.html

## 查询定义（带结果缓存）。
##
## 本类是 ECS 架构中的“查询器”：按组件条件从 EcsWorld 中筛选实体。
## 筛选条件分三组（all / any / none），结果会被缓存，
## 仅当世界的“拓扑结构”（实体与组件的从属关系）发生变化后才重建快照。
##
## 继承 RefCounted：引用计数管理，无人持有时自动释放，无手动 free 负担。

# 所属的 ECS 世界，即查询的数据源
var _world: EcsWorld

# “全部匹配”条件：实体必须同时拥有此列表中的【所有】组件
# 使用 StringName 而非 String：内部驻留字符串，比较按指针进行，性能更优
var _all: Array[StringName]

# “任意匹配”条件：实体至少拥有此列表中的【其中一个】组件
# （为空数组时此条件不生效，等价于无条件）
var _any: Array[StringName]

# “排除”条件：实体【不能】拥有此列表中的任何一个组件
var _none: Array[StringName]

# 缓存构建时所处的世界拓扑版本号（缓存失效机制的核芯）。
# - 当它与 _world._topology_version 相等 => 缓存仍然有效，可直接复用
# - 当两者不相等 => 世界发生过结构性变更，缓存已过期，需重建
# 初始值 -1 保证第一次访问时必然触发一次刷新（构建初始缓存）
var _compiled_topology_version: int = -1

# 匹配结果缓存：所有满足查询条件的实体 ID 列表
var _matched_entities: Array[int] = []


## 构造函数：由 EcsWorld 内部创建查询时调用，保存世界引用与三组筛选条件。
func _init(
		world: EcsWorld,
		all: Array[StringName],
		any: Array[StringName],
		none: Array[StringName]
) -> void:
	_world = world
	_all = all
	_any = any
	_none = none


## 获取所有匹配的实体 ID 列表（对外只读接口）。
##
## 两个要点：
## 1. 先调用 _refresh_if_needed() 做“惰性刷新”——
##    只有缓存过期时才真正执行筛选计算，平时几乎零开销；
## 2. 返回 duplicate() 副本而非内部数组本身——
##    防止外部代码 push/erase 意外污染内部缓存。
## Example: [code]var ids := movers.entities()[/code].
func entities() -> Array[int]:
	_refresh_if_needed()
	return _matched_entities.duplicate()


## 遍历所有匹配的实体，并对每个实体执行回调：for_each(func(id): ...)
##
## 这是一个“结构性变更安全”的迭代器，做了三重防护：
## 1. _begin_iteration()：通知世界进入迭代状态，
##    期间结构性变更（增删组件/实体）通常会被暂缓排队；
## 2. 遍历的是快照副本——即使在回调中触发了变更，
##    也只会影响下一次查询，本次遍历的集合不受干扰；
## 3. 每次回调前用 is_entity_alive() 复查实体存活性，
##    兜底防止实体已被销毁却仍被回调访问。
## Example: [code]movers.for_each(func(id): world.destroy_entity(id))[/code].
func for_each(callback: Callable) -> void:
	# ① 标记进入迭代状态（世界开始暂缓结构变更）
	_world._begin_iteration()
	
	# ② 取出匹配实体的快照（内部会先做必要的缓存刷新）
	var snapshot := entities()
	
	for entity_id in snapshot:
		# ③ 存活检查：实体在快照拍摄后、回调执行前可能已被销毁
		if _world.is_entity_alive(entity_id):
			callback.call(entity_id)
	
	# ④ 标记退出迭代状态（世界此刻统一应用/刷新被暂缓的变更）
	_world._end_iteration()


## 缓存刷新（核心私有逻辑）：仅当缓存版本落后于世界拓扑版本时才重建。
##
## “拓扑版本”是世界侧的计数器：任何结构性变更（组件的添加/移除等
## 会改变实体-组件从属关系的操作）都会使其 +1，
## 从而使所有旧查询缓存自动失效。
func _refresh_if_needed() -> void:
	# 版本号一致 => 缓存与世界当前状态同步，直接返回（零成本路径）
	if _compiled_topology_version == _world._topology_version:
		return
	
	# 缓存已过期：清空旧结果，准备重建
	_matched_entities.clear()
	
	# 向世界索要“驱动集合”——这是世界侧的剪枝优化：
	# 世界会挑选条件中【选择性最强】的组件（比如最稀有的那个 all 组件），
	# 返回拥有该组件的实体集合作为候选者，
	# 从而避免对世界中的全部实体做暴力遍历。
	var driver: Array[int] = _world._driver_entities_for(_all, _any)
	
	# 对候选实体逐一执行完整的条件判定：
	# all（全部拥有）、any（至少其一）、none（一个都没有），三组必须全部满足
	for entity_id in driver:
		if _world._matches_query(entity_id, _all, _any, _none):
			_matched_entities.append(entity_id)
	
	# 将缓存版本号对齐到世界当前拓扑版本，标记“缓存已同步”
	# （此后直到下一次拓扑变更前，entities() 都会命中缓存直接返回）
	_compiled_topology_version = _world._topology_version
