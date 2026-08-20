extends Control
## 系统设置菜单（Minecraft风格）- 实际可调节功能
## 按ESC打开/关闭，暂停游戏

@onready var title: Label = $Panel/VBox/Title
@onready var return_btn: Button = $Panel/VBox/ReturnBtn
@onready var player_settings_btn: Button = $Panel/VBox/PlayerSettingsBtn
@onready var controls_btn: Button = $Panel/VBox/ControlsBtn
@onready var video_btn: Button = $Panel/VBox/VideoBtn
@onready var audio_btn: Button = $Panel/VBox/AudioBtn
@onready var language_btn: Button = $Panel/VBox/LanguageBtn
@onready var quit_btn: Button = $Panel/VBox/QuitBtn
@onready var version_label: Label = $Panel/VBox/VersionLabel

# 设置子面板
@onready var settings_panel: Panel = $SettingsPanel
@onready var settings_title: Label = $SettingsPanel/Margin/VBox/SettingsTitle
@onready var settings_content: VBoxContainer = $SettingsPanel/Margin/VBox/SettingsContent
@onready var settings_back_btn: Button = $SettingsPanel/Margin/VBox/SettingsBackBtn

# 控制设置面板
@onready var shortcuts_panel: Panel = $ShortcutsPanel
@onready var shortcuts_label: Label = $ShortcutsPanel/Margin/VBox/ShortcutsLabel
@onready var shortcuts_close_btn: Button = $ShortcutsPanel/Margin/VBox/CloseBtn

var is_open: bool = false
var current_settings: String = ""

# 视频设置临时变量（应用前不生效）
var temp_resolution: String = ""
var temp_fullscreen: bool = false
var temp_window_mode: String = ""
var temp_vsync: bool = false
var temp_startup_screen: int = 0
var original_resolution: String = ""
var original_fullscreen: bool = false
var original_window_mode: String = ""
var original_vsync: bool = false
var original_startup_screen: int = 0

# 设置值（可持久化）
var settings_data: Dictionary = {
	"fullscreen": false,
	"master_volume": 0.8,
	"music_volume": 0.6,
	"sfx_volume": 0.8,
	"player_name": "Player",
	"language": "zh",
	"show_fps": false,
}

