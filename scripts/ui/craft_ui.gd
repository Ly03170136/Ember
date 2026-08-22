extends Control
## 制作UI：显示所有可制作配方，E键打开/关闭

var inventory: Node = null
var is_open: bool = false
var current_station: String = ""  # 当前工作站：""=徒手, "workbench"=工作台, "campfire"=篝火
var current_category: String = "all"  # 当前分类

# 缓存引用
var _cached_player: Node2D = null
var _cached_world_layer: Node = null

# UI元素缓存
var _cached_items: Array = []  # 缓存的配方UI元素
var _max_cached_items: int = 50  # 最大缓存数量

@onready var panel: Panel = $Panel
@onready var scroll: ScrollContainer = $Panel/Scroll
@onready var recipe_list: VBoxContainer = $Panel/Scroll/RecipeList
@onready var title_label: Label = $Panel/Header/TitleLabel
@onready var station_label: Label = $Panel/Header/StationLabel
@onready var close_btn: Button = $Panel/Header/CloseBtn

# 分类按钮
@onready var all_btn: Button = $Panel/CategoryBar/AllBtn
@onready var tool_btn: Button = $Panel/CategoryBar/ToolBtn
@onready var weapon_btn: Button = $Panel/CategoryBar/WeaponBtn
@onready var food_btn: Button = $Panel/CategoryBar/FoodBtn
@onready var med_btn: Button = $Panel/CategoryBar/MedBtn
@onready var mat_btn: Button = $Panel/CategoryBar/MatBtn


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	if all_btn:
		all_btn.pressed.connect(_on_category_pressed.bind("all"))
	if tool_btn:
		tool_btn.pressed.connect(_on_category_pressed.bind("tool"))
	if weapon_btn:
		weapon_btn.pressed.connect(_on_category_pressed.bind("weapon"))
	if food_btn:
		food_btn.pressed.connect(_on_category_pressed.bind("food"))
	if med_btn:
		med_btn.pressed.connect(_on_category_pressed.bind("medicine"))
	if mat_btn:
		mat_btn.pressed.connect(_on_category_pressed.bind("material"))


func _precreate_cached_items() -> void:
	# 预创建UI元素，避免打开菜单时卡顿
	for i in range(_max_cached_items):
		var item: HBoxContainer = HBoxContainer.new()
		item.custom_minimum_size = Vector2(0, 44)
		item.add_theme_constant_override("separation", 10)
		item.visible = false
		# 物品颜色图标
		var icon: ColorRect = ColorRect.new()
		icon.custom_minimum_size = Vector2(36, 36)
		item.add_child(icon)
		# 名称和材料
		var info: VBoxContainer = VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_label: Label = Label.new()
		name_label.add_theme_font_size_override("font_size", 14)
		info.add_child(name_label)
		var mat_label: Label = Label.new()
		mat_label.add_theme_font_size_override("font_size", 11)
		mat_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		info.add_child(mat_label)
		item.add_child(info)
		# 制作按钮
		var craft_btn: Button = Button.new()
		craft_btn.text = "制作"
		craft_btn.custom_minimum_size = Vector2(65, 36)
		craft_btn.pressed.connect(_on_craft_button_pressed.bind(craft_btn))
		item.add_child(craft_btn)
		recipe_list.add_child(item)
		# 存储引用
		_cached_items.append({
			"item": item,
			"icon": icon,
			"name_label": name_label,
			"mat_label": mat_label,
			"craft_btn": craft_btn,
			"recipe_id": ""
		})


func _get_cached_player() -> Node2D:
	# 获取并缓存玩家引用
	if not _cached_player or not is_instance_valid(_cached_player):
		_cached_player = get_tree().get_first_node_in_group("player")
	return _cached_player


func _get_cached_world_layer() -> Node:
	# 获取并缓存WorldLayer引用
	if not _cached_world_layer or not is_instance_valid(_cached_world_layer):
		var world: Node = get_tree().current_scene
		if world:
			_cached_world_layer = world.get_node_or_null("WorldLayer")
	return _cached_world_layer


func _on_input_action_pressed(action: String) -> void:
	## 处理InputManager的action_pressed信号
	if action == "craft":
		# E键打开或关闭制作菜单
		toggle()


func _unhandled_input(event: InputEvent) -> void:
	# 移除硬编码的E键检测，改用InputManager的action_pressed信号
	pass


func _input(event: InputEvent) -> void:
	# 菜单打开时直接处理滚轮事件，确保菜单能正常滚动
	if not is_open:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			scroll.scroll_vertical = max(0, scroll.scroll_vertical - 50)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var scroll_bar = scroll.get_v_scroll_bar()
			if scroll_bar:
				scroll.scroll_vertical = min(scroll_bar.max_value, scroll.scroll_vertical + 50)
			get_viewport().set_input_as_handled()


