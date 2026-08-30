class_name EcsRunner
extends Node

## [Node]-based host for an [EcsWorld]. Add it to a scene to align ECS lifecycle with
## Godot's process loop, without coupling [EcsWorld] itself to the scene tree.[br][br]
## [codeblock]
## var runner := EcsRunner.new()
## add_child(runner)
## runner.add_system(EcsMovementSystem.new())
## [/codeblock]
##
## @tutorial(Node and SceneTree): https://docs.godotengine.org/en/stable/getting_started/step_by_step/nodes_and_scenes.html

## EcsWorld 与 Godot 场景树之间的桥接器（适配器）。
##
## 设计动机：EcsWorld 是纯逻辑对象（继承 RefCounted），
## 不依赖任何 Node / SceneTree，因此可以：
##   · 在单元测试中脱离场景树手动 tick（确定性、可回放）
##   · 在 headless 服务器中运行
##   · 与任何宿主环境解耦
## 本类负责把 Godot 的节点生命周期"翻译"成世界的生命周期：
##   _ready()           -> world.start()  （开机）
##   _process/_physics  -> world.tick()   （每帧推进模拟）
##   _exit_tree()       -> world.stop()   （关机）

## 时钟选择：
## false = 跟随渲染帧（_process，delta 为实际帧耗时）——适合视觉表现
## true  = 跟随物理帧（_physics_process，固定步长，默认 1/60 秒）
##         步长恒定 => 模拟确定 => 利于网络同步 / 录像回放 / 物理稳定
## @export 使其可在编辑器 Inspector 中配置
## Selects [method Node._physics_process] instead of [method Node._process] when enabled.
## Use the physics clock for fixed-step simulation; the default follows rendered frames.
@export var use_physics_process: bool = false

# 本 Runner 托管的 ECS 世界（每个 Runner 独占一个世界；
# 需要多世界隔离时，挂多个 EcsRunner 节点即可）
## World owned and started by this runner. Add systems before or after entering the tree.
var world: EcsWorld = EcsWorld.new()

# 运行状态标记：防止 world.stop() 被重复调用
# （例如节点被移出树 -> 加回 -> 再移出的场景）
var _running: bool = false


## 节点就绪（进入树且所有子节点准备完毕）—— 世界的"开机"时刻。
##
## 为什么放 _ready 而不是 _init：
## 此时节点已在树中、导出属性已从场景恢复赋值，
## 系统若需访问场景树或兄弟节点，时机才安全。
## Example: [code]runner.world.start()[/code] is called automatically here.
func _ready() -> void:
	# 互斥启用：只在选定的时钟上收到回调。
	# 直接关闭另一个回调，比两个都开、内部再判 flag 更省——
	# 每帧少一次无效函数调用与分支判断。
	set_process(not use_physics_process)
	set_physics_process(use_physics_process)
	
	# 世界进入运行态（通常在此初始化所有已注册的系统）
	world.start()
	_running = true


## 渲染帧回调（仅当 use_physics_process == false 时被启用）。
## delta：距上一渲染帧的实际秒数（可变，随帧率波动）
## Example: Godot invokes this method automatically every rendered frame.
func _process(delta: float) -> void:
	# 双保险：即便外部误调 set_process(true)，也不会双重 tick
	if _running and not use_physics_process:
		world.tick(delta)   # 推进世界一个时间步：依次执行所有系统


## 物理帧回调（仅当 use_physics_process == true 时被启用）。
## delta：恒定物理步长（由 Engine.physics_ticks_per_second 决定，默认 60Hz）
## 注意：一个渲染帧内可能被调用 0 次、1 次或多次
## （帧率与物理频率不匹配时，Godot 会自动补跑或跳过）
## Example: set [member use_physics_process] to [code]true[/code] to activate this callback.
func _physics_process(delta: float) -> void:
	if _running and use_physics_process:
		world.tick(delta)


## 注册系统 —— 对 world.add_system 的薄代理（转发并透传返回值）。
## 提供"只接触 Runner 就能搭起整套 ECS"的门面便捷性。
## Example: [code]runner.add_system(EcsMovementSystem.new())[/code].
func add_system(system: EcsSystem) -> bool:
	return world.add_system(system)


## 节点离开场景树 —— 世界的"关机"时刻。
##
## 选 _exit_tree 而非析构通知：切场景 / remove_child 时即触发，
## 收尾不必等到对象真正销毁。
## _running 守卫：同一节点可能多次进出树，保证 stop() 只执行一次。
## Example: called automatically when [code]runner.queue_free()[/code] completes.
func _exit_tree() -> void:
	if _running:
		world.stop()   # 停止世界（通常通知各系统做最终清理）
		_running = false
