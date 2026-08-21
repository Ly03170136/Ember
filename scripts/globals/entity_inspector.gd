extends Node
## 实体检查器（Entity Inspector）- 《余烬 EMBER》
## 功能：
## 1. 按F11开启/关闭检查器模式
## 2. 在检查器模式下，点击场景中的实体可选中
## 3. 显示选中实体的详细信息（属性、状态、组件、变量）
## 4. 支持查看玩家、NPC、丧尸、物品、建筑等所有实体

# ==================== 信号 ====================
signal entity_selected(entity: Node)
signal inspector_toggled(enabled: bool)

# ==================== 配置 ====================
const PANEL_WIDTH: int = 320
const PANEL_MARGIN: int = 10
const MAX_VARIABLES: int = 50  # 最多显示的变量数量

# ==================== 状态变量 ====================
var is_enabled: bool = false
var selected_entity: Node = null
var _canvas_layer: CanvasLayer = null
var _inspector_panel: Control = null
var _info_label: Label = null
var _scroll_container: ScrollContainer = null
var _content_vbox: VBoxContainer = null
var _hint_label: Label = null

# ==================== 生命周期 ====================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[EntityInspector] 实体检查器系统已启动，按F11开启/关闭")
	GameLogger.info("实体检查器系统已启动，按F11开启/关闭", "Debug")
	call_deferred("_create_ui")


func _input(event: InputEvent) -> void:
	## 处理输入
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			toggle()
			get_viewport().set_input_as_handled()
			return

	# 在检查器模式下，处理鼠标点击
	if is_enabled and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_select_entity(event.position)
		get_viewport().set_input_as_handled()


# ==================== 公共API ====================

func toggle() -> void:
	## 切换检查器模式
	is_enabled = not is_enabled
	if _inspector_panel:
		_inspector_panel.visible = is_enabled
	if _hint_label:
		_hint_label.visible = is_enabled
	inspector_toggled.emit(is_enabled)
	print("[EntityInspector] 实体检查器: %s" % ["关闭", "开启"][int(is_enabled)])
	if not is_enabled:
		selected_entity = null
		_update_info()


func show() -> void:
	## 显示检查器
	is_enabled = true
	if _inspector_panel:
		_inspector_panel.visible = true
	if _hint_label:
		_hint_label.visible = true
	inspector_toggled.emit(true)


func hide() -> void:
	## 隐藏检查器
	is_enabled = false
	if _inspector_panel:
		_inspector_panel.visible = false
	if _hint_label:
		_hint_label.visible = false
	selected_entity = null
	inspector_toggled.emit(false)


func select_entity(entity: Node) -> void:
	## 选中指定实体
	if entity and is_instance_valid(entity):
		selected_entity = entity
		entity_selected.emit(entity)
		_update_info()
		print("[EntityInspector] 选中实体: %s" % entity.name)


func deselect() -> void:
	## 取消选中
	selected_entity = null
	_update_info()


# ==================== 内部方法 ====================

