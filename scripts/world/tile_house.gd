extends Node2D
## 双图层瓦片房屋系统
## 外表层（ExteriorLayer）：房屋外表瓦片，每个可独立拆除
## 内部地面层（InteriorLayer）：房屋内部地面，外表瓦片拆除后显示
## 支持按瓦片破坏、可进入、不可破坏模式

@export var building_name: String = "瓦片房屋"
@export var tile_health: float = 50.0  # 每个外表瓦片的生命值
@export var is_indestructible: bool = false  # 不可破坏模式（警局、军事基地等）
@export var show_roof_when_outside: bool = true  # 玩家在外面时是否显示屋顶

var tile_healths: Dictionary = {}  # Vector2i(瓦片坐标) -> 生命值
var is_inside: bool = false
var player_inside: Node = null

@onready var interior_layer: TileMapLayer = $InteriorLayer
@onready var exterior_layer: TileMapLayer = $ExteriorLayer
@onready var door_gap: Area2D = $Door_Gap
@onready var roof: Sprite2D = $Roof


func _ready() -> void:
	add_to_group("tile_house")
	add_to_group("building")
	# 初始化所有外表瓦片的生命值
	_init_tile_healths()
	# 连接门口检测
	if door_gap:
		door_gap.body_entered.connect(_on_door_body_entered)
		door_gap.body_exited.connect(_on_door_body_exited)


func _init_tile_healths() -> void:
	## 初始化所有外表瓦片的生命值
	if not exterior_layer:
		return
	var used_rect = exterior_layer.get_used_rect()
	for x in range(used_rect.position.x, used_rect.end.x):
		for y in range(used_rect.position.y, used_rect.end.y):
			var tile_pos = Vector2i(x, y)
			var tile_data = exterior_layer.get_cell_tile_data(tile_pos)
			if tile_data:
				tile_healths[tile_pos] = tile_health
	print("[TileHouse] ", building_name, " 初始化 ", tile_healths.size(), " 个外表瓦片")


func damage_tile_at_world_pos(world_pos: Vector2, amount: float) -> bool:
	## 对世界坐标处的外表瓦片造成伤害
	## 返回是否击中了瓦片
	if is_indestructible:
		return false  # 不可破坏模式
	if not exterior_layer:
		return false
	# 转换世界坐标为瓦片坐标
	var local_pos = exterior_layer.to_local(world_pos)
	var tile_pos = exterior_layer.local_to_map(local_pos)
	return damage_tile(tile_pos, amount)


func damage_tile(tile_pos: Vector2i, amount: float) -> bool:
	## 对指定瓦片坐标的外表瓦片造成伤害
	## 返回是否击中了瓦片
	if is_indestructible:
		return false
	if not tile_healths.has(tile_pos):
		return false
	var health = tile_healths[tile_pos] - amount
	tile_healths[tile_pos] = health
	print("[TileHouse] ", building_name, " 瓦片 ", tile_pos, " 受到 ", amount, " 伤害，剩余: ", health)
	if health <= 0:
		_destroy_tile(tile_pos)
	return true


func _destroy_tile(tile_pos: Vector2i) -> void:
	## 摧毁指定外表瓦片
	if not exterior_layer:
		return
	# 移除外表瓦片（关键！碰撞体自动消失，显示内部地面层）
	exterior_layer.erase_cell(tile_pos)
	# 从生命值字典中移除
	tile_healths.erase(tile_pos)
	# 播放破坏特效
	var world_pos = exterior_layer.map_to_local(tile_pos) + exterior_layer.position
	_play_destroy_effect(world_pos)
	print("[TileHouse] ", building_name, " 瓦片 ", tile_pos, " 被摧毁！显示内部地面")


func _play_destroy_effect(pos: Vector2) -> void:
	## 播放瓦片破坏特效（需要粒子系统支持）
	# 如果有 ParticleEffectManager，可以在这里调用
	pass


func get_tile_health_at_world_pos(world_pos: Vector2) -> float:
	## 获取世界坐标处外表瓦片的生命值
	if not exterior_layer:
		return 0.0
	var local_pos = exterior_layer.to_local(world_pos)
	var tile_pos = exterior_layer.local_to_map(local_pos)
	return tile_healths.get(tile_pos, 0.0)


func is_tile_destroyed_at_world_pos(world_pos: Vector2) -> bool:
	## 检查世界坐标处的外表瓦片是否已被摧毁
	return get_tile_health_at_world_pos(world_pos) <= 0


func repair_tile(tile_pos: Vector2i) -> void:
	## 修复指定瓦片（如果需要）
	if not exterior_layer:
		return
	# 重新放置瓦片（需要知道原来的瓦片ID，这里简化处理）
	# exterior_layer.set_cell(tile_pos, original_tile_id)
	tile_healths[tile_pos] = tile_health
	print("[TileHouse] ", building_name, " 瓦片 ", tile_pos, " 已修复")


func _on_door_body_entered(body: Node) -> void:
	## 玩家从门口进入
	if body.is_in_group("player"):
		player_inside = body
		is_inside = true
		_hide_roof()
		print("[TileHouse] 玩家进入 ", building_name)


func _on_door_body_exited(body: Node) -> void:
	## 玩家从门口离开
	if body.is_in_group("player") and body == player_inside:
		player_inside = null
		is_inside = false
		_show_roof()
		print("[TileHouse] 玩家离开 ", building_name)


func _hide_roof() -> void:
	## 隐藏屋顶
	if roof:
		roof.visible = false


func _show_roof() -> void:
	## 显示屋顶
	if not show_roof_when_outside:
		return
	if roof:
		roof.visible = true


func get_exterior_tile_count() -> int:
	## 获取当前外表瓦片数量
	return tile_healths.size()
