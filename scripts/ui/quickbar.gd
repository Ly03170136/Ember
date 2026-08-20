extends Control
## 快捷栏UI：底部显示9个快捷格子

const SLOT_COUNT := 9

var inventory: Node = null
var slot_buttons: Array = []

@onready var hbox: HBoxContainer = $Panel/HBox


func _ready() -> void:
	for i in range(SLOT_COUNT):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(56, 56)
		btn.text = str(i + 1)
		btn.name = "QuickSlot_%d" % i
		# 设置格子样式：深色背景+灰色边框
		var normal_style := StyleBoxFlat.new()
		normal_style.bg_color = Color(0.12, 0.12, 0.15, 0.9)
		normal_style.border_color = Color(0.4, 0.4, 0.5, 0.8)
		normal_style.border_width_left = 2
		normal_style.border_width_right = 2
		normal_style.border_width_top = 2
		normal_style.border_width_bottom = 2
		normal_style.corner_radius_top_left = 4
		normal_style.corner_radius_top_right = 4
		normal_style.corner_radius_bottom_left = 4
		normal_style.corner_radius_bottom_right = 4
		normal_style.content_margin_left = 4
		normal_style.content_margin_right = 4
		normal_style.content_margin_top = 4
		normal_style.content_margin_bottom = 4
		btn.add_theme_stylebox_override("normal", normal_style)
		btn.add_theme_stylebox_override("hover", normal_style)
		btn.add_theme_stylebox_override("pressed", normal_style)
		btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(_on_slot_pressed.bind(i))
		hbox.add_child(btn)
		slot_buttons.append(btn)


func set_inventory(inv: Node) -> void:
	inventory = inv
	if inventory:
		inventory.inventory_changed.connect(refresh)
		inventory.selected_slot_changed.connect(_on_selected_changed)
		refresh()


func refresh() -> void:
	if not inventory:
		return
	for i in range(SLOT_COUNT):
		var btn: Button = slot_buttons[i]
		var item: Dictionary = inventory.get_slot(i)
		if item.is_empty():
			btn.text = str(i + 1)
			btn.icon = null
			btn.modulate = Color(0.3, 0.3, 0.35)
		else:
			btn.icon = ArtAssets.get_item_icon(item.id)
			btn.modulate = Color.WHITE
			btn.text = "%d\n%d" % [i + 1, item.count]
			btn.tooltip_text = ItemDB.get_item_name(item.id)
	# 高亮选中
	_highlight_selected()


func _highlight_selected() -> void:
	if not inventory:
		return
	var selected: int = inventory.selected_slot
	for i in range(SLOT_COUNT):
		var btn: Button = slot_buttons[i]
		if i == selected:
			# 选中的格子：金色边框+稍亮背景
			var selected_style := StyleBoxFlat.new()
			selected_style.bg_color = Color(0.25, 0.2, 0.1, 0.95)
			selected_style.border_color = Color(1.0, 0.85, 0.3, 1.0)
			selected_style.border_width_left = 3
			selected_style.border_width_right = 3
			selected_style.border_width_top = 3
			selected_style.border_width_bottom = 3
			selected_style.corner_radius_top_left = 4
			selected_style.corner_radius_top_right = 4
			selected_style.corner_radius_bottom_left = 4
			selected_style.corner_radius_bottom_right = 4
			selected_style.content_margin_left = 4
			selected_style.content_margin_right = 4
			selected_style.content_margin_top = 4
			selected_style.content_margin_bottom = 4
			btn.add_theme_stylebox_override("normal", selected_style)
			btn.add_theme_color_override("font_color", Color(1, 0.9, 0.5, 1))
		else:
			# 未选中的格子：恢复默认深色边框
			var normal_style := StyleBoxFlat.new()
			normal_style.bg_color = Color(0.12, 0.12, 0.15, 0.9)
			normal_style.border_color = Color(0.4, 0.4, 0.5, 0.8)
			normal_style.border_width_left = 2
			normal_style.border_width_right = 2
			normal_style.border_width_top = 2
			normal_style.border_width_bottom = 2
			normal_style.corner_radius_top_left = 4
			normal_style.corner_radius_top_right = 4
			normal_style.corner_radius_bottom_left = 4
			normal_style.corner_radius_bottom_right = 4
			normal_style.content_margin_left = 4
			normal_style.content_margin_right = 4
			normal_style.content_margin_top = 4
			normal_style.content_margin_bottom = 4
			btn.add_theme_stylebox_override("normal", normal_style)
			btn.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 1))


func _on_selected_changed(index: int) -> void:
	refresh()


func _on_slot_pressed(index: int) -> void:
	if inventory:
		inventory.select_slot(index)
