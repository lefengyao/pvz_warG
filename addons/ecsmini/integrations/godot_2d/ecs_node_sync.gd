class_name EcsNodeSync
extends RefCounted

## Optional one-to-one bridge between ECS entity IDs and visual [Node2D] instances.
## It observes [signal EcsWorld.entity_destroyed] to remove stale entity mappings, but
## never creates or frees scene nodes itself.[br][br]
## [codeblock]
## var sync := EcsNodeSync.new(world)
## var entity := world.create_entity()
## sync.bind(entity, $Player)
## var player_node := sync.get_node(entity)
## [/codeblock]
##
## @tutorial(Node2D): https://docs.godotengine.org/en/stable/classes/class_node2d.html

## 实体（entity_id）与 Node2D（场景节点）之间的显式双向绑定表。
##
## 【设计定位】
## 本类是 ECS 数据世界与 Godot 场景树之间的"桥梁层"（适配器）：
##   - ECS 实体只是一个 int，不在场景树上，无法直接显示
##   - Godot 渲染必须有 Node2D，但节点本身不属于 ECS 数据体系
##   - 本类用两张映射表把两者关联起来，负责"翻译"工作
##
## 【架构原则】
##   1. 本层是【可选的】——纯逻辑模拟（服务器、无界面测试）不需要它
##   2. 本类【刻意与 EcsWorld 分离】——依赖方向是单向的：
##      本类知道 EcsWorld，但 EcsWorld 完全不知道 Node 的存在
##      （数据层保持纯净，不依赖 Godot 场景系统）
##   3. 实体销毁时只【解除绑定】，不会主动删除节点——
##      删除节点（如播放死亡动画后 free）是表现层自己的职责
##
## 【生命周期防御】
## 本类需要处理两种"不同步"的危险情况：
##   - 实体先死：通过监听 entity_destroyed 信号自动解绑
##   - 节点先死：通过 is_instance_valid() 校验 + 惰性清理兜底
##
## 【绑定约定】
##   - 一个实体最多绑定一个节点（重复绑定时自动替换旧节点）
##   - 一个节点最多绑定一个实体（重复绑定时自动替换旧实体）

# ---------------------------------------------------------------------------
# 内部数据结构：双向映射表
# ---------------------------------------------------------------------------

## 正向表：entity_id（实体 ID）-> Node2D（绑定的场景节点）
## 用途：渲染系统拿到实体后，查它对应的显示节点
##      例如："实体 1001 的位置更新了，该移动哪个 Sprite？"
var _entity_to_node: Dictionary = {}

## 反向表：节点实例 ID -> 实体 ID
## 用途：交互事件拿到节点后，查它对应的实体
##      例如："玩家点击了这个敌人 Sprite，该扣哪个实体的血？"
##
## 注意：键使用 node.get_instance_id()（Godot 为每个对象分配的唯一编号），
## 而不是节点引用本身——这是 Godot 中以对象为字典键的标准做法，
## 可以避免对象哈希比较带来的问题，且便于字典序列化与查找。
var _node_to_entity: Dictionary = {}

## 当前关联的 ECS 数据世界。
## 绑定关系必须依附于某个世界：查询实体是否存活、监听销毁信号都依赖它。
var _world: EcsWorld


# ---------------------------------------------------------------------------
# 构造与世界关联
# ---------------------------------------------------------------------------

## 构造函数。可选择在创建时直接关联一个世界。
## @param world 要关联的世界，传 null 则稍后用 attach_world() 手动关联
## Example: [code]var sync := EcsNodeSync.new(world)[/code].
func _init(world: EcsWorld = null) -> void:
	if world != null:
		attach_world(world)


## 关联（或切换到）指定的 ECS 世界。
##
## 切换世界时的完整流程：
##   1. 若新旧世界相同，直接返回（避免无意义的清理）
##   2. 若旧世界存在，断开其 entity_destroyed 信号连接
##      （否则旧世界里实体销毁时，本类还会收到"幽灵通知"）
##   3. 清空所有绑定（旧世界的绑定对新世界毫无意义）
##   4. 记录新世界并订阅其销毁信号
##
## @param world 要关联的新世界（可为 null，表示彻底解绑）
## Example: [code]sync.attach_world(next_level_world)[/code].
func attach_world(world: EcsWorld) -> void:
	# 已经是这个世界的桥梁了，无需重复操作
	if _world == world:
		return

	# 若已关联旧世界，先断开旧世界的销毁信号监听
	# is_connected 检查是为了避免重复断开导致报错
	if _world != null and _world.entity_destroyed.is_connected(_on_entity_destroyed):
		_world.entity_destroyed.disconnect(_on_entity_destroyed)

	# 旧世界的所有绑定对新世界无效，全部清空
	clear()

	# 记录新世界
	_world = world

	# 订阅新世界的实体销毁信号
	# 从此该世界销毁任何实体时，_on_entity_destroyed 都会被自动调用
	if _world != null:
		_world.entity_destroyed.connect(_on_entity_destroyed)


# ---------------------------------------------------------------------------
# 绑定 / 解绑
# ---------------------------------------------------------------------------

