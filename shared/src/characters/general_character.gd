extends Resource
class_name general_character

@export var character_name: String = "未知角色"
@export var max_health: int = 100
@export var current_health: int = 100
@export var attack_speed_constant_value: float
@export var attack_speed_ratio: float = 1.0
@export var speed: float
@export var speed_ratio: float = 1.0
@export var damage_ratio: float = 1.0
@export var row: int
@export var column: int
@export_enum("plant", "zombie") var attack_object: String = "plant"
