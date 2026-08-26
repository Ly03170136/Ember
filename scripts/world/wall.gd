extends Node2D
## 可破坏墙体（独立Sprite2D方案）
## 一整张精灵图就是一面墙，不是用瓦片拼凑

@export var wall_name: String = "围墙"
@export var max_health: float = 100.0
@export var is_indestructible: bool = false

var health: float = 100.0
var is_destroyed: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: StaticBody2D = $StaticBody2D


func _ready() -> void:
	add_to_group("wall")
	add_to_group("building")
	health = max_health


func take_damage(amount: float, attacker: Node) -> void:
	if is_destroyed or is_indestructible:
		return
	health -= amount
	print("[Wall] ", wall_name, " 受到 ", amount, " 伤害，剩余: ", health)
	if health <= 0:
		_destroy()


func _destroy() -> void:
	is_destroyed = true
	if sprite:
		sprite.visible = false
	if collision:
		collision.queue_free()
	print("[Wall] ", wall_name, " 被摧毁！")


func repair() -> void:
	is_destroyed = false
	health = max_health
	if sprite:
		sprite.visible = true
	print("[Wall] ", wall_name, " 已修复")
