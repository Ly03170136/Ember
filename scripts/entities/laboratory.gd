extends Node2D
## 实验室建筑：全图唯一，病毒发源地
## 玩家按F进入实验室副本，摧毁病毒发生器通关游戏

@export var lab_name: String = "秘密实验室"
var is_entered: bool = false
var _entered: bool = false
var _sprite: Sprite2D = null
var _interact_area: Area2D = null
var _prompt_label: Label = null
var _player_nearby: bool = false

# 实验室僵尸刷新
var zombie_spawn_timer: float = 0.0
const ZOMBIE_SPAWN_INTERVAL := 15.0
const MAX_ZOMBIES_NEAR_LAB := 20
var _zombies_spawned: int = 0

static var _lab_texture: Texture2D = null


func _ready() -> void:
	add_to_group("laboratory")
	add_to_group("building")
	# 创建精灵
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite"
	if not _lab_texture:
		_lab_texture = _make_lab_texture()
	_sprite.texture = _lab_texture
	_sprite.scale = Vector2(1.5, 1.5)
	add_child(_sprite)
	# 创建交互区域
	_interact_area = Area2D.new()
	_interact_area.name = "InteractArea"
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(120, 120)
	collision.shape = shape
	_interact_area.add_child(collision)
	_interact_area.body_entered.connect(_on_body_entered)
	_interact_area.body_exited.connect(_on_body_exited)
	add_child(_interact_area)
	# 提示文字
	_prompt_label = Label.new()
	_prompt_label.name = "Prompt"
	_prompt_label.text = ""
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	_prompt_label.add_theme_font_size_override("font_size", 14)
	_prompt_label.position = Vector2(-60, -100)
	add_child(_prompt_label)
	print("[Lab] 实验室已生成: %s, 位置: %s" % [lab_name, str(position)])


func _process(delta: float) -> void:
	# 更新提示
	if _player_nearby and not _entered:
		_prompt_label.text = "[F] 进入 %s" % lab_name
	else:
		_prompt_label.text = ""
	# 僵尸刷新（全图感染后）
	if GameManager.infection_complete:
		zombie_spawn_timer -= delta
		if zombie_spawn_timer <= 0:
			zombie_spawn_timer = ZOMBIE_SPAWN_INTERVAL
			_spawn_zombie()


func _spawn_zombie() -> void:
	# 统计附近僵尸数量
	var nearby_zombies: int = 0
	var world: Node = get_tree().current_scene
	if world and world.has_node("WorldLayer"):
		var world_layer: Node = world.get_node("WorldLayer")
		for child in world_layer.get_children():
			if child.is_in_group("zombie"):
				if position.distance_to(child.position) < 400:
					nearby_zombies += 1
	if nearby_zombies >= MAX_ZOMBIES_NEAR_LAB:
		return
	# 生成僵尸
	var zombie_scene: PackedScene = load("res://scenes/entities/zombie.tscn")
	if zombie_scene:
		var zombie: Node2D = zombie_scene.instantiate()
		var angle: float = randf() * PI * 2
		var dist: float = randf_range(80, 150)
		zombie.position = position + Vector2(cos(angle), sin(angle)) * dist
		zombie.name = "LabZombie_%d" % randi()
		get_parent().add_child(zombie)
		zombie.add_to_group("zombie")
		_zombies_spawned += 1
		print("[Lab] 实验室刷新僵尸 #%d, 附近已有%d只" % [_zombies_spawned, nearby_zombies])


func try_enter(player: Node2D) -> void:
	## 玩家尝试进入实验室
	if _entered:
		return
	_entered = true
	print("[Lab] 玩家进入实验室副本")
	# 切换到副本场景
	var main: Node = get_tree().current_scene
	if main and main.has_method("enter_lab_dungeon"):
		main.enter_lab_dungeon(self)
	else:
		# 直接切换场景
		get_tree().change_scene_to_file("res://scenes/world/lab_dungeon.tscn")


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_nearby = true


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_nearby = false


static func _make_lab_texture() -> Texture2D:
	## 程序生成实验室外观（等距视角）
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := size / 2.0

	# 建筑阴影
	img.fill_rect(Rect2(center - 45, center + 5, 90, 25), Color(0, 0, 0, 0.3))

	# 建筑主体（等距菱形底座）
	var base_color := Color(0.35, 0.38, 0.42, 1)
	_draw_isometric_diamond(img, center, center + 10, 50, 20, base_color)

	# 建筑墙体
	var wall_color := Color(0.4, 0.43, 0.48, 1)
	img.fill_rect(Rect2(center - 40, center - 25, 80, 35), wall_color)

	# 屋顶
	var roof_color := Color(0.25, 0.28, 0.32, 1)
	_draw_isometric_diamond(img, center, center - 25, 45, 15, roof_color)

	# 窗户（发光的绿色，表示病毒）
	var window_color := Color(0.3, 0.8, 0.4, 0.8)
	img.fill_rect(Rect2(center - 30, center - 15, 12, 10), window_color)
	img.fill_rect(Rect2(center + 18, center - 15, 12, 10), window_color)
	img.fill_rect(Rect2(center - 6, center - 15, 12, 10), window_color)

	# 门
	var door_color := Color(0.2, 0.22, 0.25, 1)
	img.fill_rect(Rect2(center - 8, center + 2, 16, 13), door_color)
	# 门把手
	img.fill_rect(Rect2(center + 4, center + 8, 2, 2), Color(0.8, 0.7, 0.3))

	# 生物危害标志（屋顶上）
	var bio_color := Color(0.9, 0.7, 0.2, 1)
	img.fill_circle(Vector2(center, center - 28), 6, bio_color)
	img.fill_circle(Vector2(center, center - 28), 3, roof_color)

	# 围栏
	var fence_color := Color(0.3, 0.32, 0.35, 1)
	for i in range(-5, 6):
		var x: float = center + i * 9
		img.fill_rect(Rect2(x - 1, center + 18, 2, 8), fence_color)
	img.fill_rect(Rect2(center - 48, center + 20, 96, 2), fence_color)

	# 破损效果（随机黑点）
	var rng := RandomNumberGenerator.new()
	rng.seed = 99999
	for i in range(15):
		var x: int = rng.randi_range(center - 38, center + 38)
		var y: int = rng.randi_range(center - 23, center + 8)
		img.fill_rect(Rect2(x, y, 2, 2), Color(0.15, 0.15, 0.18, 0.8))

	var tex := ImageTexture.create_from_image(img)
	return tex


static func _draw_isometric_diamond(img: Image, cx: float, cy: float, w: float, h: float, color: Color) -> void:
	## 绘制等距菱形
	for y in range(-int(h), int(h) + 1):
		var ratio: float = 1.0 - abs(float(y)) / h
		var line_w: int = int(w * ratio)
		img.fill_rect(Rect2(cx - line_w / 2, cy + y, line_w, 1), color)
