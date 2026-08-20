extends StaticBody2D
## 资源节点基类：树、石头、浆果丛等可采集资源

@export var resource_name: String = "Resource"
@export var max_health: float = 50.0
@export var drop_item: String = "wood"  # 掉落物品ID
@export var drop_count: int = 3  # 每次采集掉落数量
@export var hit_count: int = 3  # 需要采集几次
@export var respawn_time: float = 60.0  # 重生时间（秒），0=不重生

var health: float = 0.0
var is_depleted: bool = false
var respawn_timer: float = 0.0

# 动画相关
var sway_timer: float = 0.0
var hit_shake_timer: float = 0.0
var base_scale: Vector2 = Vector2.ONE

@onready var sprite: Sprite2D = $Sprite
@onready var area: Area2D = $Area2D

static var _textures: Dictionary = {}


func _ready() -> void:
	health = max_health
	_generate_texture()
	add_to_group("resource")
	if area:
		area.body_entered.connect(_on_body_entered)


func _generate_texture() -> void:
	if not sprite:
		return
	if not _textures.has(resource_name):
		_textures[resource_name] = _make_resource_texture()
	sprite.texture = _textures[resource_name]


func _make_resource_texture() -> Texture2D:
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := size / 2.0
	if resource_name == "Tree":
		# 树干
		for x in range(28, 36):
			for y in range(32, 56):
				img.set_pixel(x, y, Color(0.4, 0.25, 0.1, 1))
		# 树冠
		var cr := 24.0
		for x in range(size):
			for y in range(size):
				var dx := x - center
				var dy := y - (center - 6)
				if dx * dx + dy * dy <= cr * cr:
					img.set_pixel(x, y, Color(0.2, 0.55, 0.2, 1))
	elif resource_name == "Rock":
		var rr := 22.0
		for x in range(size):
			for y in range(size):
				var dx := x - center
				var dy := y - center
				var d := dx * dx + dy * dy
				if d <= rr * rr:
					var n := sin(x * 0.5) * cos(y * 0.3) * 0.1
					img.set_pixel(x, y, Color(0.55 + n, 0.55 + n, 0.6 + n, 1))
	elif resource_name == "BerryBush":
		# 灌木丛
		var br := 20.0
		for x in range(size):
			for y in range(size):
				var dx := x - center
				var dy := y - center
				if dx * dx + dy * dy <= br * br:
					img.set_pixel(x, y, Color(0.25, 0.5, 0.25, 1))
		# 浆果点
		for bx in [22, 38, 30, 42, 20]:
			for by in [24, 28, 40, 36, 44]:
				img.set_pixel(bx, by, Color(0.8, 0.1, 0.1, 1))
				img.set_pixel(bx+1, by, Color(0.8, 0.1, 0.1, 1))
				img.set_pixel(bx, by+1, Color(0.8, 0.1, 0.1, 1))
	else:
		var rr := 20.0
		for x in range(size):
			for y in range(size):
				var dx := x - center
				var dy := y - center
				if dx * dx + dy * dy <= rr * rr:
					img.set_pixel(x, y, Color(0.5, 0.5, 0.5, 1))
	return ImageTexture.create_from_image(img)


func _process(delta: float) -> void:
	if is_depleted:
		if respawn_time > 0:
			respawn_timer -= delta
			if respawn_timer <= 0:
				_respawn()
		return

	# 树木/浆果丛摇晃动画
	if sprite and (resource_name == "Tree" or resource_name == "BerryBush"):
		sway_timer += delta
		var sway_amount: float = sin(sway_timer * 1.5) * 0.03
		sprite.rotation = sway_amount
		# 轻微的呼吸缩放
		var breathe: float = 1.0 + sin(sway_timer * 0.8) * 0.01
		sprite.scale = base_scale * breathe

	# 采集抖动反馈
	if hit_shake_timer > 0:
		hit_shake_timer -= delta
		var shake: float = sin(hit_shake_timer * 40) * 0.1 * (hit_shake_timer / 0.3)
		if sprite:
			sprite.position.x = shake * 20
		if hit_shake_timer <= 0 and sprite:
			sprite.position.x = 0


func hit(damage: float = 1.0) -> void:
	if is_depleted:
		return
	# 触发抖动反馈
	hit_shake_timer = 0.3
	if not GameManager.is_server:
		return  # 只有服务器能修改资源状态
	health -= damage
	if health <= 0:
		_collect()


func _collect() -> void:
	is_depleted = true
	health = 0
	if sprite:
		sprite.visible = false
	# 禁用碰撞，让玩家可以穿过
	var collision: CollisionShape2D = get_node_or_null("CollisionShape2D")
	if collision:
		collision.disabled = true
	# 掉落物品（给附近玩家）
	_drop_items()
	if respawn_time > 0:
		respawn_timer = respawn_time
	else:
		queue_free()


func _drop_items() -> void:
	# 简单处理：在资源位置生成掉落物
	# P0先打印，后续做物品掉落
	print("[Resource] %s collected, dropped %dx %s" % [resource_name, drop_count, drop_item])


func _respawn() -> void:
	is_depleted = false
	health = max_health
	if sprite:
		sprite.visible = true
	# 恢复碰撞
	var collision: CollisionShape2D = get_node_or_null("CollisionShape2D")
	if collision:
		collision.disabled = false


func _on_body_entered(body: Node) -> void:
	pass  # 后续处理交互提示
