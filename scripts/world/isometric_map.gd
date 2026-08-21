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
	
	# 回退：程序生成等距瓦片
	print("[IsoMap] ===== 开始生成等距地图: %dx%d瓦片 =====" % [MAP_WIDTH, MAP_HEIGHT])
	_create_terrain_textures()
	_generate_map()
	_world_ready = true
	print("[IsoMap] ===== 等距地图生成完成 =====")


func _create_terrain_textures() -> void:
	## 创建地形纹理
	var terrain_types := ["default"]
	for terrain_type in terrain_types:
		var tex: Texture2D = _create_isometric_tile_texture(terrain_type)
		_terrain_textures[terrain_type] = tex
	print("[IsoMap] 地形纹理创建完成，共%d种" % terrain_types.size())


func _create_isometric_tile_texture(terrain_type: String) -> Texture2D:
	## 创建等距菱形瓦片纹理
	var img: Image = Image.create(TILE_WIDTH, TILE_HEIGHT, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))  # 透明背景
	
	var center := Vector2(TILE_WIDTH / 2.0, TILE_HEIGHT / 2.0)
	
	# 基础颜色（统一默认灰色，无地形区分）
	var base_color: Color = Color(0.5, 0.5, 0.5)
	
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
			
			# 统一默认地形，无任何地形区分
			var terrain_type: String = "default"
			
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


func _load_full_map_image(bg_path: String) -> void:
	## 完整大图模式：加载一张图片作为整个地图底面
	_full_map_mode = true
	var tex: Texture2D = load(bg_path) as Texture2D
	if tex == null:
		print("[IsoMap] 错误: 大图加载失败，回退到瓦片模式")
		_full_map_mode = false
		_create_terrain_textures()
		_generate_map()
		_world_ready = true
		return
	_full_map_size = Vector2(tex.get_width(), tex.get_height())
	
	# 计算等距地图整体边界尺寸
	var map_total_width: float = (MAP_WIDTH + MAP_HEIGHT) * TILE_WIDTH / 2.0
	var map_total_height: float = (MAP_WIDTH + MAP_HEIGHT) * TILE_HEIGHT / 2.0
	# 计算缩放比例，使图片覆盖整个地图区域（保持宽高比）
	var scale_x: float = map_total_width / tex.get_width()
	var scale_y: float = map_total_height / tex.get_height()
	var map_scale: float = max(scale_x, scale_y)
	
	# 创建Sprite2D显示大图，中心与原等距地图中心对齐(0, 3200)
	var map_sprite: Sprite2D = Sprite2D.new()
	map_sprite.texture = tex
	map_sprite.position = Vector2(0, (MAP_WIDTH + MAP_HEIGHT) * TILE_HEIGHT / 4.0)
	map_sprite.centered = true
	map_sprite.scale = Vector2(map_scale, map_scale)
	map_container.add_child(map_sprite)
	print("[IsoMap] 地图缩放比例: %.2f (原图 %dx%d -> 显示 %dx%d)" % [map_scale, tex.get_width(), tex.get_height(), int(tex.get_width() * map_scale), int(tex.get_height() * map_scale)])
	
	# 填充_tile_data为全default，保证小地图系统不崩溃
	_tile_data.resize(MAP_WIDTH * MAP_HEIGHT)
	for i in range(_tile_data.size()):
		_tile_data[i] = "default"
	
	_world_ready = true
	print("[IsoMap] ===== 完整大图模式已加载: %dx%d =====" % [tex.get_width(), tex.get_height()])


func get_tile_type_at_world_position(world_pos: Vector2) -> String:
	## 根据世界坐标获取瓦片类型
	if _full_map_mode:
		return "default"
	var tile_x: float = (world_pos.x / (TILE_WIDTH / 2.0) + world_pos.y / (TILE_HEIGHT / 2.0)) / 2.0
	var tile_y: float = (world_pos.y / (TILE_HEIGHT / 2.0) - world_pos.x / (TILE_WIDTH / 2.0)) / 2.0
	var tx: int = int(tile_x)
	var ty: int = int(tile_y)
	if tx < 0 or tx >= MAP_WIDTH or ty < 0 or ty >= MAP_HEIGHT:
		return "default"
	return _tile_data[ty * MAP_WIDTH + tx]


func find_safe_spawn_position(center: Vector2, max_attempts: int = 50) -> Vector2:
	## 寻找一个安全出生点
	if _full_map_mode:
		# 大图模式：在中心附近随机，限制在大图范围内
		var half_w: float = _full_map_size.x / 2.0
		var half_h: float = _full_map_size.y / 2.0
		for i in range(max_attempts):
			var offset: Vector2 = Vector2(randf_range(-half_w * 0.3, half_w * 0.3), randf_range(-half_h * 0.3, half_h * 0.3))
			var pos: Vector2 = center + offset
			# 检查是否在大图范围内
			var relative: Vector2 = pos - Vector2(0, (MAP_WIDTH + MAP_HEIGHT) * TILE_HEIGHT / 4.0)
			if abs(relative.x) < half_w * 0.9 and abs(relative.y) < half_h * 0.9:
				return pos
		return center
	# 瓦片模式：在中心附近随机
	for i in range(max_attempts):
		var pos: Vector2 = center + Vector2(randf_range(-200, 200), randf_range(-200, 200))
		return pos
	return center
