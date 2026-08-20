extends StaticBody2D
## 建筑组件：处理建筑的生命值、建造进度、升级等

@export var building_id: String = ""
var max_health: float = 100.0
var health: float = 100.0
var level: int = 1
var is_built: bool = false
var build_progress: float = 0.0  # 0.0 - 1.0
var build_time: float = 30.0
# 升级相关
var is_upgrading: bool = false
var upgrade_progress: float = 0.0
var upgrade_time: float = 60.0
var target_level: int = 2

# 动画相关
var anim_timer: float = 0.0
var flame_frame: int = 0
var base_scale: Vector2 = Vector2.ONE
var build_shake_timer: float = 0.0

@onready var sprite: Sprite2D = $Sprite
@onready var progress_bar: ProgressBar = $ProgressBar

static var _building_textures: Dictionary = {}


func _ready() -> void:
	if building_id != "":
		_setup_building()
	add_to_group("building")


func _setup_building() -> void:
	var data: Dictionary = BuildingDB.get_building(building_id)
	if data.is_empty():
		return
	max_health = data.max_health
	health = max_health
	build_time = data.build_time
	# 设置纹理
	if sprite:
		var tex: Texture2D = _get_building_texture(building_id)
		sprite.texture = tex
		sprite.modulate = Color.WHITE  # 图标已自带颜色，不额外染色
		base_scale = sprite.scale
	# 设置碰撞形状
	var collision: CollisionShape2D = get_node_or_null("CollisionShape2D")
	if collision:
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = BuildingDB.get_building_size(building_id)
		collision.shape = shape
	# 建造进度条
	if progress_bar:
		progress_bar.visible = not is_built
		progress_bar.max_value = 1.0
		progress_bar.value = build_progress


func _process(delta: float) -> void:
	if not is_built:
		build_progress = min(1.0, build_progress + delta / build_time)
		if progress_bar:
			progress_bar.value = build_progress
		# 建造中的轻微抖动
		if sprite:
			build_shake_timer += delta
			var shake: float = sin(build_shake_timer * 8) * 0.02
			sprite.position.x = shake * 10
		if build_progress >= 1.0:
			_finish_building()
		return

	# 建造完成后重置位置
	if sprite and sprite.position.x != 0:
		sprite.position.x = 0

	# 升级进度
	if is_upgrading:
		upgrade_progress = min(1.0, upgrade_progress + delta / upgrade_time)
		if progress_bar:
			progress_bar.value = upgrade_progress
		# 升级中的轻微抖动
		if sprite:
			build_shake_timer += delta
			var shake: float = sin(build_shake_timer * 6) * 0.015
			sprite.position.x = shake * 8
		if upgrade_progress >= 1.0:
			_finish_upgrade()
		return

	# 篝火/火把火焰动画
	if building_id == "campfire" or building_id == "torch":
		anim_timer += delta
		if anim_timer >= 0.15:
			anim_timer = 0
			flame_frame = (flame_frame + 1) % 3
			_update_flame_animation()
		# 火焰轻微闪烁
		var flicker: float = 0.9 + sin(anim_timer * 20) * 0.1
		if sprite:
			sprite.modulate.a = flicker


func _finish_building() -> void:
	is_built = true
	if progress_bar:
		progress_bar.visible = false
	if sprite:
		sprite.modulate = sprite.modulate.lightened(0.1)
		sprite.position.x = 0
	print("[Building] %s 建造完成" % BuildingDB.get_building_name(building_id))
	if building_id == "farm_plot":
		var farm_script: Script = load("res://scripts/world/farm_plot.gd")
		if farm_script:
			set_script(farm_script)
			# 调用农田的 _ready
			if has_method("_ready"):
				_ready()
	# 如果是电力建筑，附加电力建筑脚本
	elif building_id in ["small_generator", "electric_light", "auto_turret"]:
		var power_script: Script = load("res://scripts/world/power_building.gd")
		if power_script:
			set_script(power_script)
			# 设置建筑类型
			set("power_building_type", building_id)
			# 调用电力建筑的 _ready
			if has_method("_ready"):
				_ready()


func set_building_complete() -> void:
	## 公共方法：直接设置建筑为已完成状态（用于预生成建筑如实验室）
	if not is_built:
		_finish_building()


func _update_flame_animation() -> void:
	# 通过修改scale模拟火焰跳动
	if not sprite:
		return
	match flame_frame:
		0:
			sprite.scale = base_scale * Vector2(1.0, 1.0)
		1:
			sprite.scale = base_scale * Vector2(0.95, 1.1)
		2:
			sprite.scale = base_scale * Vector2(1.05, 0.95)