func _try_select_entity(click_pos: Vector2) -> void:
	## 尝试选中点击位置的实体
	var main_scene = get_tree().current_scene
	if not main_scene:
		print("[EntityInspector] 未找到主场景")
		return

	# 将屏幕坐标转换为世界坐标
	# 方法1：使用get_viewport().get_camera_2d()获取当前活动相机
	var camera = get_viewport().get_camera_2d()
	var world_pos = click_pos
	if camera:
		world_pos = camera.get_global_mouse_position()
		print("[EntityInspector] 通过get_viewport找到相机，世界坐标: (%.1f, %.1f)" % [world_pos.x, world_pos.y])
	else:
		# 方法2：按类型查找Camera2D节点（使用find_children）
		var cameras = main_scene.find_children("*", "Camera2D", true, false)
		if cameras.size() > 0:
			camera = cameras[0]
			world_pos = camera.get_global_mouse_position()
			print("[EntityInspector] 通过find_children找到相机: %s，世界坐标: (%.1f, %.1f)" % [camera.name, world_pos.x, world_pos.y])
		else:
			print("[EntityInspector] 未找到相机，使用屏幕坐标: (%.1f, %.1f)" % [world_pos.x, world_pos.y])

	# 遍历所有可能的实体，找到点击位置最近的
	var candidates = []
	var all_nodes = main_scene.find_children("*", "", true, false)
	print("[EntityInspector] 找到 %d 个节点" % all_nodes.size())
	
	var node_types = {}
	for node in all_nodes:
		if not is_instance_valid(node):
			continue
		if not (node is Node2D):
			continue
		var node_name = str(node.name)
		var node_type = node.get_class()
		# 统计节点类型
		if not node_types.has(node_type):
			node_types[node_type] = 0
		node_types[node_type] += 1
		
		var node_pos = node.global_position
		var distance = world_pos.distance_to(node_pos)
		# 检查是否在点击范围内（100像素，更大范围）
		if distance < 100.0:
			# 不过滤任何节点，全部加入候选
			var priority = 0
			if node_name.begins_with("Player_") or node_name == "Player":
				priority = 100
			elif node_name.find("NPC") >= 0 or node_name.find("Citizen") >= 0 or node_name.find("Police") >= 0 or node_name.find("Human") >= 0:
				priority = 90
			elif node_name.find("Zombie") >= 0 or node_name.find("zombie") >= 0:
				priority = 80
			elif node is CharacterBody2D:
				priority = 70
			elif node is RigidBody2D:
				priority = 60
			elif node is StaticBody2D:
				priority = 50
			elif node is Node2D:
				priority = 10
			candidates.append({"node": node, "distance": distance, "priority": priority})
			print("[EntityInspector] 候选: %s (%s) 距离: %.1f 优先级: %d" % [node_name, node_type, distance, priority])

	# 输出节点类型统计
	print("[EntityInspector] 节点类型统计:")
	for node_type in node_types.keys():
		print("  %s: %d个" % [node_type, node_types[node_type]])

	# 按优先级排序，优先级相同按距离排序
	candidates.sort_custom(func(a, b):
		if a.priority != b.priority:
			return a.priority > b.priority
		return a.distance < b.distance)

	if candidates.size() > 0:
		select_entity(candidates[0].node)
		print("[EntityInspector] 选中: %s (距离: %.1f, 优先级: %d)" % [candidates[0].node.name, candidates[0].distance, candidates[0].priority])
	else:
		deselect()
		print("[EntityInspector] 未找到实体，世界坐标: (%.1f, %.1f)，100像素范围内无Node2D节点" % [world_pos.x, world_pos.y])


func _update_info() -> void:
	## 更新信息面板
	if not _content_vbox:
		return

	# 清空现有内容
	for child in _content_vbox.get_children():
		child.queue_free()

	if not selected_entity or not is_instance_valid(selected_entity):
		_add_label("未选中实体", Color(0.7, 0.7, 0.7), 12)
		_add_label("点击场景中的实体查看详情", Color(0.5, 0.5, 0.5), 10)
		return

	var entity = selected_entity

	# 基本信息
	_add_section_title("=== 基本信息 ===")
	_add_label("名称: %s" % str(entity.name), Color(1, 1, 1), 11)
	_add_label("类型: %s" % entity.get_class(), Color(1, 1, 1), 11)
	if entity is Node2D:
		_add_label("位置: (%.1f, %.1f)" % [entity.global_position.x, entity.global_position.y], Color(1, 1, 1), 11)
		_add_label("旋转: %.1f°" % entity.global_rotation_degrees, Color(1, 1, 1), 11)
		_add_label("缩放: (%.2f, %.2f)" % [entity.global_scale.x, entity.global_scale.y], Color(1, 1, 1), 11)
	_add_label("场景路径: %s" % entity.get_path(), Color(0.8, 0.8, 0.8), 9)

	# 属性（常见游戏属性）
	_add_section_title("=== 属性 ===")
	var has_game_attrs = false
	for prop_name in ["health", "max_health", "hunger", "thirst", "stamina", "attack_damage", "attack_range", "move_speed", "level", "experience"]:
		if entity.get(prop_name) != null:
			var value = entity.get(prop_name)
			_add_label("%s: %s" % [prop_name, str(value)], Color(0.9, 0.9, 0.6), 10)
			has_game_attrs = true
	if not has_game_attrs:
		_add_label("(无游戏属性)", Color(0.5, 0.5, 0.5), 10)

	# 状态
	_add_section_title("=== 状态 ===")
	var has_state = false
	for state_name in ["is_down", "is_sick", "is_attacking", "is_moving", "is_dead", "is_sprinting", "infection_complete"]:
		if entity.get(state_name) != null:
			var value = entity.get(state_name)
			var color = Color(0.6, 1, 0.6) if value else Color(1, 0.6, 0.6)
			_add_label("%s: %s" % [state_name, str(value)], color, 10)
			has_state = true
	if not has_state:
		_add_label("(无状态信息)", Color(0.5, 0.5, 0.5), 10)

	# 组件/子节点
	_add_section_title("=== 组件/子节点 ===")
	var children = entity.get_children()
	_add_label("子节点数量: %d" % children.size(), Color(1, 1, 1), 10)
	for i in range(min(children.size(), 15)):
		var child = children[i]
		_add_label("  [%d] %s (%s)" % [i, str(child.name), child.get_class()], Color(0.7, 0.9, 1), 9)
	if children.size() > 15:
		_add_label("  ... 还有 %d 个" % (children.size() - 15), Color(0.5, 0.5, 0.5), 9)

	# 变量（通过get方法获取）
	_add_section_title("=== 变量 ===")
	var var_count = 0
	var script = entity.get_script()
	if script and script is GDScript:
		# 尝试获取脚本中定义的变量
		var source = script.source_code
		if source:
			var lines = source.split("\n")
			for line in lines:
				line = line.strip_edges()
				if line.begins_with("var ") and var_count < MAX_VARIABLES:
					var eq_pos = line.find("=")
					var name_len = eq_pos - 4 if eq_pos > 0 else line.length() - 4
					var var_name = line.substr(4, name_len).strip_edges()
					if var_name and not var_name.begins_with("_"):
						var value = entity.get(var_name)
						if value != null:
							var value_str = str(value)
							if value_str.length() > 30:
								value_str = value_str.substr(0, 30) + "..."
							_add_label("%s = %s" % [var_name, value_str], Color(0.9, 0.8, 1), 9)
							var_count += 1
	if var_count == 0:
		_add_label("(无公开变量)", Color(0.5, 0.5, 0.5), 10)


