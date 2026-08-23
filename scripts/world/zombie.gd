extends CharacterBody2D
## 丧尸AI：6种丧尸类型，白天漫游，夜晚追击玩家，会拆建筑

# ==================== P1: 丧尸类型配置（按GDD详细数值） ====================
const ZOMBIE_TYPES := {
	"normal": {"name": "普通丧尸", "speed": 20.0, "run_speed": 45.0, "damage": 8.0, "max_health": 50.0, "color": Color(0.4, 0.6, 0.3), "spawn_weight": 50, "scale": 1.0, "attack_range": 45.0, "knockback_resistance": 1.0},
	"fast": {"name": "快速丧尸", "speed": 45.0, "run_speed": 80.0, "damage": 5.0, "max_health": 30.0, "color": Color(0.55, 0.4, 0.6), "spawn_weight": 20, "scale": 0.9, "attack_range": 40.0, "knockback_resistance": 1.2},
	"fat": {"name": "胖子丧尸", "speed": 12.0, "run_speed": 25.0, "damage": 25.0, "max_health": 200.0, "color": Color(0.6, 0.4, 0.3), "spawn_weight": 12, "scale": 1.4, "attack_range": 50.0, "explode_on_death": true, "explode_damage": 30.0, "explode_radius": 80.0, "knockback_resistance": 0.4},
	"dog": {"name": "丧尸犬", "speed": 60.0, "run_speed": 100.0, "damage": 6.0, "max_health": 25.0, "color": Color(0.4, 0.35, 0.3), "spawn_weight": 10, "scale": 0.7, "attack_range": 35.0, "knockback_resistance": 1.3},
	"giant": {"name": "巨型丧尸", "speed": 8.0, "run_speed": 18.0, "damage": 50.0, "max_health": 500.0, "color": Color(0.5, 0.5, 0.55), "spawn_weight": 3, "scale": 1.8, "attack_range": 60.0, "knockback": true, "destroy_building": true, "knockback_resistance": 0.2},
	"spitter": {"name": "吐酸变异体", "speed": 18.0, "run_speed": 35.0, "damage": 10.0, "max_health": 100.0, "color": Color(0.3, 0.65, 0.4), "spawn_weight": 5, "scale": 1.1, "attack_range": 150.0, "ranged_attack": true, "acid_dps": 15.0, "corrode_building": true, "knockback_resistance": 0.8},
}

const ATTACK_COOLDOWN := 1.0
const DETECT_RANGE := 150.0
const NIGHT_DETECT_RANGE := 250.0
const LOSE_TARGET_TIME := 3.0

@export var zombie_type: String = "normal"
@export var max_health: float = 30.0
var health: float = 30.0
var attack_timer: float = 0.0
var wander_direction: Vector2 = Vector2.ZERO
var wander_timer: float = 0.0
var target: Node2D = null
var lose_target_timer: float = 0.0
var _type_config: Dictionary = {}
# 击退僵直
var stun_timer: float = 0.0
var knockback_velocity: Vector2 = Vector2.ZERO

# LOD系统：AI更新间隔控制
var ai_update_interval: float = 0.0  # AI更新间隔（0=每帧更新，0.2=每0.2秒更新一次）
var ai_update_timer: float = 0.0  # AI更新计时器
var entity_type: String = "zombie"  # 实体类型（用于LOD系统识别）
var is_horde_zombie: bool = false  # 尸潮丧尸标记，使用简化AI

@onready var sprite: Sprite2D = $Sprite
@onready var synchronizer: MultiplayerSynchronizer = $MultiplayerSynchronizer

static var _zombie_textures: Dictionary = {}


func _ready() -> void:
	# 使用PhysicsLayers系统设置碰撞层和mask（确保丧尸之间、丧尸与资源之间有体积碰撞）
	if PhysicsLayers and PhysicsLayers.has_method("set_collision"):
		PhysicsLayers.set_collision(self, "enemy")
	# 初始化丧尸类型
	if ZOMBIE_TYPES.has(zombie_type):
		_type_config = ZOMBIE_TYPES[zombie_type]
	else:
		_type_config = ZOMBIE_TYPES["normal"]
		zombie_type = "normal"
	max_health = _type_config.max_health
	health = max_health
	# 设置精灵
	if not _zombie_textures.has(zombie_type):
		_zombie_textures[zombie_type] = _make_zombie_texture(zombie_type)
	if sprite:
		sprite.texture = _zombie_textures[zombie_type]
		sprite.modulate = _type_config.color
		sprite.scale = Vector2(_type_config.scale, _type_config.scale)
	if synchronizer:
		synchronizer.replication_config = _build_replication_config()
	# 只有服务器运行AI
	if not GameManager.is_server:
		set_physics_process(false)
	add_to_group("zombie")


