extends Node2D
## 世界地图生成器：写实风格地面，单一大纹理渲染（简单可靠）

const TILE_SIZE := 64
const MAP_WIDTH := 200
const MAP_HEIGHT := 200

# 固定地形种子（设置为固定值后，每次生成的地形都一样；改为randi()可恢复随机）
const TERRAIN_SEED := 12345
const USE_FIXED_TERRAIN := true  # true=固定地形，false=随机地形

@onready var ground_layer: Node2D = $GroundLayer

var _noise: FastNoiseLite = null
var _biome_noise: FastNoiseLite = null
var _detail_noise: FastNoiseLite = null
var _micro_noise: FastNoiseLite = null

const TILE_TYPES := ["grass", "dirt", "stone", "sand", "water", "concrete", "snow"]
var _tile_textures: Dictionary = {}
var _world_ready: bool = false
var _ground_sprite: Sprite2D = null


func _ready() -> void:
	print("[WorldGen] ===== 开始生成大地图: %dx%d瓦片 =====" % [MAP_WIDTH, MAP_HEIGHT])
	_generate_noise()
	_preload_tile_textures()
	_generate_world_single_texture()
	_world_ready = true
	print("[WorldGen] ===== 大地图生成完成! 总计%d瓦片 =====" % (MAP_WIDTH * MAP_HEIGHT))
	print("[WorldGen] 地面精灵位置: %s, 纹理大小: %dx%d" % [str(_ground_sprite.position if _ground_sprite else "null"), MAP_WIDTH * TILE_SIZE, MAP_HEIGHT * TILE_SIZE])


func is_ready() -> bool:
	return _world_ready


func get_tile_type_at_position(pos: Vector2) -> String:
	# 根据世界坐标获取地形类型
	var tile_x: int = int(pos.x / TILE_SIZE)
	var tile_y: int = int(pos.y / TILE_SIZE)
	if tile_x < 0 or tile_x >= MAP_WIDTH or tile_y < 0 or tile_y >= MAP_HEIGHT:
		return "grass"
	return _get_tile_type(tile_x, tile_y)


func find_safe_spawn_position(center: Vector2, max_attempts: int = 50) -> Vector2:
	# 寻找一个草地出生点（避免水域）
	for i in range(max_attempts):
		var pos: Vector2 = center + Vector2(randf_range(-200, 200), randf_range(-200, 200))
		if get_tile_type_at_position(pos) != "water":
			return pos
	return center  # 实在找不到就返回中心


func _generate_noise() -> void:
	# 根据USE_FIXED_TERRAIN决定使用固定种子还是随机种子
	var base_seed: int = TERRAIN_SEED if USE_FIXED_TERRAIN else randi()
	if USE_FIXED_TERRAIN:
		print("[WorldGen] 使用固定地形种子: %d" % base_seed)
	else:
		print("[WorldGen] 使用随机地形种子: %d" % base_seed)
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_noise.frequency = 0.004  # 更低频率，地形变化更大
	_noise.seed = base_seed
	_biome_noise = FastNoiseLite.new()
	_biome_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_biome_noise.frequency = 0.002  # 更低频率，生物群系变化更大
	_biome_noise.seed = base_seed + 1000
	_detail_noise = FastNoiseLite.new()
	_detail_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_detail_noise.frequency = 0.06
	_detail_noise.seed = base_seed + 2000
	_micro_noise = FastNoiseLite.new()
	_micro_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_micro_noise.frequency = 0.15
	_micro_noise.seed = base_seed + 3000


func _preload_tile_textures() -> void:
	for tile_type in TILE_TYPES:
		var img: Image = _generate_tile_image(tile_type)
		_tile_textures[tile_type] = img
	print("[WorldGen] 预加载%d种写实瓦片纹理" % _tile_textures.size())


func _generate_world_single_texture() -> void:
	# 清除旧节点
	for child in ground_layer.get_children():
		child.queue_free()
	# 创建大图像
	var total_width: int = MAP_WIDTH * TILE_SIZE
	var total_height: int = MAP_HEIGHT * TILE_SIZE
	var world_img: Image = Image.create(total_width, total_height, false, Image.FORMAT_RGBA8)
	# 先用亮绿色纯色填充（确保能看到颜色）
	world_img.fill(Color(0.65, 0.85, 0.4))
	print("[WorldGen] 大图像已创建，填充亮绿色")
	# 遍历每个瓦片，把纹理绘制到大图像上
	var tile_count: Dictionary = {}
	for x in range(MAP_WIDTH):
		for y in range(MAP_HEIGHT):
			var tile_type: String = _get_tile_type(x, y)
			tile_count[tile_type] = tile_count.get(tile_type, 0) + 1
			var tile_img: Image = _tile_textures[tile_type]
			var offset_x: int = x * TILE_SIZE
			var offset_y: int = y * TILE_SIZE
			_blit_image(world_img, tile_img, offset_x, offset_y)
	# 创建纹理和精灵
	var world_tex: ImageTexture = ImageTexture.create_from_image(world_img)
	_ground_sprite = Sprite2D.new()
	_ground_sprite.texture = world_tex
	_ground_sprite.position = Vector2(total_width / 2.0, total_height / 2.0)
	_ground_sprite.centered = true
	_ground_sprite.z_index = -100  # 确保在最底层
	_ground_sprite.modulate = Color.WHITE  # 确保没有颜色调整
	ground_layer.add_child(_ground_sprite)
	print("[WorldGen] 地面精灵已创建，位置:%s, z_index:-100, modulate:WHITE" % str(_ground_sprite.position))
	# 打印统计
	for tile_type in tile_count.keys():
		print("[WorldGen] %s: %d个瓦片" % [tile_type, tile_count[tile_type]])


