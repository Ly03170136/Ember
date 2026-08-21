## 载具系统：自行车、摩托车、汽车、卡车、装甲车
## 玩家可以进入/退出载具，驾驶移动

extends CharacterBody2D

# 载具类型配置
const VEHICLE_TYPES := {
	"bicycle": {
		"name": "自行车",
		"max_speed": 40.0,
		"acceleration": 80.0,
		"friction": 100.0,
		"fuel_consumption": 0.0,  # 不用油
		"max_fuel": 0.0,
		"max_health": 50.0,
		"max_passengers": 1,
		"cargo_capacity": 10,
		"color": Color(0.6, 0.4, 0.2),
		"scale": 0.8,
		"can_attack": false
	},
	"motorcycle": {
		"name": "摩托车",
		"max_speed": 200.0,
		"acceleration": 150.0,
		"friction": 80.0,
		"fuel_consumption": 0.5,  # 每秒油耗
		"max_fuel": 20.0,
		"max_health": 80.0,
		"max_passengers": 2,
		"cargo_capacity": 20,
		"color": Color(0.3, 0.3, 0.35),
		"scale": 0.9,
		"can_attack": false
	},
	"car": {
		"name": "小汽车",
		"max_speed": 160.0,
		"acceleration": 100.0,
		"friction": 60.0,
		"fuel_consumption": 1.0,
		"max_fuel": 50.0,
		"max_health": 150.0,
		"max_passengers": 4,
		"cargo_capacity": 50,
		"color": Color(0.4, 0.5, 0.7),
		"scale": 1.1,
		"can_attack": false
	},
	"truck": {
		"name": "卡车",
		"max_speed": 100.0,
		"acceleration": 60.0,
		"friction": 50.0,
		"fuel_consumption": 1.5,
		"max_fuel": 100.0,
		"max_health": 250.0,
		"max_passengers": 3,
		"cargo_capacity": 200,
		"color": Color(0.5, 0.45, 0.35),
		"scale": 1.4,
		"can_attack": false
	},
	"armored": {
		"name": "装甲车",
		"max_speed": 90.0,
		"acceleration": 50.0,
		"friction": 40.0,
		"fuel_consumption": 2.0,
		"max_fuel": 80.0,
		"max_health": 500.0,
		"max_passengers": 4,
		"cargo_capacity": 100,
		"color": Color(0.35, 0.4, 0.35),
		"scale": 1.5,
		"can_attack": true,  # 可以撞丧尸
		"ram_damage": 50.0
	}
}

@export var vehicle_type: String = "bicycle"
@export var is_wreck: bool = false  # 是否是废弃残骸

var _type_config: Dictionary = {}
var health: float = 100.0
var fuel: float = 0.0
var is_occupied: bool = false
var driver: Node2D = null
var current_speed: float = 0.0

@onready var sprite: Sprite2D = $Sprite
@onready var collision: CollisionShape2D = $CollisionShape2D

static var _vehicle_textures: Dictionary = {}


func _ready() -> void:
	add_to_group("vehicle")
	# 初始化载具类型
	if VEHICLE_TYPES.has(vehicle_type):
		_type_config = VEHICLE_TYPES[vehicle_type]
	else:
		_type_config = VEHICLE_TYPES["bicycle"]
		vehicle_type = "bicycle"
	health = _type_config.max_health
	fuel = _type_config.max_fuel * 0.5  # 初始半箱油
	# 设置精灵
	if not _vehicle_textures.has(vehicle_type):
		_vehicle_textures[vehicle_type] = _make_vehicle_texture(vehicle_type)
	if sprite:
		sprite.texture = _vehicle_textures[vehicle_type]
		sprite.modulate = _type_config.color
		sprite.scale = Vector2(_type_config.scale, _type_config.scale)
	# 废弃残骸显示为损坏状态
	if is_wreck:
		if sprite:
			sprite.modulate = Color(0.3, 0.3, 0.3)
			sprite.rotation = randf_range(-0.3, 0.3)


func _physics_process(delta: float) -> void:
	if not is_occupied or not driver:
		# 无人驾驶时，摩擦力减速
		if velocity.length() > 0.1:
			velocity = velocity.lerp(Vector2.ZERO, delta * 2.0)
			move_and_slide()
		return
	# 有人驾驶时，处理输入
	_handle_driving(delta)
	# 油耗
	if _type_config.fuel_consumption > 0 and fuel > 0:
		fuel = max(0, fuel - _type_config.fuel_consumption * delta)
		if fuel <= 0:
			print("[Vehicle] %s 没油了！" % _type_config.name)


