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

# TileMap地图参数（新）
var _map_tile_offset: Vector2i = Vector2i.ZERO  # 地图瓦片偏移
var _map_tile_scale: int = 2  # 每个瓦片中多少像素
var _tile_size: int = 64  # 瓦片大小（像素）
var _terrain_layer: TileMapLayer = null  # 保存TerrainLayer引用用于坐标转换

# 大图模式参数
var _full_map_mode: bool = false
var _full_map_world_size: Vector2 = Vector2.ZERO  # 大图在世界中的显示尺寸
var _full_map_center: Vector2 = Vector2.ZERO  # 大图中心的世界坐标


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	background.visible = false
	map_panel.visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 添加到组，方便其他脚本检测大地图是否打开
	add_to_group("map_ui")
	# 连接InputManager的action_pressed信号
	if InputManager:
		InputManager.action_pressed.connect(_on_input_action_pressed)
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


func _on_input_action_pressed(action: String) -> void:
	## 处理InputManager的action_pressed信号
	if action == "map":
		# M键打开或关闭大地图
		toggle()


func _unhandled_input(event: InputEvent) -> void:
	# 移除硬编码的M键检测，改用InputManager的action_pressed信号
	pass


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
	# 获取TileMap地形系统
	var main = get_tree().current_scene
	if not main:
		print("[MapUI] 错误: 找不到主场景")
		return
	
	# 查找TerrainMap节点（可能在WorldLayer下）
	var terrain_map = null
	if main.has_node("WorldLayer/TerrainMap"):
		terrain_map = main.get_node("WorldLayer/TerrainMap")
	elif main.has_node("TerrainMap"):
		terrain_map = main.get_node("TerrainMap")
	else:
		# 递归查找TerrainMap
		terrain_map = _find_node_by_name(main, "TerrainMap")
	
	if not terrain_map:
		print("[MapUI] 错误: 找不到TerrainMap节点")
		return
	
	# 获取TerrainLayer
	var terrain_layer = null
	if terrain_map.has_node("TerrainLayer"):
		terrain_layer = terrain_map.get_node("TerrainLayer")
	elif terrain_map.has_method("get_terrain_layer"):
		terrain_layer = terrain_map.get_terrain_layer()
	
	if not terrain_layer or not terrain_layer is TileMapLayer:
		print("[MapUI] 错误: 找不到TerrainLayer")
		return
	
	# 保存TerrainLayer引用用于后续坐标转换
	_terrain_layer = terrain_layer
	
	# 从TileSet获取实际瓦片大小
	var tile_set = terrain_layer.tile_set
	if tile_set:
		_tile_size = tile_set.tile_size.x
		print("[MapUI] 实际瓦片大小: ", _tile_size)
	else:
		_tile_size = 64
		print("[MapUI] 警告: 无法获取TileSet，使用默认瓦片大小64")
	
	# 使用固定的地图范围（从0,0开始，确保地图左上角对应世界坐标0,0）
	# 地图大小：400x300瓦片（与terrain_map.gd中的配置一致）
	const MAP_WIDTH_TILES = 400
	const MAP_HEIGHT_TILES = 300
	var map_start = Vector2i(0, 0)
	var map_size = Vector2i(MAP_WIDTH_TILES, MAP_HEIGHT_TILES)
	
	print("[MapUI] 使用固定地图范围: ", map_start, " 大小: ", map_size)
	
	# 生成简化地图纹理（每个瓦片一个像素，可缩放）
	var map_scale = 2  # 每个瓦片中2x2像素
	var img_w = map_size.x * map_scale
	var img_h = map_size.y * map_scale
	if img_w < 100: img_w = 100
	if img_h < 100: img_h = 100
	
	var img := Image.create(img_w, img_h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.08, 0.08, 0.1, 1))
	
	# 遍历所有瓦片，根据源ID绘制颜色
	var tile_colors = _get_tile_color_map()
	for x in range(map_size.x):
		for y in range(map_size.y):
			var tile_pos = Vector2i(map_start.x + x, map_start.y + y)
			var source_id = terrain_layer.get_cell_source_id(tile_pos)
			if source_id >= 0:
				var color = tile_colors.get(source_id, Color(0.4, 0.5, 0.3))
				# 绘制map_scale x map_scale像素块
				for dx in range(map_scale):
					for dy in range(map_scale):
						var px = x * map_scale + dx
						var py = y * map_scale + dy
						if px >= 0 and px < img_w and py >= 0 and py < img_h:
							img.set_pixel(px, py, color)
	
	_map_texture = ImageTexture.create_from_image(img)
	map_image.texture = _map_texture
	map_image.custom_minimum_size = Vector2(img_w, img_h)
	map_original_size = Vector2(img_w, img_h)
	_map_generated = true
	
	# 保存地图参数用于坐标映射（从0,0开始，所以偏移为0）
	_map_tile_offset = map_start
	_map_tile_scale = map_scale
	
	print("[MapUI] TileMap地图纹理生成完成: %dx%d" % [img_w, img_h])