const SHORTCUTS := {
	"移动": "W A S D", "冲刺": "Shift", "攻击": "鼠标左键",
	"交互/采集": "F", "制作菜单": "E", "建造菜单": "B",
	"背包": "TAB", "大地图": "M", "科技树": "T",
	"快捷栏": "1 - 9", "聊天": "Enter", "系统菜单": "ESC",
	"取消放置": "鼠标右键",
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	settings_panel.visible = false
	shortcuts_panel.visible = false
	# 延迟加载设置，确保Godot编辑器的运行设置不会覆盖窗口位置
	call_deferred("_deferred_load_settings")
	_update_shortcuts()
	return_btn.pressed.connect(_on_return)
	player_settings_btn.pressed.connect(func(): _open_settings("player"))
	controls_btn.pressed.connect(_on_controls)
	video_btn.pressed.connect(func(): _open_settings("video"))
	audio_btn.pressed.connect(func(): _open_settings("audio"))
	language_btn.pressed.connect(func(): _open_settings("language"))
	quit_btn.pressed.connect(_on_quit)
	shortcuts_close_btn.pressed.connect(_on_close_shortcuts)
	settings_back_btn.pressed.connect(_on_close_settings)
	add_to_group("ui_menu")
	version_label.text = "余烬 EMBER v0.9 - Godot 4.7"


func _deferred_load_settings() -> void:
	# 延迟一帧后加载设置，确保窗口已初始化
	await get_tree().process_frame
	_load_settings()
	# 再延迟一帧后确保窗口在单个屏幕内（防止跨屏渲染冲突）
	await get_tree().process_frame
	_ensure_window_in_single_screen()


func _ensure_window_in_single_screen() -> void:
	# 确保窗口完全在一个屏幕内，不跨越边界（避免多显示器渲染冲突）
	var window_pos: Vector2i = DisplayServer.window_get_position()
	var window_size: Vector2i = DisplayServer.window_get_size()
	var screen_count: int = DisplayServer.get_screen_count()

	# 找到窗口中心所在的屏幕
	var window_center: Vector2i = Vector2i(
		window_pos.x + window_size.x / 2,
		window_pos.y + window_size.y / 2
	)
	var target_screen: int = 0
	for i in range(screen_count):
		var sp: Vector2i = DisplayServer.screen_get_position(i)
		var ss: Vector2i = DisplayServer.screen_get_size(i)
		if window_center.x >= sp.x and window_center.x < sp.x + ss.x and \
		   window_center.y >= sp.y and window_center.y < sp.y + ss.y:
			target_screen = i
			break

	# 如果用户设置了启动屏幕，使用设置的屏幕
	if settings_data.has("startup_screen"):
		var startup: int = int(settings_data.startup_screen)
		if startup >= 0 and startup < screen_count:
			target_screen = startup

	# 获取目标屏幕的位置和大小
	var screen_pos: Vector2i = DisplayServer.screen_get_position(target_screen)
	var screen_size: Vector2i = DisplayServer.screen_get_size(target_screen)

	# 限制窗口大小不超过目标屏幕的90%
	var max_w: int = int(screen_size.x * 0.9)
	var max_h: int = int(screen_size.y * 0.9)
	var new_w: int = min(window_size.x, max_w)
	var new_h: int = min(window_size.y, max_h)
	if new_w != window_size.x or new_h != window_size.y:
		DisplayServer.window_set_size(Vector2i(new_w, new_h))
		window_size = Vector2i(new_w, new_h)

	# 把窗口移到目标屏幕居中
	var new_x: int = screen_pos.x + (screen_size.x - window_size.x) / 2
	var new_y: int = screen_pos.y + (screen_size.y - window_size.y) / 2
	DisplayServer.window_set_position(Vector2i(new_x, new_y))

	print("[Settings] 窗口已确保在屏幕 ", target_screen, " 内: 位置(", new_x, ",", new_y, ") 大小", new_w, "x", new_h)


func _limit_window_size() -> void:
	# 确保窗口完全在当前屏幕内，不跨越边界（避免多显示器渲染冲突）
	var current_screen: int = DisplayServer.window_get_current_screen()
	var screen_pos: Vector2i = DisplayServer.screen_get_position(current_screen)
	var screen_size: Vector2i = DisplayServer.screen_get_size(current_screen)
	var window_pos: Vector2i = DisplayServer.window_get_position()
	var window_size: Vector2i = DisplayServer.window_get_size()

	# 限制窗口大小不超过当前屏幕的90%
	var max_w: int = int(screen_size.x * 0.9)
	var max_h: int = int(screen_size.y * 0.9)
	var new_w: int = min(window_size.x, max_w)
	var new_h: int = min(window_size.y, max_h)
	if new_w != window_size.x or new_h != window_size.y:
		DisplayServer.window_set_size(Vector2i(new_w, new_h))
		window_size = Vector2i(new_w, new_h)

	# 确保窗口完全在当前屏幕内（不跨越边界）
	var new_x: int = window_pos.x
	var new_y: int = window_pos.y
	# 如果窗口右边界超出屏幕右边界，向左移动
	if window_pos.x + window_size.x > screen_pos.x + screen_size.x:
		new_x = screen_pos.x + screen_size.x - window_size.x
	# 如果窗口左边界小于屏幕左边界，向右移动
	if window_pos.x < screen_pos.x:
		new_x = screen_pos.x
	# 如果窗口下边界超出屏幕下边界，向上移动
	if window_pos.y + window_size.y > screen_pos.y + screen_size.y:
		new_y = screen_pos.y + screen_size.y - window_size.y
	# 如果窗口上边界小于屏幕上边界，向下移动
	if window_pos.y < screen_pos.y:
		new_y = screen_pos.y

	# 如果位置需要调整，设置新位置
	if new_x != window_pos.x or new_y != window_pos.y:
		DisplayServer.window_set_position(Vector2i(new_x, new_y))

	print("[Settings] 窗口已限制在屏幕内: 位置(", new_x, ",", new_y, ") 大小", new_w, "x", new_h)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if shortcuts_panel.visible:
				shortcuts_panel.visible = false
			elif settings_panel.visible:
				settings_panel.visible = false
			else:
				toggle()
			get_viewport().set_input_as_handled()


func toggle() -> void:
	is_open = not is_open
	visible = is_open
	if is_open:
		get_tree().paused = true
	else:
		get_tree().paused = false
		settings_panel.visible = false
		shortcuts_panel.visible = false


func _update_shortcuts() -> void:
	var text: String = "=== 控制设置 ===\n\n"
	for action in SHORTCUTS.keys():
		text += "%-10s :  %s\n" % [action, SHORTCUTS[action]]
	text += "\n=== 游戏提示 ===\n"
	text += "• 白天采集建造，夜晚防守\n"
	text += "• 丧尸会被声音和光线吸引\n"
	text += "• 倒地后60秒内需救援\n"
	text += "• 不同职业有不同能力\n"
	text += "• 学习书籍可解锁跨职业技能\n"
	text += "• 按T打开科技树\n"
	text += "• 按ESC返回菜单"
	shortcuts_label.text = text


func _open_settings(settings_type: String) -> void:
	current_settings = settings_type
	settings_panel.visible = true
	# 清空旧内容
	for child in settings_content.get_children():
		child.queue_free()
	match settings_type:
		"player":
			settings_title.text = "玩家设置"
			_build_player_settings()
		"video":
			settings_title.text = "视频设置"
			_build_video_settings()
		"audio":
			settings_title.text = "音效设置"
			_build_audio_settings()
		"language":
			settings_title.text = "语言设置"
			_build_language_settings()


func _build_player_settings() -> void:
	# 玩家名字
	var name_label := Label.new()
	name_label.text = "玩家名字:"
	settings_content.add_child(name_label)
	var name_edit := LineEdit.new()
	name_edit.text = settings_data.player_name
	name_edit.custom_minimum_size = Vector2(200, 30)
	name_edit.text_submitted.connect(func(text): _on_name_changed(text))
	settings_content.add_child(name_edit)
	# 职业显示
	var player: Node = GameManager.get_local_player()
	if player:
		var class_label := Label.new()
		class_label.text = "当前职业: %s" % player.get_class_name_cn()
		settings_content.add_child(class_label)
	# 显示FPS
	var fps_check := CheckBox.new()
	fps_check.text = "显示FPS"
	fps_check.button_pressed = settings_data.show_fps
	fps_check.toggled.connect(func(pressed): _on_fps_toggled(pressed))
	settings_content.add_child(fps_check)


func _build_video_settings() -> void:
	# 初始化临时变量为当前设置
	original_resolution = settings_data.get("resolution", "1920x1080")
	original_fullscreen = settings_data.fullscreen
	original_window_mode = settings_data.get("window_mode", "窗口化")
	original_vsync = settings_data.get("vsync", true)
	original_startup_screen = settings_data.get("startup_screen", 0)
	temp_resolution = original_resolution
	temp_fullscreen = original_fullscreen
	temp_window_mode = original_window_mode
	temp_vsync = original_vsync
	temp_startup_screen = original_startup_screen

	# 当前选择显示
	var current_label := Label.new()
	current_label.text = "当前选择: %s | %s | VSync:%s" % [
		temp_resolution,
		temp_window_mode,
		"开" if temp_vsync else "关"
	]
	current_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	current_label.name = "CurrentSelectionLabel"
	settings_content.add_child(current_label)

	# 全屏切换
	var fullscreen_check := CheckBox.new()
	fullscreen_check.text = "全屏模式"
	fullscreen_check.button_pressed = temp_fullscreen
	fullscreen_check.toggled.connect(func(pressed): _on_temp_fullscreen_toggled(pressed, current_label))
	settings_content.add_child(fullscreen_check)

	# 窗口模式
	var mode_label := Label.new()
	mode_label.text = "窗口模式:"
	settings_content.add_child(mode_label)
	var mode_options: Array = ["窗口化", "无边框窗口", "全屏"]
	for mode in mode_options:
		var mode_btn := Button.new()
		mode_btn.text = mode
		mode_btn.custom_minimum_size = Vector2(150, 25)
		if temp_window_mode == mode:
			mode_btn.modulate = Color(1, 0.9, 0.5)
		mode_btn.pressed.connect(func(): _on_temp_window_mode_changed(mode, current_label))
		settings_content.add_child(mode_btn)

	# 分辨率选项
	var res_label := Label.new()
	res_label.text = "\n分辨率:"
	settings_content.add_child(res_label)
	var resolutions: Array = [
		"1024x768", "1280x720", "1366x768", "1600x900",
		"1920x1080", "2560x1440", "3840x2160"
	]
	for res in resolutions:
		var res_btn := Button.new()
		res_btn.text = res
		res_btn.custom_minimum_size = Vector2(150, 25)
		if temp_resolution == res:
			res_btn.modulate = Color(1, 0.9, 0.5)
		res_btn.pressed.connect(func(): _on_temp_resolution_selected(res, current_label))
		settings_content.add_child(res_btn)

	# VSync
	var vsync_check := CheckBox.new()
	vsync_check.text = "垂直同步 (VSync)"
	vsync_check.button_pressed = temp_vsync
	vsync_check.toggled.connect(func(pressed): _on_temp_vsync_toggled(pressed, current_label))
	settings_content.add_child(vsync_check)

	# 启动屏幕选择
	var screen_label := Label.new()
	screen_label.text = "\n启动屏幕:"
	settings_content.add_child(screen_label)
	var screen_count: int = DisplayServer.get_screen_count()
	for i in range(screen_count):
		var screen_btn := Button.new()
		var sp: Vector2i = DisplayServer.screen_get_position(i)
		var ss: Vector2i = DisplayServer.screen_get_size(i)
		screen_btn.text = "屏幕 %d (%dx%d)" % [i + 1, ss.x, ss.y]
		screen_btn.custom_minimum_size = Vector2(150, 25)
		if temp_startup_screen == i:
			screen_btn.modulate = Color(1, 0.9, 0.5)
		screen_btn.pressed.connect(func(): _on_temp_startup_screen_changed(i, current_label))
		settings_content.add_child(screen_btn)

	# 应用和取消按钮
	var btn_hbox := HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 10)
	settings_content.add_child(btn_hbox)

	var apply_btn := Button.new()
	apply_btn.text = "应用"
	apply_btn.custom_minimum_size = Vector2(100, 30)
	apply_btn.modulate = Color(0.5, 0.8, 0.5)
	apply_btn.pressed.connect(_on_apply_video_settings)
	btn_hbox.add_child(apply_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "取消"
	cancel_btn.custom_minimum_size = Vector2(100, 30)
	cancel_btn.pressed.connect(_on_cancel_video_settings)
	btn_hbox.add_child(cancel_btn)

	# 提示
	var hint := Label.new()
	hint.text = "\n* 选择后点击\"应用\"生效，\"取消\"恢复原设置"
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	settings_content.add_child(hint)


func _build_audio_settings() -> void:
	# 主音量
	_add_volume_slider("主音量", "master_volume")
	_add_volume_slider("音乐音量", "music_volume")
	_add_volume_slider("音效音量", "sfx_volume")


func _add_volume_slider(label_text: String, setting_key: String) -> void:
	var label := Label.new()
	label.text = "%s: %d%%" % [label_text, int(settings_data[setting_key] * 100)]
	settings_content.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = settings_data[setting_key]
	slider.custom_minimum_size = Vector2(200, 20)
	slider.value_changed.connect(func(value): _on_volume_changed(setting_key, value, label, label_text))
	settings_content.add_child(slider)


func _build_language_settings() -> void:
	var lang_label := Label.new()
	lang_label.text = "选择语言:"
	settings_content.add_child(lang_label)
	var zh_btn := Button.new()
	zh_btn.text = "简体中文"
	zh_btn.custom_minimum_size = Vector2(150, 30)
	zh_btn.pressed.connect(func(): _on_language_changed("zh"))
	settings_content.add_child(zh_btn)
	var en_btn := Button.new()
	en_btn.text = "English"
	en_btn.custom_minimum_size = Vector2(150, 30)
	en_btn.pressed.connect(func(): _on_language_changed("en"))
	settings_content.add_child(en_btn)
	var hint := Label.new()
	hint.text = "\n* 语言切换需重启游戏生效"
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	settings_content.add_child(hint)


# ==================== 设置回调 ====================

func _on_name_changed(text: String) -> void:
	settings_data.player_name = text
	var player: Node = GameManager.get_local_player()
	if player:
		player.player_name = text
	_save_settings()
	print("[Settings] 玩家名字改为: ", text)


func _on_fps_toggled(pressed: bool) -> void:
	settings_data.show_fps = pressed
	_save_settings()


func _on_fullscreen_toggled(pressed: bool) -> void:
	settings_data.fullscreen = pressed
	if pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	_save_settings()


func _on_window_mode_changed(mode: String) -> void:
	match mode:
		"窗口化":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			settings_data.fullscreen = false
		"无边框窗口":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			settings_data.fullscreen = true
		"全屏":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
			settings_data.fullscreen = true
	settings_data["window_mode"] = mode
	_save_settings()
	print("[Settings] 窗口模式改为: ", mode)


func _on_vsync_toggled(pressed: bool) -> void:
	settings_data["vsync"] = pressed
	if pressed:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_save_settings()
	print("[Settings] VSync: ", "开启" if pressed else "关闭")


func _refresh_ui_after_resolution() -> void:
	# 延迟一帧后刷新所有UI，确保窗口大小已更新
	await get_tree().process_frame
	# 刷新设置菜单本身的位置
	if settings_panel.visible:
		settings_panel.position = Vector2.ZERO
	print("[Settings] UI已刷新")


func _on_temp_resolution_selected(res: String, label: Label) -> void:
	temp_resolution = res
	_update_video_selection_label(label)
	# 刷新按钮高亮
	for child in settings_content.get_children():
		if child is Button and child.text in ["1024x768", "1280x720", "1366x768", "1600x900", "1920x1080", "2560x1440", "3840x2160"]:
			child.modulate = Color(1, 0.9, 0.5) if child.text == res else Color(1, 1, 1)


func _on_temp_fullscreen_toggled(pressed: bool, label: Label) -> void:
	temp_fullscreen = pressed
	_update_video_selection_label(label)


func _on_temp_window_mode_changed(mode: String, label: Label) -> void:
	temp_window_mode = mode
	_update_video_selection_label(label)
	# 刷新按钮高亮
	for child in settings_content.get_children():
		if child is Button and child.text in ["窗口化", "无边框窗口", "全屏"]:
			child.modulate = Color(1, 0.9, 0.5) if child.text == mode else Color(1, 1, 1)


func _on_temp_vsync_toggled(pressed: bool, label: Label) -> void:
	temp_vsync = pressed
	_update_video_selection_label(label)


func _on_temp_startup_screen_changed(screen: int, label: Label) -> void:
	temp_startup_screen = screen
	_update_video_selection_label(label)
	# 刷新按钮高亮
	for child in settings_content.get_children():
		if child is Button and child.text.begins_with("屏幕 "):
			child.modulate = Color(1, 0.9, 0.5) if child.text.begins_with("屏幕 %d " % [screen + 1]) else Color(1, 1, 1)


func _update_video_selection_label(label: Label) -> void:
	label.text = "当前选择: %s | %s | VSync:%s | 启动:屏幕%d" % [
		temp_resolution,
		temp_window_mode,
		"开" if temp_vsync else "关",
		temp_startup_screen + 1
	]


func _on_apply_video_settings() -> void:
	print("[Settings] ===== 应用视频设置 =====")
	print("[Settings] temp_resolution: ", temp_resolution)
	print("[Settings] temp_window_mode: ", temp_window_mode)
	print("[Settings] temp_vsync: ", temp_vsync)
	print("[Settings] temp_startup_screen: ", temp_startup_screen)

	# 应用分辨率
	var parts: Array = temp_resolution.split("x")
	if parts.size() == 2:
		var w: int = int(parts[0])
		var h: int = int(parts[1])
		print("[Settings] 目标分辨率: ", w, "x", h)
		# 先确保窗口化模式（全屏模式下修改大小不生效）
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		# 使用DisplayServer修改窗口大小
		DisplayServer.window_set_size(Vector2i(w, h))
		print("[Settings] 调用 DisplayServer.window_set_size 完成")
		# 同时设置Window节点的大小
		if get_window():
			get_window().size = Vector2i(w, h)
			print("[Settings] 设置 get_window().size 完成")
		else:
			print("[Settings] 警告: get_window() 返回 null")
		# 修改视口大小
		get_viewport().size = Vector2i(w, h)
		print("[Settings] 设置 get_viewport().size 完成")
		# 验证窗口大小
		var actual_size: Vector2i = DisplayServer.window_get_size()
		print("[Settings] 实际窗口大小: ", actual_size.x, "x", actual_size.y)
		# 保存设置
		settings_data["resolution"] = temp_resolution
		settings_data["screen_width"] = w
		settings_data["screen_height"] = h

	# 应用最终窗口模式
	match temp_window_mode:
		"窗口化":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		"无边框窗口":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		"全屏":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	settings_data.fullscreen = temp_fullscreen
	settings_data["window_mode"] = temp_window_mode

	# 应用VSync
	if temp_vsync:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	settings_data["vsync"] = temp_vsync

	# 保存启动屏幕设置
	settings_data["startup_screen"] = temp_startup_screen

	# 保存
	_save_settings()
	print("[Settings] 视频设置已保存")
	# 确保窗口在单个屏幕内（暂时注释掉，先验证分辨率修改是否生效）
	# _ensure_window_in_single_screen()
	# 关闭设置面板
	settings_panel.visible = false
	print("[Settings] ===== 应用完成 =====")


func _on_cancel_video_settings() -> void:
	# 恢复原设置（不应用，只是重置临时变量）
	temp_resolution = original_resolution
	temp_fullscreen = original_fullscreen
	temp_window_mode = original_window_mode
	temp_vsync = original_vsync
	temp_startup_screen = original_startup_screen
	print("[Settings] 视频设置已取消，恢复为: ", original_resolution)
	# 关闭设置面板
	settings_panel.visible = false


func _on_resolution_changed(res: String) -> void:
	var parts: Array = res.split("x")
	if parts.size() == 2:
		var w: int = int(parts[0])
		var h: int = int(parts[1])
		# 先确保是窗口化模式（全屏模式下修改大小不生效）
		if not settings_data.fullscreen:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		# 使用DisplayServer修改窗口大小（Godot 4.x最可靠的方法）
		DisplayServer.window_set_size(Vector2i(w, h))
		# 在当前所在屏幕居中（而不是总是主屏幕）
		var current_screen: int = DisplayServer.window_get_current_screen()
		var screen_pos: Vector2i = DisplayServer.screen_get_position(current_screen)
		var screen_size: Vector2i = DisplayServer.screen_get_size(current_screen)
		DisplayServer.window_set_position(Vector2i(
			screen_pos.x + (screen_size.x - w) / 2,
			screen_pos.y + (screen_size.y - h) / 2
		))
		# 修改视口大小
		get_viewport().size = Vector2i(w, h)
		# 保存到设置数据
		settings_data["resolution"] = res
		settings_data["screen_width"] = w
		settings_data["screen_height"] = h
		_save_settings()
		print("[Settings] 分辨率改为: ", res, " 窗口+视口已同步修改")
		# 刷新UI（延迟一帧，确保窗口大小已更新）
		call_deferred("_refresh_ui_after_resolution")


func _on_volume_changed(key: String, value: float, label: Label, label_text: String) -> void:
	settings_data[key] = value
	label.text = "%s: %d%%" % [label_text, int(value * 100)]
	# 应用音量到AudioServer
	if key == "master_volume":
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(value))
	_save_settings()


