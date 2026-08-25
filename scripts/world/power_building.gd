extends Node2D
## 电力建筑：发电机、电灯、自动炮塔等
## 附加到电力建筑节点上使用

# 建筑类型
var power_building_type: String = ""  # small_generator / electric_light / auto_turret
var is_running: bool = false  # 发电机是否运行
var is_powered: bool = false  # 设备是否有电
var fuel: float = 0.0  # 燃料量
var max_fuel: float = 100.0  # 最大燃料
var attack_cooldown: float = 0.0  # 炮塔攻击冷却

@onready var sprite: Sprite2D = $Sprite
@onready var light_node: PointLight2D = null


func _ready() -> void:
	add_to_group("power_building")
	# 尝试获取灯光节点
	if has_node("PointLight2D"):
		light_node = $PointLight2D
	# 根据建筑类型初始化
	if power_building_type == "":
		# 从 building_id 推断（building.gd 里已声明此变量）
		if self.building_id != "":
			power_building_type = self.building_id
		else:
			power_building_type = "electric_light"
	# 注册到电力系统
	if PowerSystem:
		if power_building_type in ["small_generator", "medium_generator", "large_generator", "solar_panel"]:
			PowerSystem.register_generator(self)
		else:
			PowerSystem.register_device(self)
	_update_appearance()


func _process(delta: float) -> void:
	if power_building_type in ["small_generator", "medium_generator", "large_generator", "solar_panel"]:
		_update_generator(delta)
	elif power_building_type == "electric_light":
		_update_light(delta)
	elif power_building_type == "auto_turret":
		_update_turret(delta)
	elif power_building_type == "electric_furnace":
		_update_furnace(delta)
	elif power_building_type == "refrigerator":
		_update_fridge(delta)
	elif power_building_type == "electric_workbench":
		_update_workbench(delta)
	elif power_building_type == "electric_heater":
		_update_heater(delta)


func _update_generator(delta: float) -> void:
	# 太阳能板不需要燃料
	if power_building_type == "solar_panel":
		is_running = true
		return
	# 消耗燃料
	if is_running and fuel > 0:
		var config: Dictionary = PowerSystem.get_generator_info(power_building_type)
		var fuel_consumption: float = config.get("fuel_consumption", 0.5)
		fuel = max(0, fuel - fuel_consumption * delta)
		if fuel <= 0:
			is_running = false
			print("[Power] 发电机燃料耗尽")
	# 有燃料时自动启动
	if fuel > 0 and not is_running:
		is_running = true
		print("[Power] 发电机启动")
	_update_appearance()


func _update_light(delta: float) -> void:
	# 检查是否有电力
	var was_powered: bool = is_powered
	is_powered = PowerSystem.has_power_in_range(position) if PowerSystem else false
	if is_powered != was_powered:
		_update_appearance()