func toggle() -> void:
	if not is_open:
		var station: String = _get_nearby_station()
		current_station = station
		if station == "":
			_show_notification("当前为徒手制作，靠近工作台可解锁更多配方")
	is_open = not is_open
	panel.visible = is_open
	if AudioManager:
		if is_open:
			AudioManager.play_sfx(AudioManager.SFX.UI_OPEN)
		else:
			AudioManager.play_sfx(AudioManager.SFX.UI_CLOSE)
	if is_open:
		mouse_filter = Control.MOUSE_FILTER_STOP
		move_to_front()
		if station_label:
			var station_names: Dictionary = {"workbench": "工作台", "campfire": "篝火", "kitchen": "厨房", "furnace": "熔炉", "med_station": "医疗站", "": "徒手"}
			station_label.text = "当前: %s" % station_names.get(current_station, current_station)
		# 关闭其他菜单
		var hud: Node = get_parent()
		if hud:
			var build_ui = hud.get_node_or_null("BuildUI")
			if build_ui and build_ui.is_open:
				build_ui.is_open = false
				build_ui.panel.visible = false
				build_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
				if build_ui.is_placing:
					build_ui._cancel_placing()
			var inventory_ui = hud.get_node_or_null("InventoryUI")
			if inventory_ui and inventory_ui.is_open:
				inventory_ui.is_open = false
				inventory_ui.panel.visible = false
				inventory_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
		refresh()
	else:
		mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_category_pressed(category: String) -> void:
	current_category = category
	refresh()


func set_inventory(inv: Node) -> void:
	inventory = inv


func set_station(station: String) -> void:
	current_station = station
	if station_label:
		if station == "":
			station_label.text = "当前: 徒手制作"
		else:
			station_label.text = "当前: %s" % station
	if is_open:
		refresh()


func refresh() -> void:
	if not inventory:
		# 隐藏所有缓存的UI元素
		for cached in _cached_items:
			cached.item.visible = false
		return
	var item_index: int = 0
	for recipe_id: String in RecipeDB.get_all_recipes().keys():
		if item_index >= _max_cached_items:
			break
		var recipe: Dictionary = RecipeDB.get_recipe(recipe_id)
		if recipe.is_empty():
			continue
		# 检查工作站条件
		var recipe_station: String = RecipeDB.get_recipe_station(recipe_id)
		if recipe_station != "" and recipe_station != current_station:
			continue
		# 检查分类过滤
		if current_category != "all":
			var result_item: Dictionary = ItemDB.get_item(recipe.result)
			if not result_item.is_empty():
				var item_type: int = result_item.get("type", -1)
				var type_match: bool = false
				match current_category:
					"tool":
						type_match = (item_type == ItemDB.ItemType.TOOL)
					"weapon":
						type_match = (item_type == ItemDB.ItemType.WEAPON)
					"food":
						type_match = (item_type == ItemDB.ItemType.FOOD)
					"medicine":
						type_match = (item_type == ItemDB.ItemType.MEDICINE)
					"material":
						type_match = (item_type == ItemDB.ItemType.RESOURCE)
				if not type_match:
					continue
		var can_make: bool = RecipeDB.can_craft(recipe_id, inventory, current_station)
		# 使用缓存的UI元素，只更新内容
		var cached = _cached_items[item_index]
		cached.recipe_id = recipe_id
		cached.item.visible = true
		cached.icon.color = ItemDB.get_color(recipe.result)
		cached.name_label.text = recipe.name
		if not can_make:
			cached.name_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		else:
			cached.name_label.add_theme_color_override("font_color", Color.WHITE)
		# 更新材料信息
		var mat_text: String = ""
		for mat_id in recipe.ingredients.keys():
			var needed: int = recipe.ingredients[mat_id]
			var have: int = inventory.get_item_count(mat_id)
			var status: String = "✓" if have >= needed else "✗"
			mat_text += "%s %s %d/%d  " % [status, ItemDB.get_item_name(mat_id), have, needed]
		cached.mat_label.text = mat_text
		# 更新制作按钮
		cached.craft_btn.disabled = not can_make
		cached.craft_btn.set_meta("recipe_id", recipe_id)
		item_index += 1
	# 隐藏剩余的缓存UI元素
	for i in range(item_index, _max_cached_items):
		_cached_items[i].item.visible = false


func _on_craft_button_pressed(btn: Button) -> void:
	var recipe_id: String = btn.get_meta("recipe_id", "")
	if recipe_id != "":
		_on_craft_pressed(recipe_id)


func _on_craft_pressed(recipe_id: String) -> void:
	if not inventory:
		return
	if RecipeDB.craft(recipe_id, inventory):
		refresh()


func _get_nearby_station() -> String:
	var player: Node2D = _get_cached_player()
	if not player:
		return ""
	const INTERACT_RANGE := 120.0
	var nearest_station: String = ""
	var nearest_dist: float = INTERACT_RANGE
	# 使用组查询获取所有建筑，而不是遍历WorldLayer的所有子节点
	var buildings: Array = get_tree().get_nodes_in_group("building")
	for building in buildings:
		if building.has_method("get_building_id"):
			var building_id: String = building.get_building_id()
			var station_type: String = ""
			match building_id:
				"workbench", "electric_workbench":
					station_type = "workbench"
				"campfire":
					station_type = "campfire"
				"kitchen":
					station_type = "kitchen"
				"furnace", "electric_furnace":
					station_type = "furnace"
				"med_station":
					station_type = "med_station"
			if station_type != "":
				var dist: float = player.position.distance_to(building.position)
				if dist < nearest_dist:
					nearest_dist = dist
					nearest_station = station_type
	return nearest_station


func _show_notification(text: String) -> void:
	var main: Node = get_tree().current_scene
	if main and main.has_method("show_notification"):
		main.show_notification(text)
