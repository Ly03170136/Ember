extends Control
## 主菜单：4按钮 + 创建游戏子菜单
## 按钮：创建游戏 / 加入游戏 / 设置 / 退出游戏

# 主菜单按钮
@onready var create_button: Button = $ButtonContainer/CreateButton
@onready var join_button: Button = $ButtonContainer/JoinButton
@onready var settings_button: Button = $ButtonContainer/SettingsButton
@onready var quit_button: Button = $ButtonContainer/QuitButton

# 创建游戏子菜单
@onready var create_submenu: Panel = $CreateSubmenu
@onready var new_game_btn: Button = $CreateSubmenu/VBox/NewGameBtn
@onready var load_save_btn: Button = $CreateSubmenu/VBox/LoadSaveBtn
@onready var submenu_back_btn: Button = $CreateSubmenu/VBox/BackBtn

# 设置菜单实例
var settings_instance: Control = null


func _ready() -> void:
	get_tree().paused = false
	# 主按钮
	create_button.pressed.connect(_on_create_pressed)
	join_button.pressed.connect(_on_join_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	# 子菜单按钮
	new_game_btn.pressed.connect(_on_new_game_pressed)
	load_save_btn.pressed.connect(_on_load_save_pressed)
	submenu_back_btn.pressed.connect(_on_submenu_back_pressed)
	# 隐藏子菜单
	create_submenu.visible = false


# ==================== 主菜单按钮 ====================

func _on_create_pressed() -> void:
	# 显示创建游戏子菜单
	create_submenu.visible = true
	_set_main_buttons_enabled(false)


func _on_join_pressed() -> void:
	# 切换到网络大厅
	get_tree().change_scene_to_file("res://scenes/ui/network_lobby.tscn")


func _on_settings_pressed() -> void:
	# 打开设置菜单（实例化为子节点）
	if settings_instance and is_instance_valid(settings_instance):
		settings_instance.queue_free()
		settings_instance = null
	# 记录当前窗口大小，设置菜单可能会修改它
	var current_size: Vector2i = DisplayServer.window_get_size()
	settings_instance = load("res://scenes/ui/settings_menu.tscn").instantiate()
	add_child(settings_instance)
	# 强制显示（settings_menu默认visible=false）
	settings_instance.visible = true
	# 主菜单中不暂停游戏
	get_tree().paused = false
	# 延迟恢复窗口大小（设置菜单的_deferred_load_settings可能会修改它）
	call_deferred("_restore_window_size", current_size)
	# 连接返回按钮，点击后销毁设置菜单
	if settings_instance.has_node("Panel/VBox/ReturnBtn"):
		var return_btn: Button = settings_instance.get_node("Panel/VBox/ReturnBtn")
		return_btn.pressed.connect(_on_settings_closed)
	# 连接退出到主菜单按钮
	if settings_instance.has_node("Panel/VBox/QuitBtn"):
		var quit_btn: Button = settings_instance.get_node("Panel/VBox/QuitBtn")
		quit_btn.pressed.connect(_on_settings_closed)


func _restore_window_size(size: Vector2i) -> void:
	# 恢复窗口大小
	if DisplayServer.window_get_size() != size:
		DisplayServer.window_set_size(size)
		print("[MainMenu] 窗口大小已恢复为 ", size)


func _on_settings_closed() -> void:
	# 设置菜单关闭时销毁实例
	if settings_instance and is_instance_valid(settings_instance):
		settings_instance.queue_free()
		settings_instance = null
	get_tree().paused = false


func _on_quit_pressed() -> void:
	get_tree().quit()


# ==================== 创建游戏子菜单 ====================

func _on_new_game_pressed() -> void:
	# 切换到准备大厅（创建模式）
	get_tree().change_scene_to_file("res://scenes/ui/lobby_menu.tscn")


func _on_load_save_pressed() -> void:
	# 切换到存档列表
	get_tree().change_scene_to_file("res://scenes/ui/save_list.tscn")


func _on_submenu_back_pressed() -> void:
	create_submenu.visible = false
	_set_main_buttons_enabled(true)


func _set_main_buttons_enabled(enabled: bool) -> void:
	create_button.disabled = not enabled
	join_button.disabled = not enabled
	settings_button.disabled = not enabled
	quit_button.disabled = not enabled
