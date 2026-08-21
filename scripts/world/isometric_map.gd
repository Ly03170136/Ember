extends Node2D
## 等距地图生成器（合并大纹理渲染，高性能）
## 将所有瓦片合并成一个大纹理，只用1个Sprite2D渲染，大大提高FPS

const TILE_WIDTH := 64
const TILE_HEIGHT := 32  # 等距瓦片高度是宽度的一半
const MAP_WIDTH := 200
const MAP_HEIGHT := 200

@onready var map_container: Node2D = $MapContainer

var _world_ready: bool = false
var _terrain_textures: Dictionary = {}  # 地形类型 -> Texture2D
var _tile_data: Array = []  # 存储每个瓦片的地形类型


func _ready() -> void:
	print("[IsoMap] ===== 开始生成等距地图: %dx%d瓦片 =====" % [MAP_WIDTH, MAP_HEIGHT])
	# 安全获取map_container
	if map_container == null:
		map_container = get_node_or_null("MapContainer") as Node2D
	if map_container == null:
		map_container = Node2D.new()
		map_container.name = "MapContainer"
		add_child(map_container)
	_create_terrain_textures()
	_generate_map()
	_world_ready = true
	print("[IsoMap] ===== 等距地图生成完成 =====")


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
				print("[IsoMap] 加载自制瓦片: %s" % terrain_type)
		# 如果自制瓦片不存在，用代码生成
		if tex == null:
			tex = _create_isometric_tile_texture(terrain_type)
		_terrain_textures[terrain_type] = tex
	print("[IsoMap] 地形纹理创建完成，共%d种（自制瓦片%d个，代码生成%d个）" % [
		terrain_types.size(), custom_tiles_loaded, terrain_types.size() - custom_tiles_loaded
	])


func _create_isometric_tile_texture(terrain_type: String) -> Texture2D:
	## 创建等距菱形瓦片纹理
	var img: Image = Image.create(TILE_WIDTH, TILE_HEIGHT, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))  # 透明背景
	
	var center := Vector2(TILE_WIDTH / 2.0, TILE_HEIGHT / 2.0)
	
	# 基础颜色
	var base_color: Color = Color.GREEN
	match terrain_type:
		"grass": base_color = Color(0.45, 0.65, 0.3)
		"dirt": base_color = Color(0.55, 0.4, 0.25)
		"stone": base_color = Color(0.5, 0.5, 0.55)
		"sand": base_color = Color(0.8, 0.7, 0.45)
		"water": base_color = Color(0.2, 0.4, 0.7)
		"concrete": base_color = Color(0.5, 0.5, 0.5)
	
	# 绘制菱形
	for y in range(TILE_HEIGHT):
		for x in range(TILE_WIDTH):
			var dx: float = abs(x - center.x) / (TILE_WIDTH / 2.0)
			var dy: float = abs(y - center.y) / (TILE_HEIGHT / 2.0)
			if dx + dy <= 1.0:
				var noise: float = sin(x * 0.3) * cos(y * 0.5) * 0.05
				var c: Color = base_color + Color(noise, noise, noise, 0)
				img.set_pixel(x, y, c)
	
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	return tex