func _blit_image(dest: Image, src: Image, offset_x: int, offset_y: int) -> void:
	# 简单的图像绘制（不支持缩放，src必须是TILE_SIZE x TILE_SIZE）
	for x in range(TILE_SIZE):
		for y in range(TILE_SIZE):
			var color: Color = src.get_pixel(x, y)
			if color.a > 0.01:
				dest.set_pixel(offset_x + x, offset_y + y, color)


func _get_tile_type(x: int, y: int) -> String:
	var height: float = _noise.get_noise_2d(float(x), float(y))
	var biome: float = _biome_noise.get_noise_2d(float(x), float(y))
	# 水域（约8%）
	if height < -0.35:
		return "water"
	# 山区（约10%）
	if height > 0.4:
		return "stone"
	# 城市废墟（约15%）
	if biome > 0.3 and biome < 0.48:
		return "concrete"
	# 沙地/军事基地区域（约7%）
	if biome > 0.65:
		return "sand"
	# 泥土过渡带
	if height > 0.25 and height < 0.4:
		return "dirt"
	# 森林/草地（约60%）
	return "grass"


# ==================== 写实瓦片纹理生成 ====================

func _generate_tile_image(tile_type: String) -> Image:
	var img: Image = Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	match tile_type:
		"grass": _draw_grass_realistic(img)
		"dirt": _draw_dirt_realistic(img)
		"stone": _draw_stone_realistic(img)
		"sand": _draw_sand_realistic(img)
		"water": _draw_water_realistic(img)
		"concrete": _draw_concrete_realistic(img)
		"snow": _draw_snow_realistic(img)
		_: img.fill(Color.GRAY)
	return img


func _draw_grass_realistic(img: Image) -> void:
	# 明亮的草绿色，确保能看到明显变化
	img.fill(Color(0.65, 0.85, 0.4))
	var rng := RandomNumberGenerator.new()
	rng.seed = 10001
	for x in range(TILE_SIZE):
		for y in range(TILE_SIZE):
			var n1: float = _noise.get_noise_2d(float(x) * 0.25, float(y) * 0.25)
			var n2: float = _detail_noise.get_noise_2d(float(x) * 0.6, float(y) * 0.6)
			var shade: float = n1 * 0.08 + n2 * 0.05
			var r: float = 0.65 + shade + rng.randf_range(-0.01, 0.01)
			var g: float = 0.85 + shade + rng.randf_range(-0.01, 0.01)
			var b: float = 0.4 + shade * 0.5
			img.set_pixel(x, y, Color(clamp(r, 0, 1), clamp(g, 0, 1), clamp(b, 0, 1)))
	# 随机草叶细节
	for i in range(60):
		var gx: int = rng.randi_range(0, TILE_SIZE - 1)
		var gy: int = rng.randi_range(0, TILE_SIZE - 1)
		img.set_pixel(gx, gy, Color(0.45, 0.65, 0.3))
		if gx + 1 < TILE_SIZE:
			img.set_pixel(gx + 1, gy, Color(0.5, 0.7, 0.35))


func _draw_dirt_realistic(img: Image) -> void:
	img.fill(Color(0.65, 0.5, 0.35))
	var rng := RandomNumberGenerator.new()
	rng.seed = 10002
	for x in range(TILE_SIZE):
		for y in range(TILE_SIZE):
			var n1: float = _noise.get_noise_2d(float(x) * 0.3, float(y) * 0.3)
			var shade: float = n1 * 0.08
			var r: float = 0.65 + shade
			var g: float = 0.5 + shade * 0.8
			var b: float = 0.35 + shade * 0.5
			img.set_pixel(x, y, Color(clamp(r, 0, 1), clamp(g, 0, 1), clamp(b, 0, 1)))
	for i in range(20):
		var gx: int = rng.randi_range(0, TILE_SIZE - 1)
		var gy: int = rng.randi_range(0, TILE_SIZE - 1)
		img.set_pixel(gx, gy, Color(0.5, 0.4, 0.3))