func _add_section_title(text: String) -> void:
	## 添加分节标题
	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(0.6, 0.8, 1))
	label.add_theme_font_size_override("font_size", 10)
	_content_vbox.add_child(label)


func _add_label(text: String, color: Color, font_size: int) -> void:
	## 添加标签
	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content_vbox.add_child(label)


# ==================== UI创建 ====================

func _create_ui() -> void:
	## 创建实体检查器UI
	if _canvas_layer and is_instance_valid(_canvas_layer):
		_canvas_layer.queue_free()
		_canvas_layer = null

	# 创建CanvasLayer
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 1001  # 在性能监控之上
	add_child(_canvas_layer)

	# 提示标签（左上角）
	_hint_label = Label.new()
	_hint_label.text = "[实体检查器已开启] 点击实体查看详情 | F11关闭"
	_hint_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	_hint_label.add_theme_font_size_override("font_size", 11)
	_hint_label.position = Vector2(10, 10)
	_hint_label.visible = is_enabled
	_canvas_layer.add_child(_hint_label)

	# 检查器面板（右侧）
	_inspector_panel = Control.new()
	_inspector_panel.name = "EntityInspectorPanel"
	_inspector_panel.visible = is_enabled
	_inspector_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 500)
	_inspector_panel.position = Vector2(0, 0)
	# 锚定到右侧
	_inspector_panel.anchor_right = 1.0
	_inspector_panel.anchor_left = 1.0
	_inspector_panel.offset_left = -PANEL_WIDTH - PANEL_MARGIN
	_inspector_panel.offset_right = -PANEL_MARGIN
	_inspector_panel.offset_top = PANEL_MARGIN
	_inspector_panel.offset_bottom = -PANEL_MARGIN
	_canvas_layer.add_child(_inspector_panel)

	# 半透明背景面板
	var bg_panel = ColorRect.new()
	bg_panel.name = "Background"
	bg_panel.color = Color(0.1, 0.1, 0.1, 0.85)
	bg_panel.anchor_right = 1.0
	bg_panel.anchor_bottom = 1.0
	_inspector_panel.add_child(bg_panel)

	# 标题
	var title_label = Label.new()
	title_label.text = "=== 实体检查器 ==="
	title_label.add_theme_color_override("font_color", Color(1, 1, 1))
	title_label.add_theme_font_size_override("font_size", 12)
	title_label.position = Vector2(8, 8)
	title_label.size = Vector2(PANEL_WIDTH - 16, 20)
	_inspector_panel.add_child(title_label)

	# 滚动容器
	_scroll_container = ScrollContainer.new()
	_scroll_container.name = "ScrollContainer"
	_scroll_container.position = Vector2(8, 32)
	_scroll_container.size = Vector2(PANEL_WIDTH - 16, 460)
	_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_inspector_panel.add_child(_scroll_container)

	# 内容容器
	_content_vbox = VBoxContainer.new()
	_content_vbox.name = "Content"
	_content_vbox.add_theme_constant_override("separation", 2)
	_content_vbox.custom_minimum_size = Vector2(PANEL_WIDTH - 32, 0)
	_scroll_container.add_child(_content_vbox)

	# 初始内容
	_add_label("未选中实体", Color(0.7, 0.7, 0.7), 12)
	_add_label("点击场景中的实体查看详情", Color(0.5, 0.5, 0.5), 10)

	print("[EntityInspector] UI创建完成（右侧面板，F11切换，透明背景，白色字体）")
