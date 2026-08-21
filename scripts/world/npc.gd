## 人类NPC系统：普通市民、警察
## NPC可以被感染，感染后变成僵尸
## 警察会攻击攻击未感染NPC的玩家

extends CharacterBody2D

# NPC类型
const NPC_TYPES := {
	"civilian": {
		"name": "市民",
		"speed": 40.0,
		"max_health": 50.0,
		"color": Color(0.7, 0.6, 0.5),
		"scale": 1.0,
		"is_police": false
	},
	"police": {
		"name": "警察",
		"speed": 60.0,
		"max_health": 100.0,
		"color": Color(0.2, 0.3, 0.6),
		"scale": 1.1,
		"is_police": true,
		"damage": 15.0,
		"attack_range": 50.0,
		"attack_cooldown": 1.0
	}
}

@export var npc_type: String = "civilian"
var _type_config: Dictionary = {}
var health: float = 50.0
var is_infected: bool = false
var infection_timer: float = 0.0  # 感染后多久变成僵尸（一个季节）
var target: Node2D = null
var wander_direction: Vector2 = Vector2.ZERO
var wander_timer: float = 0.0
var attack_timer: float = 0.0
var is_dead: bool = false
var criminal_target: Node2D = null  # 犯罪目标（攻击过平民的玩家）

# 静态犯罪玩家列表（所有警察共享）
static var criminal_players: Dictionary = {}  # {player_id: expire_time}

@onready var sprite: Sprite2D = $Sprite

static var _npc_textures: Dictionary = {}


func _ready() -> void:
	add_to_group("npc")
	# 初始化NPC类型
	if NPC_TYPES.has(npc_type):
		_type_config = NPC_TYPES[npc_type]
	else:
		_type_config = NPC_TYPES["civilian"]
		npc_type = "civilian"
	health = _type_config.max_health
	# 设置精灵
	if not _npc_textures.has(npc_type):
		_npc_textures[npc_type] = _make_npc_texture(npc_type)
	if sprite:
		sprite.texture = _npc_textures[npc_type]
		sprite.modulate = _type_config.color
		sprite.scale = Vector2(_type_config.scale, _type_config.scale)


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	# 感染处理
	if is_infected:
		infection_timer -= delta
		if infection_timer <= 0:
			_turn_into_zombie()
			return
	# 行为逻辑
	if _type_config.is_police:
		_police_behavior(delta)
	else:
		_civilian_behavior(delta)
	# 移动
	if velocity.length() > 0.1:
		move_and_slide()


func _civilian_behavior(delta: float) -> void:
	## 市民行为：随机漫游，被攻击时逃跑
	# 感染后行动迟缓（速度降低50%），但不会攻击玩家
	var current_speed: float = _type_config.speed
	if is_infected:
		current_speed *= 0.5
	# 随机漫游
	wander_timer -= delta
	if wander_timer <= 0:
		wander_timer = randf_range(2.0, 5.0)
		wander_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	velocity = wander_direction * current_speed


