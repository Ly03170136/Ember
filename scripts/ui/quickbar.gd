extends Control
## 快捷栏UI：底部显示9个快捷格子

const SLOT_COUNT := 9

var inventory: Node = null
var slot_buttons: Array = []

@onready var hbox: HBoxContainer = $Panel/HBox


func _ready() -> void:
	for i in range(SLOT_COUNT):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(48, 48)
		btn.text = str(i + 1)
		btn.name = "QuickSlot_%d" % i
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
	if selected >= 0 and selected < SLOT_COUNT:
		var btn: Button = slot_buttons[selected]
		btn.modulate = btn.modulate.lightened(0.3)


func _on_selected_changed(index: int) -> void:
	refresh()


func _on_slot_pressed(index: int) -> void:
	if inventory:
		inventory.select_slot(index)
