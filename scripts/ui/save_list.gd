extends Control
## 存档列表：3个存档位，支持加载和删除

signal load_save(slot: int)
signal new_game()
signal back_pressed

var selected_slot: int = -1

@onready var title_label: Label = $TitleLabel
@onready var slots_container: VBoxContainer = $MainPanel/SlotsContainer
@onready var delete_button: Button = $BottomBar/DeleteButton
@onready var back_button: Button = $BottomBar/BackButton
@onready var confirm_popup: PopupPanel = $ConfirmPopup
@onready var confirm_label: Label = $ConfirmPopup/VBox/ConfirmLabel
@onready var confirm_btn: Button = $ConfirmPopup/VBox/ButtonRow/ConfirmBtn
@onready var cancel_btn: Button = $ConfirmPopup/VBox/ButtonRow/CancelBtn

var _slot_panels: Array = []


func _ready() -> void:
	_build_slots()
	_refresh_slots()
	delete_button.disabled = true
	delete_button.pressed.connect(_on_delete_pressed)
	back_button.pressed.connect(_on_back_pressed)
	confirm_btn.pressed.connect(_on_confirm_delete)
	cancel_btn.pressed.connect(func(): confirm_popup.hide())


func _build_slots() -> void:
	## 构建3个存档位
	_slot_panels.clear()
	for i in range(3):
		var slot_panel: Panel = Panel.new()
		slot_panel.custom_minimum_size = Vector2(0, 90)
		slot_panel.name = "Slot%d" % i
		var hbox: HBoxContainer = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 16)
		slot_panel.add_child(hbox)
		# 左侧：存档编号
		var num_label: Label = Label.new()
		num_label.text = "存档 %d" % (i + 1)
		num_label.custom_minimum_size = Vector2(80, 0)
		num_label.add_theme_color_override("font_color", Color(1, 0.8, 0.4))
		num_label.add_theme_font_size_override("font_size", 18)
		hbox.add_child(num_label)
		# 中间：存档信息
		var info_vbox: VBoxContainer = VBoxContainer.new()
		info_vbox.add_theme_constant_override("separation", 4)
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(info_vbox)
		var day_label: Label = Label.new()
		day_label.name = "DayLabel"
		day_label.add_theme_font_size_override("font_size", 14)
		info_vbox.add_child(day_label)
		var time_label: Label = Label.new()
		time_label.name = "TimeLabel"
		time_label.add_theme_color_override("font_color", Color(0.6, 0.58, 0.55))
		time_label.add_theme_font_size_override("font_size", 12)
		info_vbox.add_child(time_label)
		# 右侧：状态
		var status_label: Label = Label.new()
		status_label.name = "StatusLabel"
		status_label.custom_minimum_size = Vector2(120, 0)
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hbox.add_child(status_label)
		# 点击事件
		slot_panel.gui_input.connect(func(event): _on_slot_clicked(event, i))
		slots_container.add_child(slot_panel)
		_slot_panels.append({
			"panel": slot_panel,
			"day_label": day_label,
			"time_label": time_label,
			"status_label": status_label
		})


func _refresh_slots() -> void:
	## 刷新所有存档位显示
	for i in range(3):
		var info: Dictionary = {}
		if SaveManager:
			info = SaveManager.get_save_info(i)
		var slot_data: Dictionary = _slot_panels[i]
		if info.get("exists", false):
			var day: int = info.get("day", 0)
			var season: String = info.get("season", "spring")
			var season_cn: String = _season_to_cn(season)
			slot_data.day_label.text = "第 %d 天 · %s" % [day, season_cn]
			slot_data.day_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75))
			slot_data.time_label.text = "保存时间：%s" % info.get("timestamp", "未知")
			slot_data.status_label.text = "点击加载"
			slot_data.status_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
		else:
			slot_data.day_label.text = "空存档位"
			slot_data.day_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			slot_data.time_label.text = "点击创建新游戏"
			slot_data.status_label.text = "空"
			slot_data.status_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		# 重置选中样式
		_update_slot_selection(i)


func _season_to_cn(season: String) -> String:
	match season:
		"spring": return "春"
		"summer": return "夏"
		"autumn": return "秋"
		"winter": return "冬"
	return season


func _update_slot_selection(index: int) -> void:
	## 更新存档位选中样式
	var slot_data: Dictionary = _slot_panels[index]
	if index == selected_slot:
		slot_data.panel.modulate = Color(1, 0.95, 0.7)
	else:
		slot_data.panel.modulate = Color.WHITE


func _on_slot_clicked(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected_slot = index
		for i in range(3):
			_update_slot_selection(i)
		var info: Dictionary = {}
		if SaveManager:
			info = SaveManager.get_save_info(index)
		if info.get("exists", false):
			delete_button.disabled = false
			# 双击加载
			if event.double_click:
				_load_game(index)
		else:
			delete_button.disabled = true
			# 空存档位点击 → 新游戏（准备大厅）
			if event.double_click:
				get_tree().change_scene_to_file("res://scenes/ui/lobby_menu.tscn")


func _load_game(slot: int) -> void:
	## 加载存档并进入游戏
	if SaveManager:
		var data: Dictionary = SaveManager.load_game(slot)
		if not data.is_empty():
			# 存档加载成功，切换到游戏场景
			# 这里需要传递存档数据，暂时直接切换
			get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_delete_pressed() -> void:
	if selected_slot < 0:
		return
	var info: Dictionary = {}
	if SaveManager:
		info = SaveManager.get_save_info(selected_slot)
	if not info.get("exists", false):
		return
	confirm_label.text = "确定要删除存档 %d 吗？\n此操作不可撤销。" % (selected_slot + 1)
	confirm_popup.position = get_viewport().get_mouse_position()
	confirm_popup.show()


func _on_confirm_delete() -> void:
	if selected_slot >= 0 and SaveManager:
		SaveManager.delete_save(selected_slot)
	selected_slot = -1
	delete_button.disabled = true
	_refresh_slots()
	confirm_popup.hide()


func _on_back_pressed() -> void:
	# 返回主菜单
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