func _on_language_changed(lang: String) -> void:
	settings_data.language = lang
	_save_settings()
	print("[Settings] 语言改为: ", lang)


# ==================== 存档 ====================

func _save_settings() -> void:
	var file := FileAccess.open("user://settings.cfg", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings_data))
		file.close()


func _load_settings() -> void:
	if FileAccess.file_exists("user://settings.cfg"):
		var file := FileAccess.open("user://settings.cfg", FileAccess.READ)
		if file:
			var content: String = file.get_as_text()
			file.close()
			var parsed: Variant = JSON.parse_string(content)
			if typeof(parsed) == TYPE_DICTIONARY:
				settings_data = parsed
				# 应用全屏设置
				if settings_data.fullscreen:
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
				# 应用分辨率设置（只设置大小，不改变位置）
				if settings_data.has("screen_width") and settings_data.has("screen_height"):
					var w: int = int(settings_data.screen_width)
					var h: int = int(settings_data.screen_height)
					if w > 0 and h > 0:
						# 先确保窗口化模式
						DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
						# 设置窗口大小
						DisplayServer.window_set_size(Vector2i(w, h))
						get_viewport().size = Vector2i(w, h)
						print("[Settings] 加载保存的分辨率: ", w, "x", h)
				# 应用VSync设置
				if settings_data.has("vsync"):
					if settings_data.vsync:
						DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
					else:
						DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	else:
		# 没有保存的设置时，使用默认分辨率
		var w: int = 1280
		var h: int = 720
		DisplayServer.window_set_size(Vector2i(w, h))
		print("[Settings] 无保存设置，使用默认分辨率: ", w, "x", h)


func _on_return() -> void:
	toggle()

func _on_controls() -> void:
	shortcuts_panel.visible = true

func _on_quit() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _on_close_shortcuts() -> void:
	shortcuts_panel.visible = false

func _on_close_settings() -> void:
	settings_panel.visible = false