func _draw_stone_realistic(img: Image) -> void:
	img.fill(Color(0.6, 0.6, 0.65))
	var rng := RandomNumberGenerator.new()
	rng.seed = 10003
	for x in range(TILE_SIZE):
		for y in range(TILE_SIZE):
			var n1: float = _noise.get_noise_2d(float(x) * 0.2, float(y) * 0.2)
			var n2: float = _detail_noise.get_noise_2d(float(x) * 0.5, float(y) * 0.5)
			var shade: float = n1 * 0.1 + n2 * 0.05
			var c: float = 0.6 + shade
			img.set_pixel(x, y, Color(c, c, c + 0.05))
	for i in range(10):
		var gx: int = rng.randi_range(0, TILE_SIZE - 1)
		var gy: int = rng.randi_range(0, TILE_SIZE - 1)
		for j in range(5):
			if gx + j < TILE_SIZE and gy + j < TILE_SIZE:
				img.set_pixel(gx + j, gy + j, Color(0.45, 0.45, 0.5))


func _draw_sand_realistic(img: Image) -> void:
	img.fill(Color(0.9, 0.82, 0.55))
	var rng := RandomNumberGenerator.new()
	rng.seed = 10004
	for x in range(TILE_SIZE):
		for y in range(TILE_SIZE):
			var n1: float = _noise.get_noise_2d(float(x) * 0.4, float(y) * 0.4)
			var shade: float = n1 * 0.05
			var r: float = 0.9 + shade
			var g: float = 0.82 + shade * 0.9
			var b: float = 0.55 + shade * 0.7
			img.set_pixel(x, y, Color(clamp(r, 0, 1), clamp(g, 0, 1), clamp(b, 0, 1)))
	for i in range(15):
		var gy: int = rng.randi_range(0, TILE_SIZE - 1)
		for gx in range(TILE_SIZE):
			if rng.randf() < 0.3:
				img.set_pixel(gx, gy, Color(0.82, 0.75, 0.5))


func _draw_water_realistic(img: Image) -> void:
	img.fill(Color(0.3, 0.6, 0.85))
	var rng := RandomNumberGenerator.new()
	rng.seed = 10005
	for x in range(TILE_SIZE):
		for y in range(TILE_SIZE):
			var n1: float = _noise.get_noise_2d(float(x) * 0.3, float(y) * 0.3)
			var shade: float = n1 * 0.1
			var r: float = 0.3 + shade * 0.5
			var g: float = 0.6 + shade
			var b: float = 0.85 + shade
			img.set_pixel(x, y, Color(clamp(r, 0, 1), clamp(g, 0, 1), clamp(b, 0, 1)))
	# 波纹高光
	for i in range(20):
		var gx: int = rng.randi_range(0, TILE_SIZE - 1)
		var gy: int = rng.randi_range(0, TILE_SIZE - 1)
		img.set_pixel(gx, gy, Color(0.5, 0.75, 0.95, 0.6))


func _draw_concrete_realistic(img: Image) -> void:
	img.fill(Color(0.65, 0.65, 0.65))
	var rng := RandomNumberGenerator.new()
	rng.seed = 10006
	for x in range(TILE_SIZE):
		for y in range(TILE_SIZE):
			var n1: float = _noise.get_noise_2d(float(x) * 0.15, float(y) * 0.15)
			var n2: float = _detail_noise.get_noise_2d(float(x) * 0.4, float(y) * 0.4)
			var shade: float = n1 * 0.08 + n2 * 0.04
			var c: float = 0.65 + shade
			img.set_pixel(x, y, Color(c, c, c))
	for i in range(15):
		var gx: int = rng.randi_range(0, TILE_SIZE - 1)
		var gy: int = rng.randi_range(0, TILE_SIZE - 1)
		img.set_pixel(gx, gy, Color(0.5, 0.5, 0.5))
	for i in range(5):
		var gx: int = rng.randi_range(5, TILE_SIZE - 5)
		var gy: int = rng.randi_range(5, TILE_SIZE - 5)
		img.set_pixel(gx, gy, Color(0.7, 0.7, 0.75))
		img.set_pixel(gx + 1, gy, Color(0.65, 0.65, 0.7))


func _draw_snow_realistic(img: Image) -> void:
	img.fill(Color(0.9, 0.92, 0.95))
	var rng := RandomNumberGenerator.new()
	rng.seed = 10007
	for x in range(TILE_SIZE):
		for y in range(TILE_SIZE):
			var n1: float = _noise.get_noise_2d(float(x) * 0.25, float(y) * 0.25)
			var shade: float = n1 * 0.05
			var r: float = 0.9 + shade
			var g: float = 0.92 + shade
			var b: float = 0.95 + shade
			img.set_pixel(x, y, Color(clamp(r, 0, 1), clamp(g, 0, 1), clamp(b, 0, 1)))
	# 雪地脚印和阴影
	for i in range(8):
		var gx: int = rng.randi_range(0, TILE_SIZE - 1)
		var gy: int = rng.randi_range(0, TILE_SIZE - 1)
		img.set_pixel(gx, gy, Color(0.8, 0.82, 0.85))
