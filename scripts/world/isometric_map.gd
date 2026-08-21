extends Node2D
## 顶斜45度视角地图生成器（僵尸毁灭工程风格）
## 64x64正方形瓦片，长方形地图，合并大纹理渲染，高性能

const TILE_WIDTH := 64
const TILE_HEIGHT := 64  # 正方形瓦片，顶视角
const MAP_WIDTH := 400   # 地图宽度（瓦片数）
const MAP_HEIGHT := 300  # 地图高度（瓦片数），长方形

@onready var map_container: Node2D = $MapContainer

var _world_ready: bool = false
var _terrain_textures: Dictionary = {}  # 地形类型 -> Texture2D
var _tile_data: Array = []  # 存储每个瓦片的地形类型
var _full_map_mode: bool = false  # 是否使用完整大图模式
var _full_map_size: Vector2 = Vector2.ZERO  # 大图尺寸


func _ready() -> void:
	# 安全获取map_container
	if map_container == null:
		map_container = get_node_or_null("MapContainer") as Node2D
	if map_container == null:
		map_container = Node2D.new()
		map_container.name = "MapContainer"
		add_child(map_container)
	
	# 优先使用完整大图模式
	var bg_path := "res://assets/terrain/map_background.png"
	if ResourceLoader.exists(bg_path):
		_load_full_map_image(bg_path)
		return
	
	# 回退：程序生成顶视角瓦片
	print("[TopDownMap] ===== 开始生成顶视角地图: %dx%d瓦片 =====" % [MAP_WIDTH, MAP_HEIGHT])
	_create_terrain_textures()
	_generate_map()
	_world_ready = true
	print("[TopDownMap] ===== 顶视角地图生成完成 =====")


func _create_terrain_textures() -> void:
	## 创建地形纹理（优先加载自制瓦片，不存在则用代码生成）
	var terrain_types := ["grass", "dirt", "stone", "sand", "water", "concrete"]
	var custom_tiles_loaded: int = 0
	for terrain_type in terrain_types:
		var tex: Texture2D = null
		# 尝试加载自制瓦片
		var tile_path: String = "res://assets/tiles/%s.png" % terrain_type
		if ResourceLoader.exists(tile_path):
			tex = load(tile_path) as Texture2D
			if tex:
				custom_tiles_loaded += 1
				print("[TopDownMap] 加载自制瓦片: %s" % terrain_type)
		# 如果自制瓦片不存在，用代码生成
		if tex == null:
			tex = _create_topdown_tile_texture(terrain_type)
		_terrain_textures[terrain_type] = tex
	print("[TopDownMap] 地形纹理创建完成，共%d种（自制瓦片%d个，代码生成%d个）" % [
		terrain_types.size(), custom_tiles_loaded, terrain_types.size() - custom_tiles_loaded
	])


func _create_topdown_tile_texture(terrain_type: String) -> Texture2D:
	## 创建顶视角正方形瓦片纹理
	var img: Image = Image.create(TILE_WIDTH, TILE_HEIGHT, false, Image.FORMAT_RGBA8)
	
	# 基础颜色（根据地形类型）
	var base_color: Color = Color(0.4, 0.5, 0.3)  # 默认草地
	match terrain_type:
		"grass":
			base_color = Color(0.35, 0.5, 0.25)
		"dirt":
			base_color = Color(0.5, 0.4, 0.3)
		"stone":
			base_color = Color(0.5, 0.5, 0.5)
		"sand":
			base_color = Color(0.7, 0.65, 0.45)
		"water":
			base_color = Color(0.2, 0.4, 0.6)
		"concrete":
			base_color = Color(0.45, 0.45, 0.45)
		_:
			base_color = Color(0.4, 0.5, 0.3)
	
	# 填充基础颜色 + 噪声纹理
	for y in range(TILE_HEIGHT):
		for x in range(TILE_WIDTH):
			var noise: float = sin(x * 0.5) * cos(y * 0.3) * 0.05
			var noise2: float = sin(x * 0.2 + y * 0.1) * 0.03
			var c: Color = base_color + Color(noise + noise2, noise + noise2, noise + noise2, 0)
			img.set_pixel(x, y, c)
	
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	return tex


