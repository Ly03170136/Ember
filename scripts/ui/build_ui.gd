extends Control
## 建造UI：B键打开建筑列表，选择后进入放置模式

var inventory: Node = null
var is_open: bool = false
var selected_building: String = ""
var is_placing: bool = false
var current_category: String = "all"

# UI元素缓存
var _cached_items: Array = []  # 缓存的建筑UI元素
var _max_cached_items: int = 50  # 最大缓存数量

@onready var panel: Panel = $Panel
@onready var scroll: ScrollContainer = $Panel/Scroll
@onready var building_list: VBoxContainer = $Panel/Scroll/BuildingList
@onready var title_label: Label = $Panel/Header/TitleLabel
@onready var close_btn: Button = $Panel/Header/CloseBtn
@onready var preview: Sprite2D = null  # 放置预览精灵

signal building_placed(building_id: String, position: Vector2)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group("build_ui")
	add_to_group("ui_menu")
	# 预创建UI元素缓存
	_precreate_cached_items()
	# 连接InputManager的action_pressed信号
	if InputManager:
		InputManager.action_pressed.connect(_on_input_action_pressed)
	# 连接关闭按钮
	if close_btn:
		close_btn.pressed.connect(toggle)
	# 连接分类按钮
	var category_bar: HBoxContainer = get_node_or_null("Panel/CategoryBar")
	if category_bar:
		for btn in category_bar.get_children():
			if btn is Button:
				var cat: String = btn.name.to_lower().replace("btn", "")
				btn.pressed.connect(_on_category_pressed.bind(cat))


func _precreate_cached_items() -> void:
	# 预创建UI元素，避免打开菜单时卡顿
	for i in range(_max_cached_items):
		var item: HBoxContainer = HBoxContainer.new()
		item.custom_minimum_size = Vector2(0, 44)
		item.add_theme_constant_override("separation", 8)
		item.visible = false
		# 建筑图标（临时用颜色方块，避免图标生成导致崩溃）
		var icon: ColorRect = ColorRect.new()
		icon.custom_minimum_size = Vector2(32, 32)
		item.add_child(icon)
		# 名称和材料
		var info: VBoxContainer = VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_label: Label = Label.new()
		name_label.add_theme_font_size_override("font_size", 14)
		info.add_child(name_label)
		var mat_label: Label = Label.new()
		mat_label.add_theme_font_size_override("font_size", 11)
		info.add_child(mat_label)
		item.add_child(info)
		# 选择按钮
		var select_btn: Button = Button.new()
		select_btn.text = "建造"
		select_btn.custom_minimum_size = Vector2(60, 32)
		select_btn.pressed.connect(_on_select_button_pressed.bind(select_btn))
		item.add_child(select_btn)
		building_list.add_child(item)
		# 存储引用
		_cached_items.append({
			"item": item,
			"icon": icon,
			"name_label": name_label,
			"mat_label": mat_label,
			"select_btn": select_btn,
			"building_id": ""
		})


func _on_category_pressed(category: String) -> void:
	current_category = category
	if is_open:
		refresh()


func _process(delta: float) -> void:
	# 放置模式下每帧更新预览位置，确保跟随鼠标
	if is_placing and preview and is_instance_valid(preview):
		_update_preview_position()


func _input(event: InputEvent) -> void:
	# 菜单打开时处理滚轮事件，确保菜单能正常滚动
	if is_open and not is_placing:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				scroll.scroll_vertical = max(0, scroll.scroll_vertical - 50)
				get_viewport().set_input_as_handled()
				return
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				var scroll_bar = scroll.get_v_scroll_bar()
				if scroll_bar:
					scroll.scroll_vertical = min(scroll_bar.max_value, scroll.scroll_vertical + 50)
				get_viewport().set_input_as_handled()
				return
	# 放置模式下用_input处理鼠标事件，确保不被其他节点拦截
	if not is_placing:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_try_place_building()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_placing()
			get_viewport().set_input_as_handled()


func _on_input_action_pressed(action: String) -> void:
	## 处理InputManager的action_pressed信号
	if action == "build":
		# B键打开或关闭建造菜单
		if is_placing:
			_cancel_placing()
			toggle()  # 取消后重新打开建造菜单
		else:
			toggle()
	elif action == "pause" and is_placing:
		# ESC键只在放置模式下取消放置
		_cancel_placing()


