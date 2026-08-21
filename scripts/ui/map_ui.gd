extends Control
## PUBG风格大地图：滚轮缩放、拖动平移、边界限制
## 按M键打开/关闭

@onready var background: ColorRect = $Background
@onready var map_panel: Panel = $MapPanel
@onready var map_viewport: Control = $MapPanel/MapViewport
@onready var map_container: Control = $MapPanel/MapViewport/MapContainer
@onready var map_image: TextureRect = $MapPanel/MapViewport/MapContainer/MapImage
@onready var player_marker: ColorRect = $MapPanel/MapViewport/MapContainer/MapImage/PlayerMarker
@onready var player_arrow: Label = $MapPanel/MapViewport/MapContainer/MapImage/PlayerArrow
@onready var zoom_label: Label = $MapPanel/ZoomLabel

var is_open: bool = false
var _map_texture: ImageTexture = null
var _map_generated: bool = false

# 缩放配置
var current_zoom: float = 1.0
var min_zoom: float = 0.3
var max_zoom: float = 5.0
var zoom_step: float = 0.15

# 平移配置
var map_offset: Vector2 = Vector2.ZERO
var is_dragging: bool = false
var drag_start_mouse: Vector2 = Vector2.ZERO
var drag_start_offset: Vector2 = Vector2.ZERO

# 地图原始尺寸
var map_original_size: Vector2 = Vector2.ZERO

# 等距投影参数
var _map_scale_x: float = 2.0
var _map_scale_y: float = 1.0
var _map_min_x: float = 0.0
var _map_min_y: float = 0.0
var _map_img_w: int = 0
var _map_img_h: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	background.visible = false
	map_panel.visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 添加到组，方便其他脚本检测大地图是否打开
	add_to_group("map_ui")
	# 连接地图视口的输入事件（处理拖动）
	map_viewport.gui_input.connect(_on_map_viewport_input)
	# 初始化地图容器位置
	_update_map_transform()


func _input(event: InputEvent) -> void:
	# 只有大地图打开时才处理输入
	if not is_open:
		return
	
	# 滚轮缩放
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at_position(map_viewport.get_local_mouse_position(), zoom_step)
			get_viewport().set_input_as_handled()
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at_position(map_viewport.get_local_mouse_position(), -zoom_step)
			get_viewport().set_input_as_handled()
			return
		# 鼠标左键拖动
		elif event.button_index == MOUSE_BUTTON_LEFT:
			# 检查鼠标是否在地图视口区域内
			if _is_mouse_in_map_viewport():
				if event.pressed:
					# 开始拖动
					is_dragging = true
					drag_start_mouse = map_viewport.get_local_mouse_position()
					drag_start_offset = map_offset
					get_viewport().set_input_as_handled()
					return
				else:
					# 结束拖动
					is_dragging = false
					get_viewport().set_input_as_handled()
					return
	
	# 鼠标移动（拖动）
	if event is InputEventMouseMotion:
		if is_dragging:
			var current_mouse: Vector2 = map_viewport.get_local_mouse_position()
			var delta: Vector2 = current_mouse - drag_start_mouse
			map_offset = drag_start_offset + delta
			_clamp_map_offset()
			_update_map_transform()
			get_viewport().set_input_as_handled()
			return


func _is_mouse_in_map_viewport() -> bool:
	# 检查鼠标是否在地图视口区域内
	var mouse_pos: Vector2 = map_viewport.get_global_mouse_position()
	var viewport_rect: Rect2 = map_viewport.get_global_rect()
	return viewport_rect.has_point(mouse_pos)


func _unhandled_input(event: InputEvent) -> void:
	# M键开关
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_M:
			toggle()
			get_viewport().set_input_as_handled()
			return


func _on_map_viewport_input(event: InputEvent) -> void:
	# 这个函数保留备用，现在主要输入都在_input中处理
	pass


func toggle() -> void:
	is_open = not is_open
	background.visible = is_open
	map_panel.visible = is_open
	if is_open:
		mouse_filter = Control.MOUSE_FILTER_STOP
		if not _map_generated:
			_generate_map_texture()
		_reset_view()
		_update_player_marker()
	else:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		is_dragging = false


func _process(delta: float) -> void:
	if is_open:
		_update_player_marker()


# ==================== 缩放功能 ====================