func _generate_map() -> void:
	## 生成等距地图（合并成一个大纹理，高性能）
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.01
	noise.seed = 12345
	
	var biome_noise := FastNoiseLite.new()
	biome_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	biome_noise.frequency = 0.005
	biome_noise.seed = 12346
	
	_tile_data.resize(MAP_WIDTH * MAP_HEIGHT)
	
	# 计算等距地图边界
	var min_iso_x: float = -(MAP_HEIGHT - 1) * TILE_WIDTH / 2.0
	var max_iso_x: float = (MAP_WIDTH - 1) * TILE_WIDTH / 2.0
	var min_iso_y: float = 0.0
	var max_iso_y: float = (MAP_WIDTH + MAP_HEIGHT - 2) * TILE_HEIGHT / 2.0
	var img_width: int = int(max_iso_x - min_iso_x) + TILE_WIDTH
	var img_height: int = int(max_iso_y - min_iso_y) + TILE_HEIGHT
	print("[IsoMap] 大纹理尺寸: %dx%d" % [img_width, img_height])
	
	# 创建大图像
	var big_img: Image = Image.create(img_width, img_height, false, Image.FORMAT_RGBA8)
	big_img.fill(Color(0, 0, 0, 0))  # 透明背景
	
	# 预加载所有瓦片图像
	var tile_images: Dictionary = {}
	for terrain_type in _terrain_textures.keys():
		tile_images[terrain_type] = _terrain_textures[terrain_type].get_image()
	
	# 遍历所有瓦片，绘制到大图像上
	for x in range(MAP_WIDTH):
		for y in range(MAP_HEIGHT):
			var height: float = noise.get_noise_2d(float(x), float(y))
			var biome: float = biome_noise.get_noise_2d(float(x), float(y))
			
			var terrain_type: String = "grass"
			if height < -0.3:
				terrain_type = "water"
			elif height > 0.4:
				terrain_type = "stone"
			elif biome > 0.3 and biome < 0.48:
				terrain_type = "concrete"
			elif biome > 0.65:
				terrain_type = "sand"
			elif height > 0.25 and height < 0.4:
				terrain_type = "dirt"
			
			_tile_data[y * MAP_WIDTH + x] = terrain_type
			
			# 计算等距世界坐标
			var iso_x: float = (x - y) * TILE_WIDTH / 2.0
			var iso_y: float = (x + y) * TILE_HEIGHT / 2.0
			
			# 计算在大图像中的位置（瓦片中心）
			var px: int = int(iso_x - min_iso_x)
			var py: int = int(iso_y - min_iso_y)
			
			# 将瓦片图像绘制到大图像上
			var tile_img: Image = tile_images[terrain_type]
			if tile_img:
				for ty in range(TILE_HEIGHT):
					for tx in range(TILE_WIDTH):
						var c: Color = tile_img.get_pixel(tx, ty)
						if c.a > 0.1:  # 只绘制不透明像素
							var dst_x: int = px + tx - TILE_WIDTH / 2
							var dst_y: int = py + ty - TILE_HEIGHT / 2
							if dst_x >= 0 and dst_x < img_width and dst_y >= 0 and dst_y < img_height:
								big_img.set_pixel(dst_x, dst_y, c)
	
	# 将大图像转换为纹理
	var big_tex: ImageTexture = ImageTexture.create_from_image(big_img)
	
	# 创建一个Sprite2D显示整个地图
	var map_sprite: Sprite2D = Sprite2D.new()
	map_sprite.texture = big_tex
	map_sprite.position = Vector2(min_iso_x + TILE_WIDTH / 2, min_iso_y + TILE_HEIGHT / 2)
	map_sprite.centered = false
	map_container.add_child(map_sprite)
	
	print("[IsoMap] 地图瓦片生成完成，共%d个瓦片，合并为1个Sprite2D" % (MAP_WIDTH * MAP_HEIGHT))


func get_tile_type_at_world_position(world_pos: Vector2) -> String:
	## 根据世界坐标获取瓦片类型（等距坐标反算）
	var tile_x: float = (world_pos.x / (TILE_WIDTH / 2.0) + world_pos.y / (TILE_HEIGHT / 2.0)) / 2.0
	var tile_y: float = (world_pos.y / (TILE_HEIGHT / 2.0) - world_pos.x / (TILE_WIDTH / 2.0)) / 2.0
	var tx: int = int(tile_x)
	var ty: int = int(tile_y)
	if tx < 0 or tx >= MAP_WIDTH or ty < 0 or ty >= MAP_HEIGHT:
		return "grass"
	return _tile_data[ty * MAP_WIDTH + tx]


func find_safe_spawn_position(center: Vector2, max_attempts: int = 50) -> Vector2:
	## 寻找一个草地出生点（避免水域）
	for i in range(max_attempts):
		var pos: Vector2 = center + Vector2(randf_range(-200, 200), randf_range(-200, 200))
		if get_tile_type_at_world_position(pos) != "water":
			return pos
	return center
