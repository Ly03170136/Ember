extends Node2D
## 实验室副本：高难度地下城
## 目标：找到并摧毁病毒发生器，通关游戏

@onready var dungeon_layer: Node2D = $DungeonLayer
@onready var enemy_layer: Node2D = $EnemyLayer
@onready var exit_area: Area2D = $ExitArea
@onready var camera: Camera2D = $Camera2D

var virus_generator: Node2D = null

var _generator_health: float = 500.0
var _generator_max_health: float = 500.0
var _is_completed: bool = false
var _player: Node2D = null
var _spawn_timer: float = 0.0
const ENEMY_SPAWN_INTERVAL := 8.0
const MAX_ENEMIES := 30

# 副本房间配置
const ROOMS := [
	{"name": "入口大厅", "pos": Vector2(0, 0), "size": Vector2(400, 300)},
	{"name": "走廊A", "pos": Vector2(450, 50), "size": Vector2(200, 200)},
	{"name": "实验室A", "pos": Vector2(700, -100), "size": Vector2(350, 300)},
	{"name": "走廊B", "pos": Vector2(450, -250), "size": Vector2(200, 200)},
	{"name": "病毒培养室", "pos": Vector2(150, -350), "size": Vector2(350, 250)},
	{"name": "核心控制室", "pos": Vector2(-250, -200), "size": Vector2(400, 350)},
]


func _ready() -> void:
	print("[LabDungeon] 实验室副本加载中...")
	# 设置相机为当前相机
	if camera:
		camera.make_current()
		camera.position = Vector2(0, 0)
	# 生成副本地图
	_generate_dungeon()
	# 生成病毒发生器
	_spawn_virus_generator()
	# 生成出口
	_spawn_exit()
	# 初始敌人
	for i in range(10):
		_spawn_enemy()
	print("[LabDungeon] 实验室副本加载完成！目标：摧毁病毒发生器")
	# 显示提示
	_show_notification("实验室副本 - 找到并摧毁病毒发生器！", 4.0)


func _process(delta: float) -> void:
	if _is_completed:
		return
	# 敌人刷新
	_spawn_timer -= delta
	if _spawn_timer <= 0:
		_spawn_timer = ENEMY_SPAWN_INTERVAL
		var enemy_count: int = enemy_layer.get_child_count()
		if enemy_count < MAX_ENEMIES:
			_spawn_enemy()
	# 检查病毒发生器
	if virus_generator and virus_generator.has_method("get_health"):
		_generator_health = virus_generator.get_health()
		if _generator_health <= 0:
			_complete_dungeon()


func _generate_dungeon() -> void:
	## 生成副本地图（地面+墙壁）
	for room in ROOMS:
		var room_pos: Vector2 = room["pos"]
		var room_size: Vector2 = room["size"]
		# 地面
		var floor := ColorRect.new()
		floor.position = room_pos - room_size / 2
		floor.size = room_size
		floor.color = Color(0.25, 0.27, 0.3, 1)
		dungeon_layer.add_child(floor)
		# 房间名称
		var label := Label.new()
		label.text = room["name"]
		label.position = room_pos - Vector2(40, room_size.y / 2 + 20)
		label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
		label.add_theme_font_size_override("font_size", 12)
		dungeon_layer.add_child(label)
		# 墙壁（四周）
		var wall_color := Color(0.15, 0.17, 0.2, 1)
		var wall_thickness := 8.0
		# 上墙
		var top_wall := ColorRect.new()
		top_wall.position = room_pos - Vector2(room_size.x / 2, room_size.y / 2)
		top_wall.size = Vector2(room_size.x, wall_thickness)
		top_wall.color = wall_color
		dungeon_layer.add_child(top_wall)
		# 下墙
		var bottom_wall := ColorRect.new()
		bottom_wall.position = room_pos + Vector2(-room_size.x / 2, room_size.y / 2 - wall_thickness)
		bottom_wall.size = Vector2(room_size.x, wall_thickness)
		bottom_wall.color = wall_color
		dungeon_layer.add_child(bottom_wall)
		# 左墙
		var left_wall := ColorRect.new()
		left_wall.position = room_pos - Vector2(room_size.x / 2, room_size.y / 2)
		left_wall.size = Vector2(wall_thickness, room_size.y)
		left_wall.color = wall_color
		dungeon_layer.add_child(left_wall)
		# 右墙
		var right_wall := ColorRect.new()
		right_wall.position = room_pos + Vector2(room_size.x / 2 - wall_thickness, -room_size.y / 2)
		right_wall.size = Vector2(wall_thickness, room_size.y)
		right_wall.color = wall_color
		dungeon_layer.add_child(right_wall)
	# 连接走廊（简化处理）
	# 走廊A连接入口大厅和实验室A
	var corridor1 := ColorRect.new()
	corridor1.position = Vector2(200, -50)
	corridor1.size = Vector2(250, 100)
	corridor1.color = Color(0.25, 0.27, 0.3, 1)
	dungeon_layer.add_child(corridor1)
	# 走廊B连接实验室A和病毒培养室
	var corridor2 := ColorRect.new()
	corridor2.position = Vector2(350, -200)
	corridor2.size = Vector2(350, 100)
	corridor2.color = Color(0.25, 0.27, 0.3, 1)
	dungeon_layer.add_child(corridor2)
	# 连接病毒培养室和核心控制室
	var corridor3 := ColorRect.new()
	corridor3.position = Vector2(-100, -250)
	corridor3.size = Vector2(250, 100)
	corridor3.color = Color(0.25, 0.27, 0.3, 1)
	dungeon_layer.add_child(corridor3)