func set_zombie_type(new_type: String) -> void:
	## 动态设置丧尸类型（用于尸潮）
	if not ZOMBIE_TYPES.has(new_type):
		return
	zombie_type = new_type
	_type_config = ZOMBIE_TYPES[new_type]
	max_health = _type_config.max_health
	health = max_health
	# 更新精灵
	if not _zombie_textures.has(zombie_type):
		_zombie_textures[zombie_type] = _make_zombie_texture(zombie_type)
	if sprite:
		sprite.texture = _zombie_textures[zombie_type]
		sprite.modulate = _type_config.color
		sprite.scale = Vector2(_type_config.scale, _type_config.scale)


func _build_replication_config() -> SceneReplicationConfig:
	var config := SceneReplicationConfig.new()
	config.add_property(NodePath("position"))
	config.add_property(NodePath("health"))
	return config


func _physics_process(delta: float) -> void:
	if not GameManager.is_server:
		return
	attack_timer = max(0, attack_timer - delta)
	# 僵直状态处理
	if stun_timer > 0:
		stun_timer = max(0, stun_timer - delta)
		# 应用击退速度
		if knockback_velocity.length() > 0.1:
			position += knockback_velocity * delta
			# 击退速度衰减
			knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, delta * 8.0)
		# 僵直时不运行AI
		return
	# LOD系统：AI更新间隔控制
	if ai_update_interval > 0.0:
		ai_update_timer += delta
		if ai_update_timer >= ai_update_interval:
			ai_update_timer = 0.0
			_update_behavior(delta)
	else:
		_update_behavior(delta)
	_move(delta)


func set_ai_update_interval(interval: float) -> void:
	## LOD系统：设置AI更新间隔（0=每帧更新，0.2=每0.2秒更新一次）
	ai_update_interval = interval
	ai_update_timer = 0.0


func _update_behavior(delta: float) -> void:
	# 尸潮丧尸简化AI：直接追击最近玩家，不漫游，不检查建筑
	if is_horde_zombie:
		var horde_target: Node2D = _find_nearest_player(500.0)  # 扩大检测范围
		if horde_target:
			target = horde_target
			var dir := (horde_target.position - position).normalized()
			wander_direction = dir
			var atk_range: float = _type_config.get("attack_range", 45.0)
			if position.distance_to(horde_target.position) <= atk_range and attack_timer <= 0:
				_attack(horde_target)
		else:
			# 没有玩家时向地图中心移动
			wander_direction = (Vector2.ZERO - position).normalized()
		return
	
	var is_night := false
	var main: Node = get_tree().current_scene
	if main and main.has_method("get_time_of_day"):
		var t: float = main.get_time_of_day()
		is_night = t < 0.2 or t > 0.8
	var detect_range := NIGHT_DETECT_RANGE if is_night else DETECT_RANGE

	# 如果已有目标，检查是否超出范围
	if target and is_instance_valid(target):
		var dist_to_target: float = position.distance_to(target.position)
		if dist_to_target > detect_range:
			# 超出范围，开始计时
			lose_target_timer += delta
			if lose_target_timer >= LOSE_TARGET_TIME:
				# 放弃目标，恢复漫游
				target = null
				lose_target_timer = 0.0
				print("[Zombie] 失去目标，恢复漫游")
		else:
			# 在范围内，重置计时
			lose_target_timer = 0.0
	else:
		# 没有目标，在附近搜寻玩家
		target = _find_nearest_player(detect_range)
		lose_target_timer = 0.0

	if target:
		# 追击玩家
		var dir := (target.position - position).normalized()
		wander_direction = dir
		# 攻击玩家
		var atk_range: float = _type_config.get("attack_range", 45.0)
		if position.distance_to(target.position) <= atk_range and attack_timer <= 0:
			_attack(target)
	else:
		# 没有玩家目标，检查附近是否有建筑可以攻击
		var atk_range: float = _type_config.get("attack_range", 45.0)
		var nearby_building: Node2D = _find_nearest_building(atk_range * 1.5)
		if nearby_building:
			# 朝建筑移动并攻击
			var dir := (nearby_building.position - position).normalized()
			wander_direction = dir
			if position.distance_to(nearby_building.position) <= atk_range and attack_timer <= 0:
				_attack_building(nearby_building)
		else:
			# 漫游
			wander_timer -= delta
			if wander_timer <= 0:
				wander_timer = randf_range(1.0, 3.0)
				var angle := randf() * TAU
				wander_direction = Vector2(cos(angle), sin(angle))