## 建立实体与节点的双向绑定。
##
## 执行流程：
##   1. 三重防御检查（世界未关联 / 实体已死 / 节点无效）→ 任一失败返回 false
##   2. 清理该实体的旧绑定（若之前绑过别的节点）
##   3. 清理该节点的旧绑定（若之前绑过别的实体）
##   4. 写入两张映射表，完成绑定
##
## 通过第 2、3 步，保证映射关系永远是一对一的：
##   - 一个实体换绑新节点时，旧节点的反向记录会被清除
##   - 一个节点换绑新实体时，旧实体的正向记录会被清除
##
## @param entity_id 目标实体 ID
## @param node      目标 Node2D 节点
## @return bool     绑定成功返回 true；参数无效时返回 false
## Example: [code]sync.bind(player_entity, $Player)[/code].
func bind(entity_id: int, node: Node2D) -> bool:
	# --- 防御检查 ---
	# ① 尚未关联任何世界，无法验证实体，拒绝绑定
	# ② 实体在世界中已不存在（未创建或已被销毁）
	# ③ 节点为 null，或已被 free（悬空引用）
	#    is_instance_valid 是 Godot 检查对象是否仍存活的唯一安全手段：
	#    被 queue_free() 释放后的节点引用不能直接访问，否则程序崩溃
	if _world == null or not _world.is_entity_alive(entity_id) or node == null or not is_instance_valid(node):
		return false

	# 清理该实体的旧绑定（若存在）——保证"一实体一节点"
	unbind(entity_id)

	# 查询该节点是否已绑定了其他实体
	var old_entity: Variant = _node_to_entity.get(node.get_instance_id())
	if old_entity != null:
		# 该节点之前绑的是别的实体，先解除旧关系——保证"一节点一实体"
		unbind(int(old_entity))

	# --- 写入双向映射表 ---
	# 正向：实体 -> 节点
	_entity_to_node[entity_id] = node
	# 反向：节点实例 ID -> 实体
	_node_to_entity[node.get_instance_id()] = entity_id
	return true


## 解除指定实体的绑定关系。
##
## 注意：两张表必须【同时】清理，只清一张会留下"半截"脏数据：
##   - 只清正向表：反向查询时还能从节点查到已解绑的实体
##   - 只清反向表：正向表里还留着指向节点的无效引用
##
## 本方法只解除关联，【不会删除节点本身】。
##
## @param entity_id 要解绑的实体 ID（未绑定时静默无操作）
## Example: [code]sync.unbind(player_entity)[/code].
func unbind(entity_id: int) -> void:
	# 从正向表取出该实体绑定的节点
	var node: Node2D = _entity_to_node.get(entity_id)

	# 若存在绑定节点，同步清理反向表中该节点的记录
	if node != null:
		_node_to_entity.erase(node.get_instance_id())

	# 清理正向表中该实体的记录（无论之前是否绑定，erase 都安全）
	_entity_to_node.erase(entity_id)


# ---------------------------------------------------------------------------
# 查询：实体 -> 节点
# ---------------------------------------------------------------------------

## 查询指定实体绑定的节点（正向查询）。
##
## 包含【惰性清理】机制：
## 节点可能被外部代码（非本类）提前 free，本类无法收到通知，
## 映射表中会残留指向已死节点的"悬空绑定"。
## 这里在查询时顺手检查——一旦发现节点已失效，立即清除这条脏数据，
## 用最小代价保持数据一致性，无需定时全表扫描。
##
## 典型用途：渲染系统遍历实体，取节点更新其 position 等显示属性。
##
## @param entity_id 目标实体 ID
## @return Node2D   绑定的节点；未绑定、节点已被释放时返回 null
## Example: [code]var node := sync.get_node(player_entity)[/code].
func get_node(entity_id: int) -> Node2D:
	# 从正向表查找节点
	var node: Node2D = _entity_to_node.get(entity_id)

	# 两种失败情况：
	#   node == null               → 该实体从未绑定或已解绑
	#   not is_instance_valid(node)→ 节点已被 free（悬空引用）
	if node == null or not is_instance_valid(node):
		# 惰性清理：节点已死，这条绑定成为脏数据，顺手清除
		unbind(entity_id)
		return null

	return node


# ---------------------------------------------------------------------------
# 查询：节点 -> 实体
# ---------------------------------------------------------------------------

## 查询指定节点绑定的实体（反向查询）。
##
## 典型用途：处理鼠标点击、碰撞信号等"从场景节点出发"的交互事件，
## 将 Node2D 翻译回 ECS 实体 ID，再交给数据层的系统处理。
##
## @param node 目标节点
## @return int 绑定的实体 ID；节点无效或未绑定时返回 -1（哨兵值）
## Example: [code]var entity_id := sync.get_entity(clicked_node)[/code].
func get_entity(node: Node2D) -> int:
	# 节点为 null 或已被释放，必然查不到实体
	if node == null or not is_instance_valid(node):
		return -1

	# 从反向表查找，找不到返回 -1
	# get() 返回的可能是 Variant，用 int() 显式转换回整数
	return int(_node_to_entity.get(node.get_instance_id(), -1))


# ---------------------------------------------------------------------------
# 清理
# ---------------------------------------------------------------------------

## 清空所有绑定关系（两张表同时清空，保持一致性）。
##
## 注意：只清除映射记录，不影响任何实体或节点的存活状态。
## 适用场景：切换世界、整体重置表现层等。
## Example: [code]sync.clear()[/code].
func clear() -> void:
	_entity_to_node.clear()   # 清空正向表
	_node_to_entity.clear()   # 清空反向表


# ---------------------------------------------------------------------------
# 信号回调
# ---------------------------------------------------------------------------

## entity_destroyed 信号的回调：实体被销毁时自动解除其绑定。
##
## 这是对抗"实体先死、节点还在"不同步情况的核心防线：
## 当 EcsWorld 销毁某个实体时发出信号，本方法被自动调用，
## 该实体的绑定记录立即被清除——之后 get_node() 对它返回 null。
##
## 【职责边界】此处只做解绑，【绝不删除节点】：
## 表现层可能需要节点播放死亡动画、掉落特效后再自行 free，
## 删除时机的决定权在表现层手中，桥梁只保证映射表不失真。
##
## @param entity_id 被销毁的实体 ID
func _on_entity_destroyed(entity_id: int) -> void:
	unbind(entity_id)