func _spawn_virus_generator() -> void:
	## 生成病毒发生器（最终目标）
	var generator_pos: Vector2 = Vector2(-250, -200)  # 核心控制室
	var generator := Node2D.new()
	generator.name = "VirusGenerator"
	generator.position = generator_pos
	# 精灵
	var sprite := Sprite2D.new()
	sprite.texture = _make_generator_texture()
	sprite.scale = Vector2(2.0, 2.0)
	generator.add_child(sprite)
	# 碰撞体
	var area := Area2D.new()
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 50
	collision.shape = shape
	area.add_child(collision)
	generator.add_child(area)
	# 血量标签
	var health_label := Label.new()
	health_label.name = "HealthLabel"
	health_label.text = "病毒发生器: 500/500"
	health_label.position = Vector2(-60, -70)
	health_label.add_theme_color_override("font_color", Color(0.3, 1, 0.4))
	health_label.add_theme_font_size_override("font_size", 14)
	generator.add_child(health_label)
	# 先添加到场景树，再设置脚本（确保_ready时子节点已存在）
	add_child(generator)
	# 加载并设置脚本
	var generator_script: GDScript = load("res://scripts/entities/virus_generator.gd")
	if generator_script:
		generator.set_script(generator_script)
		# 设置血量
		generator.set("health", _generator_health)
		generator.set("max_health", _generator_max_health)
	else:
		print("[LabDungeon] 警告：无法加载virus_generator.gd")
	virus_generator = generator


func _make_generator_texture() -> Texture2D:
	## 生成病毒发生器纹理
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := size / 2.0
	# 底座
	img.fill_rect(Rect2(center - 20, center + 5, 40, 15), Color(0.3, 0.32, 0.35))
	# 主体（圆柱）
	img.fill_rect(Rect2(center - 15, center - 20, 30, 30), Color(0.4, 0.45, 0.5))
	# 病毒核心（发光绿色）
	img.fill_circle(Vector2(center, center - 5), 10, Color(0.3, 1, 0.4, 0.9))
	img.fill_circle(Vector2(center, center - 5), 5, Color(0.6, 1, 0.7))
	# 管道
	img.fill_rect(Rect2(center - 25, center - 10, 8, 4), Color(0.35, 0.38, 0.42))
	img.fill_rect(Rect2(center + 17, center - 10, 8, 4), Color(0.35, 0.38, 0.42))
	# 警告灯
	img.fill_circle(Vector2(center - 10, center - 22), 3, Color(1, 0.3, 0.3))
	img.fill_circle(Vector2(center + 10, center - 22), 3, Color(1, 0.8, 0.2))
	var tex := ImageTexture.create_from_image(img)
	return tex


func _spawn_exit() -> void:
	## 生成出口（返回大地图）
	var exit_pos: Vector2 = Vector2(0, 100)  # 入口大厅
	exit_area.position = exit_pos
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(80, 80)
	collision.shape = shape
	exit_area.add_child(collision)
	exit_area.body_entered.connect(_on_exit_entered)
	# 出口标识
	var label := Label.new()
	label.text = "[出口] 返回大地图"
	label.position = exit_pos - Vector2(50, 50)
	label.add_theme_color_override("font_color", Color(0.5, 0.8, 1))
	label.add_theme_font_size_override("font_size", 14)
	add_child(label)


func _spawn_enemy() -> void:
	## 生成敌人（丧尸+特殊变异体）使用对象池
	var zombie = ObjectPool.acquire("zombie")
	if not zombie:
		return
	# 随机位置（在副本内）
	var room_idx: int = randi_range(0, ROOMS.size() - 1)
	var room: Dictionary = ROOMS[room_idx]
	var room_pos: Vector2 = room["pos"]
	var room_size: Vector2 = room["size"]
	zombie.position = room_pos + Vector2(
		randf_range(-room_size.x / 2 + 30, room_size.x / 2 - 30),
		randf_range(-room_size.y / 2 + 30, room_size.y / 2 - 30)
	)
	zombie.name = "DungeonZombie_%d" % randi()
	# 20%概率生成特殊变异体
	if randf() < 0.2:
		zombie.set("zombie_type", "special")
		zombie.set("max_health", 150.0)
		zombie.set("health", 150.0)
	enemy_layer.add_child(zombie)
	zombie.add_to_group("zombie")


func _on_exit_entered(body: Node) -> void:
	if body.is_in_group("player"):
		if _is_completed:
			# 已通关，返回大地图
			_return_to_world()
		else:
			_show_notification("必须先摧毁病毒发生器才能离开！", 2.0)


func _on_generator_destroyed() -> void:
	## 病毒发生器被摧毁（由virus_generator.gd调用）
	_complete_dungeon()


func _complete_dungeon() -> void:
	## 通关副本
	_is_completed = true
	print("[LabDungeon] ===== 病毒发生器已摧毁！游戏通关！ =====")
	_show_notification("病毒发生器已摧毁！游戏通关！", 5.0)
	# 清除所有敌人
	for child in enemy_layer.get_children():
		child.queue_free()
	# 通知GameManager
	if GameManager:
		GameManager.game_completed = true
	# 3秒后返回主菜单
	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _return_to_world() -> void:
	## 返回大地图
	print("[LabDungeon] 返回大地图")
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _show_notification(text: String, duration: float) -> void:
	## 显示通知
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	label.add_theme_font_size_override("font_size", 20)
	label.position = Vector2(0, -200)
	add_child(label)
	await get_tree().create_timer(duration).timeout
	label.queue_free()
