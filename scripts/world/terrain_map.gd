extends Node2D
## TileMap地形管理器 - 支持外部TileSet，完全手绘地形（使用Godot 4.7 TileMapLayer）

const TILE_SIZE := 64
const MAP_WIDTH := 400   # 瓦片数量
const MAP_HEIGHT := 300  # 瓦片数量

# 地形层
@onready var terrain_layer: TileMapLayer = $TerrainLayer
@onready var decoration_layer: TileMapLayer = $DecorationLayer

var _world_ready: bool = false


func _ready() -> void:
	# 检查是否已设置TileSet（在编辑器中手动设置）
	if terrain_layer.tile_set == null:
		print("[TerrainMap] 警告：TerrainLayer未设置TileSet，请在编辑器中导入瓦片素材并设置TileSet")
	else:
		print("[TerrainMap] TileMap地形系统初始化完成，使用外部TileSet")
	
	_world_ready = true


func is_ready() -> bool:
	return _world_ready


func get_tile_type_at_position(pos: Vector2) -> String:
	"""根据世界坐标获取瓦片源ID（用于地形查询）"""
	var tile_pos = terrain_layer.local_to_map(pos)
	var source_id = terrain_layer.get_cell_source_id(tile_pos)
	if source_id < 0:
		return "empty"
	return "tile_%d" % source_id


func get_tile_position(world_pos: Vector2) -> Vector2i:
	"""世界坐标转瓦片坐标"""
	return terrain_layer.local_to_map(world_pos)


func get_world_position(tile_pos: Vector2i) -> Vector2:
	"""瓦片坐标转世界坐标"""
	return terrain_layer.map_to_local(tile_pos)


func set_tile(tile_pos: Vector2i, source_id: int, atlas_coords: Vector2i = Vector2i.ZERO, layer: int = 0) -> void:
	"""设置指定位置的瓦片（运行时动态修改）"""
	var tilemap = terrain_layer if layer == 0 else decoration_layer
	tilemap.set_cell(tile_pos, source_id, atlas_coords)


func clear_tile(tile_pos: Vector2i, layer: int = 0) -> void:
	"""清除指定位置的瓦片"""
	var tilemap = terrain_layer if layer == 0 else decoration_layer
	tilemap.set_cell(tile_pos, -1)


func get_cell_source_id(tile_pos: Vector2i, layer: int = 0) -> int:
	"""获取指定位置的瓦片源ID"""
	var tilemap = terrain_layer if layer == 0 else decoration_layer
	return tilemap.get_cell_source_id(tile_pos)


func is_walkable(pos: Vector2) -> bool:
	"""检查位置是否可行走（基于TileSet碰撞配置）"""
	# 使用物理检测判断是否有碰撞
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = pos
	query.collide_with_bodies = true
	query.collision_mask = 1  # world层
	var results = space_state.intersect_point(query, 1)
	return results.is_empty()


func get_map_size() -> Vector2i:
	"""获取地图大小（瓦片数）"""
	return Vector2i(MAP_WIDTH, MAP_HEIGHT)


func get_map_size_pixels() -> Vector2:
	"""获取地图大小（像素）"""
	return Vector2(MAP_WIDTH * TILE_SIZE, MAP_HEIGHT * TILE_SIZE)


func get_map_center() -> Vector2:
	"""获取地图中心坐标"""
	return get_map_size_pixels() / 2.0


func clear_all(layer: int = -1) -> void:
	"""清除所有瓦片（layer=-1清除所有层）"""
	if layer == -1 or layer == 0:
		terrain_layer.clear()
	if layer == -1 or layer == 1:
		decoration_layer.clear()


func get_tile_set() -> TileSet:
	"""获取当前使用的TileSet"""
	return terrain_layer.tile_set


func set_tile_set(tileset: TileSet) -> void:
	"""设置TileSet（运行时切换）"""
	terrain_layer.tile_set = tileset
	decoration_layer.tile_set = tileset