func _find_node_by_name(root: Node, name: String) -> Node:
	# 递归查找指定名称的节点
	if root.name == name:
		return root
	for child in root.get_children():
		var result = _find_node_by_name(child, name)
		if result:
			return result
	return null


func _get_tile_color_map() -> Dictionary:
	# 瓦片源ID到颜色的映射（根据你的TileSet调整）
	# 这里使用默认颜色，你可以根据实际瓦片源ID自定义
	return {
		0: Color(0.3, 0.55, 0.25),   # 草地
		1: Color(0.55, 0.42, 0.28),   # 泥土
		2: Color(0.5, 0.5, 0.55),     # 石头
		3: Color(0.78, 0.7, 0.52),    # 沙地
		4: Color(0.2, 0.45, 0.7),     # 水
		5: Color(0.55, 0.54, 0.58),   # 混凝土
		6: Color(0.25, 0.25, 0.28),   # 沥青
		7: Color(0.25, 0.4, 0.2),     # 森林地面
	}


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
	
	if map_original_size.x <= 0 or map_original_size.y <= 0:
		return
	
	if not _terrain_layer:
		return
	
	# 关键修复：将玩家全局坐标转换为TerrainLayer的本地坐标，再转瓦片坐标
	var local_pos = _terrain_layer.to_local(player.position)
	var tile_pos = _terrain_layer.local_to_map(local_pos)
	
	# 相对于地图偏移的瓦片坐标
	var relative_tile = tile_pos - _map_tile_offset
	
	# 映射到地图像素坐标
	var marker_x: float = relative_tile.x * _map_tile_scale - 6
	var marker_y: float = relative_tile.y * _map_tile_scale - 6
	
	player_marker.visible = true
	player_marker.position = Vector2(marker_x, marker_y)
	
	# 玩家方向箭头
	player_arrow.visible = true
	player_arrow.position = Vector2(marker_x - 2, marker_y - 14)


# ==================== 地图边界绘制 ====================

func _draw_map_border(img: Image, map_w: int, map_h: int, scale_x: float, scale_y: float, min_screen_x: float, min_screen_y: float, img_w: int, img_h: int) -> void:
	# 计算等距地图四个顶点的屏幕坐标
	# 顶部顶点：(0, 0)
	var top_x: float = (0 - 0) * scale_x - min_screen_x + 10
	var top_y: float = (0 + 0) * scale_y - min_screen_y + 10
	# 右侧顶点：(map_w-1, 0)
	var right_x: float = (map_w - 1 - 0) * scale_x - min_screen_x + 10
	var right_y: float = (map_w - 1 + 0) * scale_y - min_screen_y + 10
	# 底部顶点：(map_w-1, map_h-1)
	var bottom_x: float = (map_w - 1 - (map_h - 1)) * scale_x - min_screen_x + 10
	var bottom_y: float = (map_w - 1 + (map_h - 1)) * scale_y - min_screen_y + 10
	# 左侧顶点：(0, map_h-1)
	var left_x: float = (0 - (map_h - 1)) * scale_x - min_screen_x + 10
	var left_y: float = (0 + (map_h - 1)) * scale_y - min_screen_y + 10
	
	# 绘制边界外的阴影（边界外区域变暗）
	_draw_border_shadow(img, top_x, top_y, right_x, right_y, bottom_x, bottom_y, left_x, left_y, img_w, img_h)
	
	# 绘制外层边框（金色，较粗）
	var border_color_outer: Color = Color(1.0, 0.85, 0.3, 0.9)
	_draw_line(img, top_x, top_y, right_x, right_y, border_color_outer, 3)
	_draw_line(img, right_x, right_y, bottom_x, bottom_y, border_color_outer, 3)
	_draw_line(img, bottom_x, bottom_y, left_x, left_y, border_color_outer, 3)
	_draw_line(img, left_x, left_y, top_x, top_y, border_color_outer, 3)
	
	# 绘制内层边框（白色，较细）
	var border_color_inner: Color = Color(0.95, 0.95, 0.9, 0.8)
	_draw_line(img, top_x, top_y, right_x, right_y, border_color_inner, 1)
	_draw_line(img, right_x, right_y, bottom_x, bottom_y, border_color_inner, 1)
	_draw_line(img, bottom_x, bottom_y, left_x, left_y, border_color_inner, 1)
	_draw_line(img, left_x, left_y, top_x, top_y, border_color_inner, 1)
	
	# 在四个顶点绘制标记点
	var corner_color: Color = Color(1.0, 0.9, 0.4, 1.0)
	_draw_corner_marker(img, top_x, top_y, corner_color)
	_draw_corner_marker(img, right_x, right_y, corner_color)
	_draw_corner_marker(img, bottom_x, bottom_y, corner_color)
	_draw_corner_marker(img, left_x, left_y, corner_color)
	
	print("[MapUI] 地图边界绘制完成")