func _update_turret(delta: float) -> void:
	# 检查是否有电力
	is_powered = PowerSystem.has_power_in_range(position) if PowerSystem else false
	if not is_powered:
		return
	# 攻击冷却
	attack_cooldown = max(0, attack_cooldown - delta)
	if attack_cooldown > 0:
		return
	# 寻找附近的丧尸
	var config: Dictionary = PowerSystem.get_device_info("auto_turret")
	var range: float = config.get("range", 200.0)
	var damage: float = config.get("damage", 15.0)
	var fire_rate: float = config.get("fire_rate", 1.0)
	var world: Node = get_tree().current_scene
	if not world:
		return
	var world_layer: Node = world.get_node_or_null("WorldLayer")
	if not world_layer:
		return
	var nearest_zombie: Node = null
	var nearest_dist: float = range
	for child in world_layer.get_children():
		if child.is_in_group("zombie") or child.name.begins_with("Zombie"):
			var dist: float = position.distance_to(child.position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest_zombie = child
	if nearest_zombie and nearest_zombie.has_method("take_damage"):
		nearest_zombie.take_damage(damage)
		attack_cooldown = 1.0 / fire_rate
		# 播放攻击音效
		if AudioManager:
			AudioManager.play_sfx(AudioManager.SFX.ATTACK)
		# 产生噪音
		if has_method("emit_noise"):
			emit_noise(10.0)


func interact(player: Node) -> void:
	## 玩家交互：给发电机加燃料
	if power_building_type in ["small_generator", "medium_generator", "large_generator"]:
		# 检查玩家是否有汽油
		if player.inventory and player.inventory.has_item("gasoline", 1):
			player.inventory.remove_item("gasoline", 1)
			fuel = min(max_fuel, fuel + 50.0)
			is_running = true
			print("[Power] 添加燃料，当前燃料: %.0f" % fuel)
			if AudioManager:
				AudioManager.play_sfx(AudioManager.SFX.SUCCESS)
		else:
			print("[Power] 需要汽油才能给发电机加燃料")
			if AudioManager:
				AudioManager.play_sfx(AudioManager.SFX.ERROR)


func _update_appearance() -> void:
	## 更新外观
	if not sprite:
		return
	if power_building_type in ["small_generator", "medium_generator", "large_generator"]:
		# 发电机：运行时颜色变亮
		if is_running:
			sprite.modulate = Color(0.8, 0.8, 0.85)
		else:
			sprite.modulate = Color(0.5, 0.5, 0.55)
	elif power_building_type == "electric_light":
		# 电灯：有电时发光
		if is_powered:
			sprite.modulate = Color(1.0, 1.0, 0.9)
			if light_node:
				light_node.visible = true
				light_node.energy = 1.0
		else:
			sprite.modulate = Color(0.4, 0.4, 0.4)
			if light_node:
				light_node.visible = false
	elif power_building_type == "auto_turret":
		# 炮塔：有电时颜色变亮
		if is_powered:
			sprite.modulate = Color(0.6, 0.6, 0.7)
		else:
			sprite.modulate = Color(0.3, 0.3, 0.35)
	elif power_building_type == "electric_furnace":
		# 电炉：有电时发热发光
		if is_powered:
			sprite.modulate = Color(1.0, 0.6, 0.3)
		else:
			sprite.modulate = Color(0.4, 0.3, 0.25)
	elif power_building_type == "refrigerator":
		# 冰箱：有电时冷光
		if is_powered:
			sprite.modulate = Color(0.8, 0.95, 1.0)
		else:
			sprite.modulate = Color(0.4, 0.45, 0.5)
	elif power_building_type == "electric_workbench":
		# 电动工具台：有电时指示灯亮
		if is_powered:
			sprite.modulate = Color(0.7, 0.75, 0.8)
		else:
			sprite.modulate = Color(0.35, 0.35, 0.4)
	elif power_building_type == "electric_heater":
		# 电暖气：有电时发热红光
		if is_powered:
			sprite.modulate = Color(1.0, 0.5, 0.2)
		else:
			sprite.modulate = Color(0.4, 0.3, 0.25)


# ==================== 新电力设备更新函数 ====================
func _update_furnace(delta: float) -> void:
	## 电炉：有电时可以冶炼金属（简化为视觉效果）
	# 实际冶炼功能可以后续扩展
	pass


func _update_fridge(delta: float) -> void:
	## 冰箱：有电时减缓附近食物腐烂
	# 实际腐烂减缓功能可以后续扩展
	pass


func _update_workbench(delta: float) -> void:
	## 电动工具台：有电时加速制作50%
	# 实际加速功能可以后续扩展
	pass


func _update_heater(delta: float) -> void:
	## 电暖气：有电时增加附近玩家保暖度
	if not is_powered:
		return
	# 查找附近玩家，增加保暖度
	for pid: int in GameManager.players.keys():
		var p: Node2D = GameManager.players[pid]
		if is_instance_valid(p) and position.distance_to(p.position) < 120:
			if "warmth_level" in p:
				# 临时增加保暖度（每帧重置，实际应该用buff系统）
				# 简化处理：直接增加基础保暖度
				pass