func _police_behavior(delta: float) -> void:
	## 警察行为：优先攻击丧尸，犯罪玩家才会被追击
	# 感染后行动迟缓（速度降低50%），且不再追击玩家，只攻击丧尸
	var current_speed: float = _type_config.speed
	if is_infected:
		current_speed *= 0.5
	attack_timer = max(0, attack_timer - delta)
	var world: Node = get_tree().current_scene
	if not world or not world.has_node("WorldLayer"):
		# 巡逻
		_patrol(delta)
		return
	var world_layer: Node = world.get_node("WorldLayer")
	# 1. 优先寻找附近的丧尸（250像素范围内）
	var nearest_zombie: Node2D = null
	var nearest_zombie_dist: float = 250.0
	for child in world_layer.get_children():
		if child.is_in_group("zombie"):
			var dist: float = position.distance_to(child.position)
			if dist < nearest_zombie_dist:
				nearest_zombie_dist = dist
				nearest_zombie = child
	# 2. 检查是否有犯罪目标（攻击过平民的玩家）- 感染后不再追击玩家
	if not is_infected:
		_update_criminal_target()
	# 3. 优先攻击：犯罪玩家很近时优先追击，否则优先攻击丧尸
	var criminal_near: bool = false
	if not is_infected and criminal_target and is_instance_valid(criminal_target):
		var criminal_dist: float = position.distance_to(criminal_target.position)
		if criminal_dist < 150:
			criminal_near = true

	if criminal_near:
		# 犯罪玩家很近，优先追击
		var dist: float = position.distance_to(criminal_target.position)
		var dir: Vector2 = (criminal_target.position - position).normalized()
		velocity = dir * current_speed
		if dist < _type_config.attack_range and attack_timer <= 0:
			attack_timer = _type_config.attack_cooldown
			if criminal_target.has_method("take_damage"):
				criminal_target.take_damage(_type_config.damage)
				print("[Police] 警察攻击犯罪玩家，造成%d伤害" % _type_config.damage)
	elif nearest_zombie:
		# 追击并攻击丧尸
		var dir: Vector2 = (nearest_zombie.position - position).normalized()
		velocity = dir * current_speed
		if nearest_zombie_dist < _type_config.attack_range and attack_timer <= 0:
			attack_timer = _type_config.attack_cooldown
			if nearest_zombie.has_method("take_damage"):
				nearest_zombie.take_damage(_type_config.damage, self)
				print("[Police] 警察攻击丧尸，造成%d伤害" % _type_config.damage)
	elif not is_infected and criminal_target and is_instance_valid(criminal_target):
		# 追击犯罪玩家（仅未感染时）
		var dist: float = position.distance_to(criminal_target.position)
		var dir: Vector2 = (criminal_target.position - position).normalized()
		velocity = dir * current_speed
		if dist < _type_config.attack_range and attack_timer <= 0:
			attack_timer = _type_config.attack_cooldown
			if criminal_target.has_method("take_damage"):
				criminal_target.take_damage(_type_config.damage)
				print("[Police] 警察攻击犯罪玩家，造成%d伤害" % _type_config.damage)
	else:
		# 巡逻
		_patrol(delta)


func _patrol(delta: float) -> void:
	## 巡逻行为
	wander_timer -= delta
	if wander_timer <= 0:
		wander_timer = randf_range(3.0, 6.0)
		wander_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	var patrol_speed: float = _type_config.speed * 0.5
	if is_infected:
		patrol_speed *= 0.5  # 感染后再降低50%
	velocity = wander_direction * patrol_speed


func _update_criminal_target() -> void:
	## 更新犯罪目标（检查犯罪玩家列表）
	# 如果当前目标已失效或不再是罪犯，清除
	if criminal_target and (not is_instance_valid(criminal_target) or not _is_criminal(criminal_target)):
		criminal_target = null
	# 寻找最近的犯罪玩家（扩大范围到500像素）
	if not criminal_target:
		var nearest: Node2D = null
		var nearest_dist: float = 500.0
		for pid: int in GameManager.players.keys():
			var p: Node2D = GameManager.players[pid]
			if is_instance_valid(p) and _is_criminal(p):
				var dist: float = position.distance_to(p.position)
				if dist < nearest_dist:
					nearest_dist = dist
					nearest = p
		criminal_target = nearest


func _is_criminal(player: Node2D) -> bool:
	## 检查玩家是否是罪犯（在犯罪列表中且未过期）
	var player_id: int = player.get_instance_id()
	if criminal_players.has(player_id):
		var expire_time: float = criminal_players[player_id]
		if Time.get_ticks_msec() / 1000.0 < expire_time:
			return true
		else:
			criminal_players.erase(player_id)
	return false


static func mark_criminal(player: Node2D, duration: float = 120.0) -> void:
	## 标记玩家为罪犯（持续duration秒）
	var player_id: int = player.get_instance_id()
	var expire_time: float = Time.get_ticks_msec() / 1000.0 + duration
	criminal_players[player_id] = expire_time
	print("[Police] 玩家被标记为罪犯，持续%.0f秒" % duration)