func _move(delta: float) -> void:
	var attack_range: float = 45.0
	if _type_config.has("attack_range"):
		attack_range = _type_config.attack_range
	if target and position.distance_to(target.position) <= attack_range:
		velocity = Vector2.ZERO
	else:
		var speed: float = _type_config.run_speed if target else _type_config.speed
		velocity = wander_direction * speed
	move_and_slide()


func _attack(player_node: Node) -> void:
	attack_timer = ATTACK_COOLDOWN
	if player_node and player_node.has_method("take_damage"):
		player_node.take_damage(_type_config.damage)


func attract_to(pos: Vector2) -> void:
	# 被噪音吸引，朝噪音位置移动
	wander_direction = (pos - position).normalized()
	lose_target_timer = 0.0


func _find_nearest_building(range: float) -> Node2D:
	var nearest: Node2D = null
	var nearest_dist := range
	var buildings: Array = get_tree().get_nodes_in_group("building")
	for b: Node2D in buildings:
		if not is_instance_valid(b):
			continue
		if b.has_method("is_built") and not b.is_built:
			continue  # 不攻击建造中的建筑
		var d := position.distance_to(b.position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = b
	return nearest


func _attack_building(building_node: Node2D) -> void:
	attack_timer = ATTACK_COOLDOWN
	var dmg: float = _type_config.get("damage", 5.0)
	if building_node and building_node.has_method("take_damage"):
		building_node.take_damage(dmg)
		print("[Zombie] 攻击建筑 %s，造成 %d 伤害" % [building_node.building_id, dmg])


func _find_nearest_player(range: float) -> Node2D:
	var nearest: Node2D = null
	var nearest_dist := range
	for pid: int in GameManager.players.keys():
		var p: CharacterBody2D = GameManager.players[pid]
		if not is_instance_valid(p) or p.is_down:
			continue
		var d := position.distance_to(p.position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = p
	return nearest


func take_damage(amount: float, attacker: Node2D = null) -> void:
	if not GameManager.is_server:
		return
	health -= amount
	# 击退僵直效果（巨型丧尸和胖子丧尸击退较小）
	var knockback_resistance: float = _type_config.get("knockback_resistance", 1.0)
	var knockback_force: float = 120.0 * knockback_resistance
	var stun_duration: float = 0.25 * knockback_resistance
	# 计算击退方向（从攻击者指向丧尸）
	if attacker and is_instance_valid(attacker):
		var dir: Vector2 = (position - attacker.position).normalized()
		knockback_velocity = dir * knockback_force
		stun_timer = max(stun_timer, stun_duration)
	if health <= 0:
		_die()


func _die() -> void:
	# 胖子丧尸死亡爆炸
	if _type_config.has("explode_on_death") and _type_config.explode_on_death:
		_explode()
	# 掉落物品
	_drop_loot()
	# 给附近玩家经验值
	_give_experience()
	print("[Zombie] %s died at %s, recycled to pool" % [zombie_type, str(position)])
	# 从组中移除
	if is_in_group("zombie"):
		remove_from_group("zombie")
	# 归还到对象池，而不是销毁
	ObjectPool.recycle("zombie", self)


func _give_experience() -> void:
	# 不同丧尸给不同经验值
	var exp_map: Dictionary = {
		"normal": 10.0,
		"fast": 15.0,
		"fat": 25.0,
		"dog": 12.0,
		"giant": 100.0,
		"special": 50.0,
	}
	var exp_amount: float = exp_map.get(zombie_type, 10.0)
	const EXP_RANGE := 300.0  # 经验获取范围
	# 给范围内的玩家经验
	for pid: int in GameManager.players.keys():
		var player: Node = GameManager.players[pid]
		if player and is_instance_valid(player) and player.has_method("add_experience"):
			if position.distance_to(player.position) <= EXP_RANGE:
				player.add_experience(exp_amount)


func _explode() -> void:
	var explode_damage: float = _type_config.get("explode_damage", 20.0)
	var explode_radius: float = _type_config.get("explode_radius", 60.0)
	print("[Zombie] 胖子丧尸爆炸！半径%.0f，伤害%.0f" % [explode_radius, explode_damage])
	# 对范围内玩家造成伤害
	for pid: int in GameManager.players.keys():
		var p: CharacterBody2D = GameManager.players[pid]
		if is_instance_valid(p) and position.distance_to(p.position) <= explode_radius:
			if p.has_method("take_damage"):
				p.take_damage(explode_damage)
	# 对范围内建筑造成伤害
	var buildings: Array = get_tree().get_nodes_in_group("building")
	for b: Node2D in buildings:
		if is_instance_valid(b) and position.distance_to(b.position) <= explode_radius:
			if b.has_method("take_damage"):
				b.take_damage(explode_damage * 0.5)


func _drop_loot() -> void:
	# 简单掉落：随机掉落纤维/布料/废铁
	var world: Node = get_tree().current_scene
	if not world:
		return
	var player: Node = null
	# 找到最近的玩家，把掉落物给他（P0简化版）
	var nearest_dist: float = 200.0
	for pid: int in GameManager.players.keys():
		var p: CharacterBody2D = GameManager.players[pid]
		if is_instance_valid(p):
			var dist: float = position.distance_to(p.position)
			if dist < nearest_dist:
				nearest_dist = dist
				player = p
	if player and player.inventory:
		# 随机掉落1-2种物品
		var loot_table: Array = ["fiber", "cloth", "scrap"]
		var loot_count: int = randi_range(1, 2)
		for i in range(loot_count):
			var item_id: String = loot_table[randi() % loot_table.size()]
			var amount: int = randi_range(1, 3)
			player.inventory.add_item(item_id, amount)
			print("[Loot] 丧尸掉落 %dx %s" % [amount, item_id])
		# 5%概率掉落书籍
		if randf() < 0.05:
			var book_table: Array = ["medical_book", "farming_book", "cooking_book", "engineering_book", "combat_book", "mechanic_book", "building_book"]
			var book_id: String = book_table[randi() % book_table.size()]
			player.inventory.add_item(book_id, 1)
			print("[Loot] 丧尸掉落书籍：%s" % book_id)


static func _make_zombie_texture(zombie_type: String = "normal") -> Texture2D:
	var size := 48
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := size / 2.0
	# 根据丧尸类型设置颜色和大小
	var body_color := Color(0.35, 0.5, 0.3, 1)
	var head_color := Color(0.4, 0.55, 0.35, 1)
	var br := 16.0
	var hr := 10.0
	match zombie_type:
		"fast":
			body_color = Color(0.45, 0.3, 0.5, 1)
			head_color = Color(0.5, 0.35, 0.55, 1)
			br = 13.0
			hr = 8.0
		"fat":
			body_color = Color(0.5, 0.3, 0.2, 1)
			head_color = Color(0.55, 0.35, 0.25, 1)
			br = 20.0
			hr = 12.0
		"dog":
			body_color = Color(0.3, 0.25, 0.2, 1)
			head_color = Color(0.35, 0.3, 0.25, 1)
			br = 10.0
			hr = 7.0
		"giant":
			body_color = Color(0.4, 0.4, 0.45, 1)
			head_color = Color(0.45, 0.45, 0.5, 1)
			br = 22.0
			hr = 14.0
		"spitter":
			body_color = Color(0.25, 0.5, 0.3, 1)
			head_color = Color(0.3, 0.55, 0.35, 1)
			br = 17.0
			hr = 11.0
	# 身体
	for x in range(size):
		for y in range(size):
			var dx := x - center
			var dy := y - center + 2
			if dx * dx + dy * dy <= br * br:
				img.set_pixel(x, y, body_color)
	# 头
	for x in range(size):
		for y in range(size):
			var dx := x - center
			var dy := y - center + 10
			if dx * dx + dy * dy <= hr * hr:
				img.set_pixel(x, y, head_color)
	# 眼睛（红色）
	img.set_pixel(center - 3, center - 6, Color(1, 0.2, 0.2, 1))
	img.set_pixel(center + 3, center - 6, Color(1, 0.2, 0.2, 1))
	# 吐酸丧尸有绿色嘴部
	if zombie_type == "spitter":
		img.set_pixel(center, center - 3, Color(0.2, 0.8, 0.2, 1))
		img.set_pixel(center - 1, center - 3, Color(0.3, 0.9, 0.3, 1))
		img.set_pixel(center + 1, center - 3, Color(0.3, 0.9, 0.3, 1))
	return ImageTexture.create_from_image(img)
