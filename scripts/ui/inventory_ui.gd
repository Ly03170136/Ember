extends Control
## 背包UI：显示30格背包、物品、负重
## TAB键打开/关闭，支持拖拽交换物品

const SLOT_COUNT := 30
const COLUMNS := 6

var inventory: Node = null
var slot_buttons: Array = []
var is_open: bool = false
var dragged_slot: int = -1
var is_dragging: bool = false
var drag_preview: Control = null

@onready var panel: Panel = $Panel
@onready var grid: GridContainer = $Panel/VBox/Grid
@onready var weight_label: Label = $Panel/VBox/WeightLabel
@onready var title_label: Label = $Panel/VBox/TitleLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group("ui_menu")
	# 连接InputManager的action_pressed信号
	if InputManager:
		InputManager.action_pressed.connect(_on_input_action_pressed)
	# 创建格子
	grid.columns = COLUMNS
	for i in range(SLOT_COUNT):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(56, 56)
		btn.text = ""
		btn.name = "Slot_%d" % i
		btn.tooltip_text = ""
		# 末日风格格子样式
		var slot_style := StyleBoxFlat.new()
		slot_style.bg_color = Color(0.1, 0.09, 0.11, 0.92)
		slot_style.border_color = Color(0.4, 0.3, 0.15, 0.85)
		slot_style.border_width_left = 2
		slot_style.border_width_right = 2
		slot_style.border_width_top = 2
		slot_style.border_width_bottom = 2
		slot_style.corner_radius_top_left = 3
		slot_style.corner_radius_top_right = 3
		slot_style.corner_radius_bottom_left = 3
		slot_style.corner_radius_bottom_right = 3
		slot_style.content_margin_left = 3
		slot_style.content_margin_right = 3
		slot_style.content_margin_top = 3
		slot_style.content_margin_bottom = 3
		btn.add_theme_stylebox_override("normal", slot_style)
		btn.add_theme_stylebox_override("hover", slot_style)
		btn.add_theme_stylebox_override("pressed", slot_style)
		btn.add_theme_font_size_override("font_size", 12)
		btn.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7, 1))
		btn.gui_input.connect(_on_slot_gui_input.bind(i))
		grid.add_child(btn)
		slot_buttons.append(btn)
	# 创建拖拽预览
	drag_preview = Control.new()
	drag_preview.custom_minimum_size = Vector2(56, 56)
	drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var preview_icon := TextureRect.new()
	preview_icon.name = "Icon"
	preview_icon.anchor_right = 1.0
	preview_icon.anchor_bottom = 1.0
	preview_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	drag_preview.add_child(preview_icon)
	var preview_count := Label.new()
	preview_count.name = "Count"
	preview_count.anchor_right = 1.0
	preview_count.anchor_bottom = 1.0
	preview_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	preview_count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	preview_count.add_theme_font_size_override("font_size", 12)
	drag_preview.add_child(preview_count)
	drag_preview.visible = false
	add_child(drag_preview)


func _on_input_action_pressed(action: String) -> void:
	## 处理InputManager的action_pressed信号
	if action == "inventory":
		# TAB键打开或关闭背包
		toggle()


func _unhandled_input(event: InputEvent) -> void:
	# 移除硬编码的TAB键检测，改用InputManager的action_pressed信号
	pass


func _input(event: InputEvent) -> void:
	# 拖拽过程中
	if is_dragging and drag_preview and drag_preview.visible:
		if event is InputEventMouseMotion:
			drag_preview.position = get_viewport().get_mouse_position() - Vector2(28, 28)
		# 鼠标左键释放：结束拖拽，检测鼠标位置下的格子
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			var target_slot: int = _get_slot_at_mouse()
			if target_slot != -1 and target_slot != dragged_slot:
				inventory.swap_slots(dragged_slot, target_slot)
				_end_drag(true)
			else:
				_end_drag(false)
			get_viewport().set_input_as_handled()


func _get_slot_at_mouse() -> int:
	## 获取鼠标位置下的格子索引
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	for i in range(SLOT_COUNT):
		var btn: Button = slot_buttons[i]
		var btn_rect: Rect2 = btn.get_global_rect()
		# 将视口鼠标位置转换为全局位置
		var global_mouse: Vector2 = get_global_transform() * mouse_pos
		if btn_rect.has_point(global_mouse):
			return i
	return -1


func toggle() -> void:
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
		var hud: Node = get_parent()
		if hud:
			var build_ui = hud.get_node_or_null("BuildUI")
			if build_ui and build_ui.is_open:
				build_ui.is_open = false
				build_ui.panel.visible = false
				build_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
				if build_ui.is_placing:
					build_ui._cancel_placing()
			var craft_ui = hud.get_node_or_null("CraftUI")
			if craft_ui and craft_ui.is_open:
				craft_ui.is_open = false
				craft_ui.panel.visible = false
				craft_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
		refresh()
	else:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_end_drag(false)


func set_inventory(inv: Node) -> void:
	inventory = inv
	if inventory:
		inventory.inventory_changed.connect(refresh)
		refresh()


func refresh() -> void:
	if not inventory:
		return
	for i in range(SLOT_COUNT):
		var btn: Button = slot_buttons[i]
		var item: Dictionary = inventory.get_slot(i)
		if item.is_empty():
			btn.text = ""
			btn.icon = null
			btn.tooltip_text = ""
			btn.modulate = Color(0.3, 0.3, 0.35)
		else:
			var item_data: Dictionary = ItemDB.get_item(item.id)
			btn.icon = ArtAssets.get_item_icon(item.id)
			btn.modulate = Color.WHITE
			btn.text = str(item.count)
			btn.tooltip_text = "%s\n%s" % [ItemDB.get_item_name(item.id), item_data.get("desc", "")]
	# 更新负重
	var weight: float = inventory.get_total_weight()
	var max_weight: float = inventory.MAX_WEIGHT
	weight_label.text = "负重: %.1f / %.1f kg" % [weight, max_weight]
	if weight > max_weight * 0.8:
		weight_label.modulate = Color(1, 0.5, 0.3)
	else:
		weight_label.modulate = Color.WHITE


func _on_slot_gui_input(event: InputEvent, index: int) -> void:
	if not inventory or not is_open:
		return
	# 鼠标左键按下：开始拖拽
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var item: Dictionary = inventory.get_slot(index)
		if not item.is_empty():
			_start_drag(index)
			get_viewport().set_input_as_handled()


func _start_drag(index: int) -> void:
	dragged_slot = index
	is_dragging = true
	if drag_preview:
		var item: Dictionary = inventory.get_slot(index)
		if not item.is_empty():
			var icon_rect: TextureRect = drag_preview.get_node("Icon")
			var count_label: Label = drag_preview.get_node("Count")
			icon_rect.texture = ArtAssets.get_item_icon(item.id)
			count_label.text = str(item.count)
			drag_preview.position = get_viewport().get_mouse_position() - Vector2(28, 28)
			drag_preview.visible = true
	# 原格子半透明
	slot_buttons[index].modulate = Color(1, 1, 1, 0.3)


func _end_drag(swapped: bool) -> void:
	is_dragging = false
	dragged_slot = -1
	if drag_preview:
		drag_preview.visible = false
	refresh()
	if swapped and AudioManager:
		AudioManager.play_sfx(AudioManager.SFX.UI_CLICK)
