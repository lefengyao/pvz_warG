class_name MapInfo
extends Resource

## 单张地图的配置数据。
##
## 用法：
##   1. 在 resources/maps/ 下新建一个 .tres（右键 → 新建资源 → MapInfo），
##      或者直接复制已有的 courtyard.tres 改内容；
##   2. 打开主场景 scenes/levels/chose_map.tscn，选中对应的卡片实例，
##      把这份 .tres 拖到检查器的 info 属性上。
##
## 这样做的目的：加地图 / 改地图只动这份资源文件，
## 不需要改主界面场景，也不需要改任何脚本。
##
## 卡片场景（scenes/ui/map_card.tscn）会读取下面这些字段：
##   display_name  → 悬停时显示的地图名
##   background    → 卡片的背景图
##   locked        → 是否禁止点击
##   locked_text   → 锁定时显示的文字（未锁定则显示「进入」）
##   target_scene  → 点击后跳转的关卡

## 卡片上显示的地图名，例如「庭院」「森林」「森林深处」。
@export var display_name: String = ""

## 卡片背景图，直接铺在卡片内部（TextureButton.texture_normal）。
## 可以是整张图，也可以是图集里裁出来的 AtlasTexture。
@export var background: Texture2D

## 点击后进入的关卡场景。
## 留空（null）时点击不跳转，通常配合 locked 一起用。
@export var target_scene: PackedScene

## 是否锁定。锁定的卡片点击无反应，状态文字显示 locked_text。
## 例：「森林」「森林深处」目前都还没做，所以是 true。
@export var locked: bool = false

## 锁定状态下显示的文字。未锁定时卡片统一显示「进入」，用不到这个字段。
@export var locked_text: String = "敬请期待"