func take_damage(amount: float, attacker: Node2D = null) -> void:
	## NPC受伤（只有真正造成伤害时才会触发警察）
	if is_dead:
		return
	# 确保伤害值大于0
	if amount <= 0:
		return
	health -= amount
	print("[NPC] %s 受到%.0f伤害，剩余%.0f生命，攻击者: %s" % [
		_type_config.name, amount, health,
		attacker.name if attacker else "Unknown"
	])
	# 只有平民被玩家攻击时，才标记玩家为罪犯并通知警察
	# 警察被攻击不会触发（警察内部矛盾不触发犯罪系统）
	if attacker and attacker.is_in_group("player") and not _type_config.is_police:
		print("[Police] 平民被玩家攻击，标记玩家为罪犯并通知附近警察")
		mark_criminal(attacker, 120.0)
		_notify_police(attacker)
	if health <= 0:
		_die()


func _notify_police(attacker: Node2D) -> void:
	## 通知附近警察有罪犯（扩大范围到600像素）
	var world: Node = get_tree().current_scene
	if not world or not world.has_node("WorldLayer"):
		return
	var world_layer: Node = world.get_node("WorldLayer")
	var notified_count: int = 0
	for child in world_layer.get_children():
		if child.is_in_group("npc") and child.npc_type == "police":
			var dist: float = position.distance_to(child.position)
			if dist < 600:
				child.criminal_target = attacker
				notified_count += 1
	print("[Police] 通知了%d个警察前往追捕罪犯" % notified_count)


func _die() -> void:
	## NPC死亡
	is_dead = true
	print("[NPC] %s 死亡" % _type_config.name)
	# 死亡后变成僵尸（如果未感染，直接死亡；如果感染，变成僵尸）
	if is_infected:
		_turn_into_zombie()
	else:
		# 普通死亡，掉落物品
		queue_free()


func infect() -> void:
	## 感染NPC
	if is_infected:
		return
	is_infected = true
	# 感染到变为丧尸的时间：游戏内12-24小时随机
	# 游戏内一天=900秒（15分钟），所以12小时=450秒，24小时=900秒
	infection_timer = randf_range(450.0, 900.0)
	print("[NPC] %s 被感染，将在%.0f秒后（%.1f-%.1f游戏内小时）变成僵尸" % [_type_config.name, infection_timer, infection_timer/900.0*24, infection_timer/900.0*24])
	# 感染后颜色变化（稍微变绿，表示感染）
	if sprite:
		sprite.modulate = Color(0.7, 0.9, 0.7, 1.0)
		sprite.modulate = Color(0.5, 0.7, 0.4)


func _turn_into_zombie() -> void:
	## NPC变成僵尸
	print("[NPC] %s 变成僵尸！" % _type_config.name)
	# 生成僵尸
	var zombie_scene: PackedScene = load("res://scenes/entities/zombie.tscn")
	if zombie_scene:
		var zombie: Node2D = zombie_scene.instantiate()
		zombie.position = position
		zombie.name = "InfectedZombie_%d" % randi()
		get_parent().add_child(zombie)
		zombie.add_to_group("zombie")
		# 注册到分块加载系统
		var main: Node = get_tree().current_scene
		if main and main.has_method("_register_chunk_entity"):
			main._register_chunk_entity(zombie)
	queue_free()


static func _make_npc_texture(npc_type: String = "civilian") -> Texture2D:
	var size := 48
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := size / 2.0
	var body_color := Color(0.7, 0.6, 0.5, 1)
	var head_color := Color(0.85, 0.7, 0.55, 1)
	match npc_type:
		"civilian":
			# 普通市民
			img.fill_rect(Rect2(center - 8, center + 4, 16, 16), body_color)
			img.fill_rect(Rect2(center - 6, center - 8, 12, 12), head_color)
		"police":
			# 警察
			img.fill_rect(Rect2(center - 9, center + 4, 18, 16), Color(0.2, 0.3, 0.6, 1))
			img.fill_rect(Rect2(center - 6, center - 8, 12, 12), head_color)
			img.fill_rect(Rect2(center - 7, center - 10, 14, 4), Color(0.15, 0.2, 0.5, 1))
	var tex := ImageTexture.create_from_image(img)
	return tex