func take_damage(amount: float) -> void:
	if not is_built:
		return  # 建造中的建筑不会被攻击
	health = max(0, health - amount)
	if health <= 0:
		_on_destroyed()


func _on_destroyed() -> void:
	print("[Building] %s 被摧毁" % BuildingDB.get_building_name(building_id))
	queue_free()


func get_building_id() -> String:
	return building_id


func is_fully_built() -> bool:
	return is_built


func start_upgrade(player: Node) -> bool:
	# 检查是否可以升级
	if not is_built or is_upgrading:
		return false
	if not BuildingDB.can_upgrade(building_id, level):
		return false
	# 检查是否是工匠职业（工匠可以升级，其他人需要学习技能）
	if player and player.player_class != "builder":
		if not (player.has_method("has_tech") and player.has_tech("advanced_building")):
			print("[Building] 只有工匠或学习高级建筑技能的人才能升级")
			return false
	# 检查材料
	var inv: Node = player.inventory if player and "inventory" in player else null
	if not inv:
		return false
	if not BuildingDB.can_afford_upgrade(building_id, level + 1, inv):
		print("[Building] 材料不足，无法升级")
		return false
	# 消耗材料
	var cost: Dictionary = BuildingDB.get_upgrade_cost(building_id, level + 1)
	for mat_id in cost.keys():
		inv.remove_item(mat_id, cost[mat_id])
	# 开始升级
	target_level = level + 1
	upgrade_time = BuildingDB.get_upgrade_time(building_id, target_level)
	# 工匠升级时间减半
	if player and player.player_class == "builder":
		upgrade_time *= 0.5
	upgrade_progress = 0.0
	is_upgrading = true
	if progress_bar:
		progress_bar.visible = true
		progress_bar.max_value = 1.0
		progress_bar.value = 0.0
	print("[Building] %s 开始升级到 %d 级，需要 %.0f 秒" % [BuildingDB.get_building_name(building_id), target_level, upgrade_time])
	return true


func _finish_upgrade() -> void:
	is_upgrading = false
	level = target_level
	# 更新建筑属性
	var stats: Dictionary = BuildingDB.get_building_stats(building_id, level)
	if stats.has("max_health"):
		max_health = stats.max_health
		health = max_health
	# 更新外观
	if sprite and stats.has("color"):
		sprite.modulate = stats.color
	if progress_bar:
		progress_bar.visible = false
	print("[Building] %s 升级到 %d 级完成" % [BuildingDB.get_building_name(building_id), level])


func demolish(player: Node) -> bool:
	## 拆除建筑，返还部分材料
	if not is_built:
		return false
	# 返还50%材料
	var cost: Dictionary = BuildingDB.get_building_cost(building_id)
	if player and player.inventory:
		for mat_id in cost.keys():
			var refund: int = int(cost[mat_id] * 0.5)
			if refund > 0:
				player.inventory.add_item(mat_id, refund)
	print("[Building] %s 被拆除，返还50%%材料" % BuildingDB.get_building_name(building_id))
	queue_free()
	return true


func get_health_percent() -> float:
	if max_health <= 0:
		return 0.0
	return health / max_health


static func _get_building_texture(building_id: String) -> Texture2D:
	if _building_textures.has(building_id):
		return _building_textures[building_id]
	var size: Vector2 = BuildingDB.get_building_size(building_id)
	var w: int = int(size.x)
	var h: int = int(size.y)
	# 使用建筑图标并缩放到建筑大小
	var icon: Texture2D = ArtAssets.get_building_icon(building_id)
	if icon:
		var icon_img: Image = icon.get_image()
		if icon_img:
			icon_img.resize(w, h, Image.INTERPOLATE_NEAREST)
			var tex: Texture2D = ImageTexture.create_from_image(icon_img)
			_building_textures[building_id] = tex
			return tex
	# 回退：带边框的矩形
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	for x in range(w):
		for y in range(h):
			if x < 2 or x >= w - 2 or y < 2 or y >= h - 2:
				img.set_pixel(x, y, Color(0.3, 0.3, 0.3, 1))
			else:
				img.set_pixel(x, y, Color(1, 1, 1, 1))
	var tex: Texture2D = ImageTexture.create_from_image(img)
	_building_textures[building_id] = tex
	return tex