func _draw_border_shadow(img: Image, top_x: float, top_y: float, right_x: float, right_y: float, bottom_x: float, bottom_y: float, left_x: float, left_y: float, img_w: int, img_h: int) -> void:
	# 绘制边界外的阴影效果（边界外区域变暗）
	# 使用简单的扫描线算法，判断每个像素是否在菱形内
	var shadow_color: Color = Color(0, 0, 0, 0.4)
	
	# 为了性能，只处理边界附近的区域
	var min_x: int = max(0, int(min(top_x, left_x) - 10))
	var max_x: int = min(img_w, int(max(right_x, bottom_x) + 10))
	var min_y: int = max(0, int(top_y - 10))
	var max_y: int = min(img_h, int(bottom_y + 10))
	
	for px in range(min_x, max_x):
		for py in range(min_y, max_y):
			# 判断点是否在菱形内（使用叉积法）
			if not _point_in_diamond(px, py, top_x, top_y, right_x, right_y, bottom_x, bottom_y, left_x, left_y):
				var original: Color = img.get_pixel(px, py)
				img.set_pixel(px, py, original.lerp(shadow_color, shadow_color.a))


func _point_in_diamond(px: float, py: float, top_x: float, top_y: float, right_x: float, right_y: float, bottom_x: float, bottom_y: float, left_x: float, left_y: float) -> bool:
	# 判断点是否在菱形内（使用叉积法，凸多边形）
	# 检查点是否在所有边的同一侧
	var d1: float = _cross_product(px, py, top_x, top_y, right_x, right_y)
	var d2: float = _cross_product(px, py, right_x, right_y, bottom_x, bottom_y)
	var d3: float = _cross_product(px, py, bottom_x, bottom_y, left_x, left_y)
	var d4: float = _cross_product(px, py, left_x, left_y, top_x, top_y)
	
	var has_neg: bool = (d1 < 0) or (d2 < 0) or (d3 < 0) or (d4 < 0)
	var has_pos: bool = (d1 > 0) or (d2 > 0) or (d3 > 0) or (d4 > 0)
	
	return not (has_neg and has_pos)


func _cross_product(px: float, py: float, x1: float, y1: float, x2: float, y2: float) -> float:
	# 计算叉积 (x2-x1)*(py-y1) - (y2-y1)*(px-x1)
	return (x2 - x1) * (py - y1) - (y2 - y1) * (px - x1)


func _draw_line(img: Image, x1: float, y1: float, x2: float, y2: float, color: Color, thickness: int) -> void:
	# 绘制直线（Bresenham算法）
	var dx: float = abs(x2 - x1)
	var dy: float = abs(y2 - y1)
	var sx: float = 1.0 if x1 < x2 else -1.0
	var sy: float = 1.0 if y1 < y2 else -1.0
	var err: float = dx - dy
	
	var px: float = x1
	var py: float = y1
	
	while true:
		# 绘制厚度
		for t_x in range(-thickness, thickness + 1):
			for t_y in range(-thickness, thickness + 1):
				var draw_x: int = int(px) + t_x
				var draw_y: int = int(py) + t_y
				if draw_x >= 0 and draw_x < img.get_width() and draw_y >= 0 and draw_y < img.get_height():
					img.set_pixel(draw_x, draw_y, color)
		
		if abs(px - x2) < 0.5 and abs(py - y2) < 0.5:
			break
		
		var e2: float = 2.0 * err
		if e2 > -dy:
			err -= dy
			px += sx
		if e2 < dx:
			err += dx
			py += sy


func _draw_corner_marker(img: Image, x: float, y: float, color: Color) -> void:
	# 在顶点绘制一个小方块标记
	var size: int = 4
	for dx in range(-size, size + 1):
		for dy in range(-size, size + 1):
			var px: int = int(x) + dx
			var py: int = int(y) + dy
			if px >= 0 and px < img.get_width() and py >= 0 and py < img.get_height():
				img.set_pixel(px, py, color)
