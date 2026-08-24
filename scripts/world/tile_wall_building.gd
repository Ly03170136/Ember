extends Node2D
## 瓦片化墙壁建筑系统
## 墙壁由TileMap组成，每个瓦片可独立被破坏
## 破坏瓦片后，碰撞体自动消失，玩家可以从缺口进入

@export var building_name: String = "瓦片墙壁建筑"
@export var tile_health: float = 50.0  # 每个瓦片的生命值
@export var wall_tile_id: int = 0  # 墙壁瓦片在TileSet中的ID
@export var show_roof_when_outside: bool = true
@export var is_indestructible: bool = false  # 不可破坏模式（用于警局、军事基地等）

var wall_healths: Dictionary = {}  # Vector2i(瓦片坐标) -> 生命值
var is_inside: bool = false
var player_inside: Node = null

@onready var walls_tilemap: TileMapLayer = $Walls
@onready var door_gap: Area2D = $Door_Gap
@onready var roof: Sprite2D = $Roof


func _ready() -> void:
	add_to_group("tile_wall_building")
	# 初始化所有墙壁瓦片的生命值
	_init_wall_healths()
	# 连接门口检测
	if door_gap:
		door_gap.body_entered.connect(_on_door_body_entered)
		door_gap.body_exited.connect(_on_door_body_exited)


func _init_wall_healths() -> void:
	## 初始化所有墙壁瓦片的生命值
	if not walls_tilemap:
		return
	var used_rect = walls_tilemap.get_used_rect()
	for x in range(used_rect.position.x, used_rect.end.x):
		for y in range(used_rect.position.y, used_rect.end.y):
			var tile_pos = Vector2i(x, y)
			var tile_data = walls_tilemap.get_cell_tile_data(tile_pos)
			if tile_data:
				wall_healths[tile_pos] = tile_health
	print("[TileWallBuilding] 初始化 ", wall_healths.size(), " 个墙壁瓦片")


func damage_wall_at_world_pos(world_pos: Vector2, amount: float) -> bool:
	## 对世界坐标处的墙壁瓦片造成伤害
	## 返回是否击中了墙壁
	if not walls_tilemap:
		return false
	# 转换世界坐标为瓦片坐标
	var tile_pos = walls_tilemap.local_to_map(walls_tilemap.to_local(world_pos))
	return damage_wall_tile(tile_pos, amount)


func damage_wall_tile(tile_pos: Vector2i, amount: float) -> bool:
	## 对指定瓦片坐标的墙壁造成伤害
	## 返回是否击中了墙壁
	if is_indestructible:
		return false  # 不可破坏模式，直接返回
	if not wall_healths.has(tile_pos):
		return false
	var health = wall_healths[tile_pos] - amount
	wall_healths[tile_pos] = health
	print("[TileWallBuilding] 瓦片 ", tile_pos, " 受到 ", amount, " 伤害，剩余: ", health)
	if health <= 0:
		_destroy_wall_tile(tile_pos)
	return true


func _destroy_wall_tile(tile_pos: Vector2i) -> void:
	## 摧毁指定瓦片
	if not walls_tilemap:
		return
	# 移除瓦片（关键！碰撞体自动消失）
	walls_tilemap.erase_cell(tile_pos)
	# 从生命值字典中移除
	wall_healths.erase(tile_pos)
	# 播放破坏特效
	var world_pos = walls_tilemap.map_to_local(tile_pos) + walls_tilemap.position
	_play_wall_destroy_effect(world_pos)
	print("[TileWallBuilding] 瓦片 ", tile_pos, " 被摧毁！可以从缺口进入")


func _play_wall_destroy_effect(pos: Vector2) -> void:
	## 播放墙壁破坏特效（需要粒子系统支持）
	# 如果有 ParticleEffectManager，可以在这里调用
	pass


func get_wall_health_at_world_pos(world_pos: Vector2) -> float:
	## 获取世界坐标处墙壁瓦片的生命值
	if not walls_tilemap:
		return 0.0
	var tile_pos = walls_tilemap.local_to_map(walls_tilemap.to_local(world_pos))
	return wall_healths.get(tile_pos, 0.0)


func is_wall_destroyed_at_world_pos(world_pos: Vector2) -> bool:
	## 检查世界坐标处的墙壁是否已被摧毁
	return get_wall_health_at_world_pos(world_pos) <= 0


func repair_wall_tile(tile_pos: Vector2i) -> void:
	## 修复指定瓦片（如果需要）
	if not walls_tilemap:
		return
	# 重新放置瓦片
	walls_tilemap.set_cell(tile_pos, wall_tile_id)
	wall_healths[tile_pos] = tile_health
	print("[TileWallBuilding] 瓦片 ", tile_pos, " 已修复")


func _on_door_body_entered(body: Node) -> void:
	## 玩家从门口进入
	if body.is_in_group("player"):
		player_inside = body
		is_inside = true
		_hide_roof()
		print("[TileWallBuilding] 玩家进入 ", building_name)


func _on_door_body_exited(body: Node) -> void:
	## 玩家从门口离开
	if body.is_in_group("player") and body == player_inside:
		player_inside = null
		is_inside = false
		_show_roof()
		print("[TileWallBuilding] 玩家离开 ", building_name)


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


func get_wall_tile_count() -> int:
	## 获取当前墙壁瓦片数量
	return wall_healths.size()