func _unhandled_input(event: InputEvent) -> void:
	# 移除硬编码的B键和ESC键检测，改用InputManager的action_pressed信号
	pass


func toggle() -> void:
	is_open = not is_open
	panel.visible = is_open
	# 播放菜单音效
	if AudioManager:
		if is_open:
			AudioManager.play_sfx(AudioManager.SFX.UI_OPEN)
		else:
			AudioManager.play_sfx(AudioManager.SFX.UI_CLOSE)
	if is_open:
		# 打开时拦截鼠标事件并移到最顶层
		mouse_filter = Control.MOUSE_FILTER_STOP
		move_to_front()
		# 关闭其他菜单（直接设置状态，避免递归调用）
		var hud: Node = get_parent()
		if hud:
			var craft_ui = hud.get_node_or_null("CraftUI")
			if craft_ui and craft_ui.is_open:
				craft_ui.is_open = false
				craft_ui.panel.visible = false
				craft_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var inventory_ui = hud.get_node_or_null("InventoryUI")
			if inventory_ui and inventory_ui.is_open:
				inventory_ui.is_open = false
				inventory_ui.panel.visible = false
				inventory_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
		refresh()
	else:
		# 关闭时忽略鼠标事件
		mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_inventory(inv: Node) -> void:
	inventory = inv


func refresh() -> void:
	if not inventory:
		# 隐藏所有缓存的UI元素
		for cached in _cached_items:
			cached.item.visible = false
		return
	var item_index: int = 0
	# 遍历所有建筑
	for building_id: String in BuildingDB.get_all_buildings().keys():
		if item_index >= _max_cached_items:
			break
		var building: Dictionary = BuildingDB.get_building(building_id)
		if building.is_empty():
			continue
		# 分类过滤
		if current_category != "all":
			var building_cat: String = building.get("category", "")
			var cat_match: bool = false
			match current_category:
				"basic":
					cat_match = (building_cat == "basic")
				"prod":
					cat_match = (building_cat == "production" or building_cat == "crafting")
				"farm":
					cat_match = (building_cat == "farming")
				"def":
					cat_match = (building_cat == "defense")
				"power":
					cat_match = (building_cat == "power")
			if not cat_match:
				continue
		var can_make: bool = BuildingDB.can_build(building_id, inventory)
		# 使用缓存的UI元素，只更新内容
		var cached = _cached_items[item_index]
		cached.building_id = building_id
		cached.item.visible = true
		cached.icon.color = BuildingDB.get_building_color(building_id)
		cached.name_label.text = building.name
		# 更新材料信息
		var mat_text: String = ""
		for mat_id in building.cost.keys():
			var needed: int = building.cost[mat_id]
			var have: int = inventory.get_item_count(mat_id)
			var status: String = "✓" if have >= needed else "✗"
			mat_text += "%s %s %d/%d  " % [status, ItemDB.get_item_name(mat_id), have, needed]
		cached.mat_label.text = mat_text
		# 更新选择按钮
		cached.select_btn.disabled = not can_make
		cached.select_btn.set_meta("building_id", building_id)
		item_index += 1
	# 隐藏剩余的缓存UI元素
	for i in range(item_index, _max_cached_items):
		_cached_items[i].item.visible = false


func _on_select_button_pressed(btn: Button) -> void:
	var building_id: String = btn.get_meta("building_id", "")
	if building_id != "":
		_on_select_building(building_id)


func _on_select_building(building_id: String) -> void:
	if not inventory:
		return
	var can_build: bool = BuildingDB.can_build(building_id, inventory)
	if not can_build:
		return
	selected_building = building_id
	is_open = false
	panel.visible = false
	_start_placing()
	# 阻止按钮点击事件传播，避免立即触发放置
	get_viewport().set_input_as_handled()


func _start_placing() -> void:
	is_placing = true
	# 放置模式下不拦截鼠标事件，让_unhandled_input能收到左右键
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 创建预览精灵，添加到世界层
	preview = Sprite2D.new()
	var data: Dictionary = BuildingDB.get_building(selected_building)
	preview.modulate = data.color
	preview.texture = _make_preview_texture(selected_building)
	preview.z_index = 100
	var main: Node = get_tree().current_scene
	var world_layer: Node = main.get_node_or_null("WorldLayer")
	if world_layer:
		world_layer.add_child(preview)
	else:
		main.add_child(preview)
	_update_preview_position()