func _generate_map() -> void:
	## 生成顶视角地图（合并成一个大纹理，高性能）
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.01
	noise.seed = 12345
	
	var biome_noise := FastNoiseLite.new()
	biome_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	biome_noise.frequency = 0.005
	biome_noise.seed = 12346
	
	_tile_data.resize(MAP_WIDTH * MAP_HEIGHT)
	
	# 顶视角地图尺寸（直接是瓦片数 * 瓦片大小）
	var img_width: int = MAP_WIDTH * TILE_WIDTH
	var img_height: int = MAP_HEIGHT * TILE_HEIGHT
	print("[TopDownMap] 大纹理尺寸: %dx%d" % [img_width, img_height])
	
	# 创建大图像
	var big_img: Image = Image.create(img_width, img_height, false, Image.FORMAT_RGBA8)
	big_img.fill(Color(0, 0, 0, 1))  # 不透明背景
	
	# 预加载所有瓦片图像
	var tile_images: Dictionary = {}
	for terrain_type in _terrain_textures.keys():
		tile_images[terrain_type] = _terrain_textures[terrain_type].get_image()
	
	# 遍历所有瓦片，绘制到大图像上
	for x in range(MAP_WIDTH):
		for y in range(MAP_HEIGHT):
			var height: float = noise.get_noise_2d(float(x), float(y))
			var biome: float = biome_noise.get_noise_2d(float(x), float(y))
			
			# 根据噪声决定地形类型
			var terrain_type: String = "grass"
			if height < -0.3:
				terrain_type = "water"
			elif height < -0.1:
				terrain_type = "sand"
			elif height > 0.4:
				terrain_type = "stone"
			elif biome > 0.3:
				terrain_type = "dirt"
			
			_tile_data[y * MAP_WIDTH + x] = terrain_type
			
			# 顶视角世界坐标（直接是瓦片坐标 * 瓦片大小）
			var px: int = x * TILE_WIDTH
			var py: int = y * TILE_HEIGHT
			
			# 将瓦片图像绘制到大图像上
			var tile_img: Image = tile_images[terrain_type]
			if tile_img:
				big_img.blit_rect(tile_img, Rect2(0, 0, TILE_WIDTH, TILE_HEIGHT), Vector2(px, py))
	
	# 将大图像转换为纹理
	var big_tex: ImageTexture = ImageTexture.create_from_image(big_img)
	
	# 创建一个Sprite2D显示整个地图
	var map_sprite: Sprite2D = Sprite2D.new()
	map_sprite.texture = big_tex
	map_sprite.position = Vector2(0, 0)
	map_sprite.centered = false
	map_container.add_child(map_sprite)
	
	print("[TopDownMap] 地图瓦片生成完成，共%d个瓦片，合并为1个Sprite2D" % (MAP_WIDTH * MAP_HEIGHT))


func _load_full_map_image(bg_path: String) -> void:
	## 完整大图模式：加载一张图片作为整个地图底面
	_full_map_mode = true
	var tex: Texture2D = load(bg_path) as Texture2D
	if tex == null:
		print("[TopDownMap] 错误: 大图加载失败，回退到瓦片模式")
		_full_map_mode = false
		_create_terrain_textures()
		_generate_map()
		_world_ready = true
		return
	_full_map_size = Vector2(tex.get_width(), tex.get_height())
	
	# 创建一个Sprite2D显示整个地图
	var map_sprite: Sprite2D = Sprite2D.new()
	map_sprite.texture = tex
	map_sprite.position = Vector2(0, 0)
	map_sprite.centered = false
	map_container.add_child(map_sprite)
	
	_world_ready = true
	print("[TopDownMap] 完整大图模式加载完成，尺寸: %dx%d" % [tex.get_width(), tex.get_height()])


func is_ready() -> bool:
	return _world_ready


func get_map_size() -> Vector2:
	## 获取地图像素尺寸
	if _full_map_mode:
		return _full_map_size
	return Vector2(MAP_WIDTH * TILE_WIDTH, MAP_HEIGHT * TILE_HEIGHT)


func get_tile_size() -> Vector2:
	## 获取瓦片像素尺寸
	return Vector2(TILE_WIDTH, TILE_HEIGHT)


func get_map_tile_count() -> Vector2i:
	## 获取地图瓦片数量
	return Vector2i(MAP_WIDTH, MAP_HEIGHT)


func world_to_tile(world_pos: Vector2) -> Vector2i:
	## 世界坐标转瓦片坐标（顶视角，直接除以瓦片大小）
	return Vector2i(
		int(floor(world_pos.x / TILE_WIDTH)),
		int(floor(world_pos.y / TILE_HEIGHT))
	)


func tile_to_world(tile_x: int, tile_y: int) -> Vector2:
	## 瓦片坐标转世界坐标（返回瓦片左上角）
	return Vector2(tile_x * TILE_WIDTH, tile_y * TILE_HEIGHT)


func tile_to_world_center(tile_x: int, tile_y: int) -> Vector2:
	## 瓦片坐标转世界坐标（返回瓦片中心）
	return Vector2(
		tile_x * TILE_WIDTH + TILE_WIDTH / 2.0,
		tile_y * TILE_HEIGHT + TILE_HEIGHT / 2.0
	)


func get_tile_type(tile_x: int, tile_y: int) -> String:
	## 获取指定瓦片的地形类型
	if tile_x < 0 or tile_x >= MAP_WIDTH or tile_y < 0 or tile_y >= MAP_HEIGHT:
		return "out_of_bounds"
	if _tile_data.size() == 0:
		return "unknown"
	return _tile_data[tile_y * MAP_WIDTH + tile_x]


func is_walkable(tile_x: int, tile_y: int) -> bool:
	## 判断瓦片是否可行走
	var terrain_type: String = get_tile_type(tile_x, tile_y)
	# 水域不可行走
	if terrain_type == "water":
		return false
	return true
