extends Control
## 大地图界面：按M键打开，显示全地图缩略图和玩家位置

@onready var panel: Panel = $Panel
@onready var background: ColorRect = $Background
@onready var map_image: TextureRect = $Panel/VBox/MapImage
@onready var player_marker: ColorRect = $Panel/VBox/MapImage/PlayerMarker

var is_open: bool = false
var _map_texture: ImageTexture = null
var _map_generated: bool = false
# 等距投影参数
var _map_scale_x: float = 2.0
var _map_scale_y: float = 1.0
var _map_min_x: float = 0.0
var _map_min_y: float = 0.0
var _map_img_w: int = 0
var _map_img_h: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	background.visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_M:
			toggle()
			get_viewport().set_input_as_handled()


func toggle() -> void:
	is_open = not is_open
	panel.visible = is_open
	background.visible = is_open
	if is_open:
		mouse_filter = Control.MOUSE_FILTER_STOP
		if not _map_generated:
			_generate_map_texture()
		_update_player_marker()
	else:
		mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if is_open:
		_update_player_marker()


func _generate_map_texture() -> void:
	# 获取等距地图生成器
	var main = get_tree().current_scene
	if not main or not main.has_node("IsometricMap"):
		print("[MapUI] 错误: 找不到IsometricMap节点")
		return
	var iso_map = main.get_node("IsometricMap")
	if not iso_map:
		return
	var map_w: int = iso_map.MAP_WIDTH
	var map_h: int = iso_map.MAP_HEIGHT
	print("[MapUI] 地图大小: %dx%d, _tile_data大小: %d" % [map_w, map_h, iso_map._tile_data.size()])
	# 等距投影渲染
	var scale_x: float = 2.0  # 每个瓦片x方向缩放
	var scale_y: float = 1.0  # 每个瓦片y方向缩放
	# 计算等距地图边界
	var min_screen_x: float = -(map_h - 1) * scale_x
	var max_screen_x: float = (map_w - 1) * scale_x
	var min_screen_y: float = 0
	var max_screen_y: float = (map_w + map_h - 2) * scale_y
	var img_w: int = int(max_screen_x - min_screen_x) + 20
	var img_h: int = int(max_screen_y - min_screen_y) + 20
	if img_w < 100: img_w = 100
	if img_h < 100: img_h = 100
	var img := Image.create(img_w, img_h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.1, 0.1, 0.12, 1))
	# 绘制地形（等距投影）
	for x in range(map_w):
		for y in range(map_h):
			var idx: int = y * map_w + x
			var tile_type: String = "grass"
			if iso_map._tile_data.size() > idx:
				tile_type = iso_map._tile_data[idx]
			var color: Color = _get_tile_map_color(tile_type)
			# 等距投影到屏幕坐标
			var sx: float = (x - y) * scale_x - min_screen_x + 10
			var sy: float = (x + y) * scale_y - min_screen_y + 10
			# 绘制小方块
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					var px: int = int(sx) + dx
					var py: int = int(sy) + dy
					if px >= 0 and px < img_w and py >= 0 and py < img_h:
						img.set_pixel(px, py, color)
	_map_texture = ImageTexture.create_from_image(img)
	map_image.texture = _map_texture
	_map_generated = true
	# 保存等距投影参数供玩家标记使用
	_map_scale_x = scale_x
	_map_scale_y = scale_y
	_map_min_x = min_screen_x
	_map_min_y = min_screen_y
	_map_img_w = img_w
	_map_img_h = img_h
	print("[MapUI] 等距地图缩略图生成完成: %dx%d" % [img_w, img_h])


func _get_tile_map_color(tile_type: String) -> Color:
	match tile_type:
		"grass":
			return Color(0.3, 0.5, 0.25)
		"dirt":
			return Color(0.5, 0.38, 0.25)
		"stone":
			return Color(0.5, 0.5, 0.52)
		"sand":
			return Color(0.75, 0.68, 0.5)
		"water":
			return Color(0.2, 0.4, 0.65)
		"concrete":
			return Color(0.55, 0.54, 0.56)
		"snow":
			return Color(0.9, 0.92, 0.95)
		_:
			return Color(0.3, 0.5, 0.25)


func _update_player_marker() -> void:
	var player = GameManager.get_local_player()
	if not player or not is_instance_valid(player):
		player_marker.visible = false
		return
	var main = get_tree().current_scene
	if not main or not main.has_node("IsometricMap"):
		return
	var iso_map = main.get_node("IsometricMap")
	if not iso_map:
		return
	var tile_w: int = iso_map.TILE_WIDTH
	var tile_h: int = iso_map.TILE_HEIGHT
	# 将玩家等距世界坐标反算为瓦片坐标
	var tile_x: float = (player.position.x / (tile_w / 2.0) + player.position.y / (tile_h / 2.0)) / 2.0
	var tile_y: float = (player.position.y / (tile_h / 2.0) - player.position.x / (tile_w / 2.0)) / 2.0
	# 等距投影到大图像素坐标
	var sx: float = (tile_x - tile_y) * _map_scale_x - _map_min_x + 10
	var sy: float = (tile_x + tile_y) * _map_scale_y - _map_min_y + 10
	# 映射到TextureRect的实际显示尺寸
	var img_size: Vector2 = map_image.size
	if img_size.x <= 0 or img_size.y <= 0:
		img_size = Vector2(400, 300)
	var rel_x: float = sx / _map_img_w
	var rel_y: float = sy / _map_img_h
	# 设置标记位置
	player_marker.visible = true
	player_marker.position = Vector2(rel_x * img_size.x - 5, rel_y * img_size.y - 5)