func _get_world_mouse_pos() -> Vector2:
	# 通过相机获取世界鼠标位置（DPI缩放下更准确）
	var player: Node = GameManager.get_local_player()
	if player and player.has_node("Camera2D"):
		var camera: Camera2D = player.get_node("Camera2D")
		return camera.get_global_mouse_position()
	# 回退方案：通过视口和画布变换计算
	var viewport_mouse: Vector2 = get_viewport().get_mouse_position()
	var canvas_transform: Transform2D = get_viewport().get_canvas_transform()
	return canvas_transform.affine_inverse() * viewport_mouse


func _update_preview_position() -> void:
	if not preview:
		return
	var mouse_pos: Vector2 = _get_world_mouse_pos()
	# 对齐到网格（32像素一格）
	var grid_size: float = 32.0
	var snapped_pos: Vector2 = Vector2(
		round(mouse_pos.x / grid_size) * grid_size,
		round(mouse_pos.y / grid_size) * grid_size
	)
	preview.global_position = snapped_pos
	# 检查是否能放置（简单检查：不与其他建筑重叠）
	var can_place: bool = _check_can_place(snapped_pos)
	preview.modulate = Color(0.3, 1, 0.3, 0.7) if can_place else Color(1, 0.3, 0.3, 0.7)


func _check_can_place(pos: Vector2) -> bool:
	# 简单检查：不与其他建筑重叠
	var size: Vector2 = BuildingDB.get_building_size(selected_building)
	var buildings: Array = get_tree().get_nodes_in_group("building")
	for b: Node2D in buildings:
		# 检查节点是否有building_id属性（wall等节点可能没有）
		var b_id = b.get("building_id")
		if b_id == null:
			continue
		var b_pos: Vector2 = b.global_position
		var b_size: Vector2 = BuildingDB.get_building_size(b_id)
		if abs(pos.x - b_pos.x) < (size.x + b_size.x) / 2 and abs(pos.y - b_pos.y) < (size.y + b_size.y) / 2:
			return false
	return true


func _try_place_building() -> void:
	if not is_placing or selected_building == "":
		return
	var mouse_pos: Vector2 = _get_world_mouse_pos()
	var grid_size: float = 32.0
	var snapped_pos: Vector2 = Vector2(
		round(mouse_pos.x / grid_size) * grid_size,
		round(mouse_pos.y / grid_size) * grid_size
	)
	var player_pos: Vector2 = GameManager.get_local_player().position if GameManager.get_local_player() else Vector2.ZERO
	print("[BuildUI] 放置调试: mouse=", mouse_pos, " snapped=", snapped_pos, " player=", player_pos)
	if not _check_can_place(snapped_pos):
		print("[BuildUI] 无法放置：位置冲突 ", snapped_pos)
		return
	if not BuildingDB.can_build(selected_building, inventory):
		print("[BuildUI] 无法放置：材料不足 ", selected_building)
		return
	# 消耗材料并放置建筑
	BuildingDB.consume_build_materials(selected_building, inventory)
	print("[BuildUI] 放置建筑: ", selected_building, " at ", snapped_pos, " is_server=", GameManager.is_server)
	emit_signal("building_placed", selected_building, snapped_pos)
	# 继续放置同一种建筑
	_update_preview_position()


func _cancel_placing() -> void:
	is_placing = false
	selected_building = ""
	# 取消放置后回到关闭状态，忽略鼠标事件
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if preview and is_instance_valid(preview):
		preview.queue_free()
		preview = null


func _make_preview_texture(building_id: String) -> Texture2D:
	# 使用建筑图标作为预览纹理
	var icon: Texture2D = ArtAssets.get_building_icon(building_id)
	if icon:
		return icon
	# 回退：生成纯色矩形
	var size: Vector2 = BuildingDB.get_building_size(building_id)
	var w: int = int(size.x)
	var h: int = int(size.y)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0.8))
	return ImageTexture.create_from_image(img)
