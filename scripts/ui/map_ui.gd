extends Control
## 大地图界面：按M键打开，显示全地图缩略图和玩家位置

@onready var panel: Panel = $Panel
@onready var background: ColorRect = $Background
@onready var map_image: TextureRect = $Panel/VBox/MapImage
@onready var player_marker: ColorRect = $Panel/VBox/MapImage/PlayerMarker

var is_open: bool = false
var _map_texture: ImageTexture = null
var _map_generated: bool = false


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
	# 获取世界生成器
	var main = get_tree().current_scene
	if not main or not main.has_node("WorldGenerator"):
		return
	var wg = main.get_node("WorldGenerator")
	if not wg:
		return
	var map_w: int = wg.MAP_WIDTH
	var map_h: int = wg.MAP_HEIGHT
	# 创建地图图像（缩小显示，每4个瓦片显示为1个像素）
	var scale: int = 2
	var img_w: int = map_w / scale
	var img_h: int = map_h / scale
	var img := Image.create(img_w, img_h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 1))
	# 绘制地形
	for x in range(img_w):
		for y in range(img_h):
			var world_x: int = x * scale
			var world_y: int = y * scale
			var tile_type: String = wg._get_tile_type(world_x, world_y)
			var color: Color = _get_tile_map_color(tile_type)
			img.set_pixel(x, y, color)
	_map_texture = ImageTexture.create_from_image(img)
	map_image.texture = _map_texture
	_map_generated = true
	print("[MapUI] 地图缩略图生成完成: %dx%d" % [img_w, img_h])


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
	if not main or not main.has_node("WorldGenerator"):
		return
	var wg = main.get_node("WorldGenerator")
	if not wg:
		return
	var map_w: int = wg.MAP_WIDTH
	var map_h: int = wg.MAP_HEIGHT
	var tile_size: int = wg.TILE_SIZE
	var world_w: float = map_w * tile_size
	var world_h: float = map_h * tile_size
	# 计算玩家在地图上的相对位置
	var rel_x: float = player.position.x / world_w
	var rel_y: float = player.position.y / world_h
	# 地图图片的实际显示尺寸
	var img_size: Vector2 = map_image.size
	if img_size.x <= 0 or img_size.y <= 0:
		img_size = Vector2(640, 640)
	# 设置标记位置
	player_marker.visible = true
	player_marker.position = Vector2(rel_x * img_size.x - 5, rel_y * img_size.y - 5)