func _handle_driving(delta: float) -> void:
	# 获取输入方向
	var input_dir: Vector2 = Vector2.ZERO
	if InputManager and InputManager.is_action_pressed("move_up"):
		input_dir.y -= 1
	if InputManager and InputManager.is_action_pressed("move_down"):
		input_dir.y += 1
	if InputManager and InputManager.is_action_pressed("move_left"):
		input_dir.x -= 1
	if InputManager and InputManager.is_action_pressed("move_right"):
		input_dir.x += 1
	input_dir = input_dir.normalized()
	# 没油时不能加速
	if _type_config.fuel_consumption > 0 and fuel <= 0:
		input_dir = Vector2.ZERO
	# 加速
	if input_dir.length() > 0:
		velocity += input_dir * _type_config.acceleration * delta
	else:
		# 摩擦力减速
		velocity = velocity.lerp(Vector2.ZERO, delta * _type_config.friction / 50.0)
	# 限制最大速度
	velocity = velocity.limit_length(_type_config.max_speed)
	# 移动
	move_and_slide()
	# 装甲车撞击丧尸
	if _type_config.can_attack and velocity.length() > 50:
		_check_ram_collision()
	# 驾驶员跟随载具
	if driver:
		driver.position = position
		driver.visible = false


func _check_ram_collision() -> void:
	## 装甲车撞击丧尸
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
	query.position = position
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.collision_mask = 8  # enemy层
	var results: Array = space_state.intersect_point(query, 10)
	for result in results:
		var collider: Node = result.collider
		if collider and collider.is_in_group("zombie") and collider.has_method("take_damage"):
			collider.take_damage(_type_config.ram_damage, self)


func enter_vehicle(player: Node2D) -> bool:
	## 玩家进入载具
	if is_occupied:
		return false
	if is_wreck:
		print("[Vehicle] 这是废弃残骸，无法驾驶")
		return false
	if health <= 0:
		print("[Vehicle] 载具已损坏，需要维修")
		return false
	is_occupied = true
	driver = player
	player.visible = false
	print("[Vehicle] 玩家进入%s" % _type_config.name)
	return true


func exit_vehicle() -> void:
	## 玩家退出载具
	if not is_occupied or not driver:
		return
	is_occupied = false
	driver.visible = true
	driver.position = position + Vector2(0, 30)  # 放在载具旁边
	print("[Vehicle] 玩家退出%s" % _type_config.name)
	driver = null


func repair(amount: float) -> void:
	## 维修载具
	health = min(_type_config.max_health, health + amount)
	print("[Vehicle] %s 维修了%.0f点，当前耐久：%.0f/%.0f" % [_type_config.name, amount, health, _type_config.max_health])


func take_damage(amount: float) -> void:
	## 载具受伤
	health = max(0, health - amount)
	if health <= 0:
		print("[Vehicle] %s 被摧毁了！" % _type_config.name)
		if is_occupied:
			exit_vehicle()


func dismantle() -> Dictionary:
	## 拆卸废弃残骸，获得配件
	var parts: Dictionary = {
		"metal": randi_range(2, 5),
		"wire": randi_range(1, 3),
		"engine_part": 1 if randf() < 0.5 else 0
	}
	print("[Vehicle] 拆卸%s，获得配件" % _type_config.name)
	queue_free()
	return parts


static func _make_vehicle_texture(vehicle_type: String = "bicycle") -> Texture2D:
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := size / 2.0
	var body_color := Color(0.5, 0.5, 0.6, 1)
	var wheel_color := Color(0.2, 0.2, 0.2, 1)
	match vehicle_type:
		"bicycle":
			# 自行车：两个轮子+车架
			img.fill_rect(Rect2(center - 20, center + 8, 12, 12), wheel_color)
			img.fill_rect(Rect2(center + 8, center + 8, 12, 12), wheel_color)
			img.fill_rect(Rect2(center - 15, center, 30, 6), body_color)
		"motorcycle":
			# 摩托车
			img.fill_rect(Rect2(center - 18, center + 10, 14, 10), wheel_color)
			img.fill_rect(Rect2(center + 4, center + 10, 14, 10), wheel_color)
			img.fill_rect(Rect2(center - 12, center - 4, 24, 14), body_color)
		"car":
			# 小汽车
			img.fill_rect(Rect2(center - 22, center + 12, 12, 10), wheel_color)
			img.fill_rect(Rect2(center + 10, center + 12, 12, 10), wheel_color)
			img.fill_rect(Rect2(center - 24, center - 6, 48, 20), body_color)
			img.fill_rect(Rect2(center - 16, center - 12, 32, 8), Color(0.6, 0.7, 0.8, 1))
		"truck":
			# 卡车
			img.fill_rect(Rect2(center - 26, center + 14, 14, 12), wheel_color)
			img.fill_rect(Rect2(center + 12, center + 14, 14, 12), wheel_color)
			img.fill_rect(Rect2(center - 28, center - 8, 56, 24), body_color)
			img.fill_rect(Rect2(center - 20, center - 14, 20, 8), Color(0.6, 0.7, 0.8, 1))
		"armored":
			# 装甲车
			img.fill_rect(Rect2(center - 28, center + 14, 16, 12), wheel_color)
			img.fill_rect(Rect2(center + 12, center + 14, 16, 12), wheel_color)
			img.fill_rect(Rect2(center - 30, center - 10, 60, 26), Color(0.4, 0.45, 0.4, 1))
			img.fill_rect(Rect2(center - 8, center - 18, 16, 10), Color(0.3, 0.35, 0.3, 1))
	var tex := ImageTexture.create_from_image(img)
	return tex
