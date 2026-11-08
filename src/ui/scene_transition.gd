extends Node

## 场景切换的统一入口（autoload 名：SceneTransition）。
##
## 为什么不直接写 ScreenFade.zoom_to_packed(...)：
##   ScreenFade 是「场景 autoload」，GDScript 在编译期只认它的根节点类型（CanvasLayer），
##   直接调用它脚本里的自定义方法会报「方法不存在」，导致整个脚本解析失败。
##   这里通过节点查找转发一层，既避开该限制，也能在 ScreenFade 没注册时优雅退化。
##
## 用法：
##   await SceneTransition.zoom_to_packed(scene, focus_screen_pos)
##   await SceneTransition.zoom_to_node(node, focus_screen_pos)
##   await SceneTransition.fade_to_packed(scene)

## 圆形扩散转场：圆圈从 focus（屏幕像素坐标）长大包住旧画面，切场景后散开。
func circle_to_packed(scene: PackedScene, focus: Vector2) -> void :
	if scene == null:
		return
	var fade := _screen_fade()
	if fade != null and fade.has_method("circle_to_scene_packed"):
		await fade.circle_to_scene_packed(scene, focus)
		return
	get_tree().change_scene_to_packed(scene)

## 圆形扩散转场到已实例化的节点。
func circle_to_node(node: Node, focus: Vector2) -> void :
	if node == null:
		return
	var fade := _screen_fade()
	if fade != null and fade.has_method("circle_to_scene_node"):
		await fade.circle_to_scene_node(node, focus)
		return
	get_tree().change_scene_to_node(node)

## 推镜转场：切到 PackedScene，以 focus（屏幕像素坐标）为中心放大。
func zoom_to_packed(scene: PackedScene, focus: Vector2) -> void :
	if scene == null:
		return
	var fade := _screen_fade()
	if fade != null and fade.has_method("zoom_to_scene_packed"):
		await fade.zoom_to_scene_packed(scene, focus)
		return
	get_tree().change_scene_to_packed(scene)

## 推镜转场：切到已实例化的节点。
func zoom_to_node(node: Node, focus: Vector2) -> void :
	if node == null:
		return
	var fade := _screen_fade()
	if fade != null and fade.has_method("zoom_to_scene_node"):
		await fade.zoom_to_scene_node(node, focus)
		return
	get_tree().change_scene_to_node(node)

## 普通渐变切换（不推镜）。
func fade_to_packed(scene: PackedScene) -> void :
	if scene == null:
		return
	var fade := _screen_fade()
	if fade != null and fade.has_method("change_scene_to_packed"):
		await fade.change_scene_to_packed(scene)
		return
	get_tree().change_scene_to_packed(scene)

func fade_to_node(node: Node) -> void :
	if node == null:
		return
	var fade := _screen_fade()
	if fade != null and fade.has_method("change_scene_to_node"):
		await fade.change_scene_to_node(node)
		return
	get_tree().change_scene_to_node(node)

func _screen_fade() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("ScreenFade")
