extends Node2D
## 可破坏围墙系统
## 只有一层围墙瓦片，每个瓦片可独立拆除
## 支持按瓦片破坏、不可破坏模式

@export var wall_name: String = "围墙"
@export var tile_health: float = 50.0  # 每个围墙瓦片的生命值
@export var is_indestructible: bool = false  # 不可破坏模式（军事基地等）

var tile_healths: Dictionary = {}  # Vector2i(瓦片坐标) -> 生命值

@onready var wall_layer: TileMapLayer = $WallLayer


func _ready() -> void:
	add_to_group("wall")
	add_to_group("building")
	_init_tile_healths()


func _init_tile_healths() -> void:
	## 初始化所有围墙瓦片的生命值
	if not wall_layer:
		return
	var used_rect = wall_layer.get_used_rect()
	for x in range(used_rect.position.x, used_rect.end.x):
		for y in range(used_rect.position.y, used_rect.end.y):
			var tile_pos = Vector2i(x, y)
			var tile_data = wall_layer.get_cell_tile_data(tile_pos)
			if tile_data:
				tile_healths[tile_pos] = tile_health
	print("[TileWall] ", wall_name, " 初始化 ", tile_healths.size(), " 个围墙瓦片")


func damage_tile_at_world_pos(world_pos: Vector2, amount: float) -> bool:
	## 对世界坐标处的围墙瓦片造成伤害
	## 返回是否击中了瓦片
	if is_indestructible:
		return false
	if not wall_layer:
		return false
	var local_pos = wall_layer.to_local(world_pos)
	var tile_pos = wall_layer.local_to_map(local_pos)
	return damage_tile(tile_pos, amount)


func damage_tile(tile_pos: Vector2i, amount: float) -> bool:
	## 对指定瓦片坐标的围墙瓦片造成伤害
	## 返回是否击中了瓦片
	if is_indestructible:
		return false
	if not tile_healths.has(tile_pos):
		return false
	var health = tile_healths[tile_pos] - amount
	tile_healths[tile_pos] = health
	print("[TileWall] ", wall_name, " 瓦片 ", tile_pos, " 受到 ", amount, " 伤害，剩余: ", health)
	if health <= 0:
		_destroy_tile(tile_pos)
	return true


func _destroy_tile(tile_pos: Vector2i) -> void:
	## 摧毁指定围墙瓦片
	if not wall_layer:
		return
	wall_layer.erase_cell(tile_pos)
	tile_healths.erase(tile_pos)
	var world_pos = wall_layer.map_to_local(tile_pos) + wall_layer.position
	_play_destroy_effect(world_pos)
	print("[TileWall] ", wall_name, " 瓦片 ", tile_pos, " 被摧毁！")


func _play_destroy_effect(pos: Vector2) -> void:
	## 播放瓦片破坏特效（需要粒子系统支持）
	pass


func get_tile_health_at_world_pos(world_pos: Vector2) -> float:
	## 获取世界坐标处围墙瓦片的生命值
	if not wall_layer:
		return 0.0
	var local_pos = wall_layer.to_local(world_pos)
	var tile_pos = wall_layer.local_to_map(local_pos)
	return tile_healths.get(tile_pos, 0.0)


func is_tile_destroyed_at_world_pos(world_pos: Vector2) -> bool:
	## 检查世界坐标处的围墙瓦片是否已被摧毁
	return get_tile_health_at_world_pos(world_pos) <= 0


func repair_tile(tile_pos: Vector2i) -> void:
	## 修复指定瓦片（如果需要）
	if not wall_layer:
		return
	tile_healths[tile_pos] = tile_health
	print("[TileWall] ", wall_name, " 瓦片 ", tile_pos, " 已修复")


func get_wall_tile_count() -> int:
	## 获取当前围墙瓦片数量
	return tile_healths.size()