func _zoom_at_position(mouse_pos: Vector2, zoom_delta: float) -> void:
	# 以鼠标位置为中心缩放
	var old_zoom: float = current_zoom
	var new_zoom: float = clamp(current_zoom + zoom_delta, min_zoom, max_zoom)
	
	if abs(new_zoom - old_zoom) < 0.001:
		return
	
	# 将鼠标位置转换为地图视口内的坐标
	var viewport_mouse: Vector2 = map_viewport.get_local_mouse_position()
	var viewport_size: Vector2 = map_viewport.size
	
	# 计算鼠标在地图上的位置（缩放前）
	var map_point_before: Vector2 = (viewport_mouse - viewport_size / 2.0 - map_offset) / old_zoom
	
	# 更新缩放
	current_zoom = new_zoom
	
	# 调整偏移，使鼠标指向的地图点保持不变
	map_offset = viewport_mouse - viewport_size / 2.0 - map_point_before * current_zoom
	
	_clamp_map_offset()
	_update_map_transform()
	_update_zoom_label()


func _update_zoom_label() -> void:
	zoom_label.text = "缩放: %d%%" % int(current_zoom * 100)


# ==================== 平移和边界限制 ====================

func _clamp_map_offset() -> void:
	# 限制地图偏移，防止拖出视口
	if map_original_size.x <= 0 or map_original_size.y <= 0:
		return
	
	var viewport_size: Vector2 = map_viewport.size
	var scaled_map_size: Vector2 = map_original_size * current_zoom
	
	# 计算最大偏移（地图比视口大时才能拖动）
	var max_offset_x: float = max(0, (scaled_map_size.x - viewport_size.x) / 2.0)
	var max_offset_y: float = max(0, (scaled_map_size.y - viewport_size.y) / 2.0)
	
	# 限制偏移范围
	map_offset.x = clamp(map_offset.x, -max_offset_x, max_offset_x)
	map_offset.y = clamp(map_offset.y, -max_offset_y, max_offset_y)


func _reset_view() -> void:
	# 重置视图，适应视口
	current_zoom = 1.0
	map_offset = Vector2.ZERO
	
	if map_original_size.x > 0 and map_original_size.y > 0:
		var viewport_size: Vector2 = map_viewport.size
		var scale_x: float = viewport_size.x / map_original_size.x
		var scale_y: float = viewport_size.y / map_original_size.y
		current_zoom = min(scale_x, scale_y) * 0.9  # 留一点边距
		current_zoom = clamp(current_zoom, min_zoom, max_zoom)
	
	_clamp_map_offset()
	_update_map_transform()
	_update_zoom_label()


func _update_map_transform() -> void:
	# 更新地图容器的位置和缩放
	map_container.position = map_viewport.size / 2.0 + map_offset
	map_container.scale = Vector2(current_zoom, current_zoom)


# ==================== 地图生成 ====================

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
	print("[MapUI] 地图大小: %dx%d" % [map_w, map_h])
	
	# 等距投影渲染
	var scale_x: float = 2.0
	var scale_y: float = 1.0
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
	img.fill(Color(0.08, 0.08, 0.1, 1))
	
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
	map_image.custom_minimum_size = Vector2(img_w, img_h)
	map_original_size = Vector2(img_w, img_h)
	_map_generated = true
	
	# 保存等距投影参数
	_map_scale_x = scale_x
	_map_scale_y = scale_y
	_map_min_x = min_screen_x
	_map_min_y = min_screen_y
	_map_img_w = img_w
	_map_img_h = img_h
	
	print("[MapUI] 地图缩略图生成完成: %dx%d" % [img_w, img_h])


func _get_tile_map_color(tile_type: String) -> Color:
	match tile_type:
		"grass":
			return Color(0.3, 0.55, 0.25)
		"dirt":
			return Color(0.55, 0.42, 0.28)
		"stone":
			return Color(0.5, 0.5, 0.55)
		"sand":
			return Color(0.78, 0.7, 0.52)
		"water":
			return Color(0.2, 0.45, 0.7)
		"concrete":
			return Color(0.55, 0.54, 0.58)
		"snow":
			return Color(0.9, 0.92, 0.95)
		"asphalt":
			return Color(0.25, 0.25, 0.28)
		"ruins":
			return Color(0.45, 0.42, 0.4)
		"forest_floor":
			return Color(0.25, 0.4, 0.2)
		_:
			return Color(0.3, 0.55, 0.25)


# ==================== 玩家标记 ====================

func _update_player_marker() -> void:
	var player = GameManager.get_local_player()
	if not player or not is_instance_valid(player):
		player_marker.visible = false
		player_arrow.visible = false
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
	
	# 映射到MapImage的坐标
	if map_original_size.x <= 0 or map_original_size.y <= 0:
		return
	
	var rel_x: float = sx / _map_img_w
	var rel_y: float = sy / _map_img_h
	
	# 设置标记位置（相对于MapImage）
	var marker_x: float = rel_x * map_original_size.x - 6
	var marker_y: float = rel_y * map_original_size.y - 6
	
	player_marker.visible = true
	player_marker.position = Vector2(marker_x, marker_y)
	
	# 玩家方向箭头
	player_arrow.visible = true
	player_arrow.position = Vector2(marker_x - 2, marker_y - 14)
