extends CanvasLayer
## 游戏内HUD：状态栏、时间、聊天、通知

@onready var health_bar: ProgressBar = $UIRoot/BottomLeft/HealthBar
@onready var hunger_bar: ProgressBar = $UIRoot/BottomLeft/HungerBar
@onready var thirst_bar: ProgressBar = $UIRoot/BottomLeft/ThirstBar
@onready var stamina_bar: ProgressBar = $UIRoot/BottomLeft/StaminaBar
@onready var sanity_bar: ProgressBar = $UIRoot/BottomLeft/SanityBar
@onready var day_label: Label = $UIRoot/TopRight/DayLabel
@onready var month_season_label: Label = $UIRoot/TopRight/MonthSeasonLabel
@onready var weather_temp_label: Label = $UIRoot/TopRight/WeatherTempLabel
@onready var time_label: Label = $UIRoot/TopRight/TimeLabel
@onready var chat_box: VBoxContainer = $UIRoot/Chat/Scroll/ChatBox
@onready var chat_input: LineEdit = $UIRoot/Chat/ChatInput
@onready var chat_panel: Control = $UIRoot/Chat
@onready var notification: Label = $UIRoot/Notification
@onready var player_list: VBoxContainer = $UIRoot/BottomRight/PlayerList

var notification_timer: float = 0.0
var chat_visible: bool = false
var chat_hide_timer: float = 0.0  # 聊天窗口自动隐藏计时器
const CHAT_AUTO_HIDE_TIME := 5.0  # 5秒后自动隐藏
var debug_console: Node = null  # 调试控制台引用


func _ready() -> void:
	GameManager.chat_received.connect(_on_chat_received)
	chat_input.text_submitted.connect(_on_chat_submitted)
	# 初始隐藏聊天窗口
	chat_panel.hide()
	chat_input.hide()
	# 初始显示
	_add_chat_message("系统", "欢迎来到余烬！WASD移动，Enter聊天，输入 /help 查看调试命令")
	# 延迟获取调试控制台引用（它在main.gd中动态创建）
	call_deferred("_init_debug_console")


func _init_debug_console() -> void:
	## 初始化调试控制台引用并连接信号
	debug_console = get_node_or_null("DebugConsole")
	if debug_console and debug_console.has_signal("command_output"):
		debug_console.command_output.connect(_on_command_output)
		print("[HUD] 调试控制台已连接，输入 /help 查看命令")


func _process(delta: float) -> void:
	_update_stats()
	_update_time()
	_update_player_list()
	# 通知计时
	if notification_timer > 0:
		notification_timer -= delta
		if notification_timer <= 0:
			notification.visible = false
	# 聊天窗口自动隐藏计时
	if chat_hide_timer > 0:
		chat_hide_timer -= delta
		if chat_hide_timer <= 0:
			_hide_chat()


func _update_stats() -> void:
	var player: CharacterBody2D = GameManager.get_local_player()
	if player and is_instance_valid(player):
		health_bar.value = player.health
		hunger_bar.value = player.hunger
		thirst_bar.value = player.thirst
		stamina_bar.value = player.stamina
		# 理智值
		if player.has_method("get") or true:
			sanity_bar.value = player.sanity


func _update_time() -> void:
	var main: Node = get_tree().current_scene
	if main and main.has_method("get_time_of_day"):
		var t: float = main.get_time_of_day()
		var hour := int(t * 24)
		var minute := int((t * 24 - hour) * 60)
		# 第四行：当前时间24小时制
		time_label.text = "%02d:%02d" % [hour, minute]
		# 第一行：存活多少天
		day_label.text = "已存活 %d 天" % main.get_day_count()
		# 第二行：月份 季节
		var month_name: String = "3月"
		if main.has_method("get_month_name"):
			month_name = main.get_month_name()
		var season: String = main.get_season() if main.has_method("get_season") else "spring"
		var season_names: Dictionary = {"spring": "春季", "summer": "夏季", "autumn": "秋季", "winter": "冬季"}
		var season_text: String = season_names.get(season, season)
		month_season_label.text = "%s | %s" % [month_name, season_text]
		# 第三行：天气 | 温度 舒适情况
		var weather: String = main.get_weather() if main.has_method("get_weather") else "clear"
		var weather_names: Dictionary = {"clear": "晴", "cloudy": "多云", "rain": "小雨", "storm": "暴雨", "snow": "大雪", "fog": "大雾"}
		var weather_text: String = weather_names.get(weather, weather)
		var temp_text: String = "舒适"
		var temp_value: float = 0.0
		if main.has_method("get_ambient_temperature"):
			temp_value = main.get_ambient_temperature()
			if temp_value < -20:
				temp_text = "极寒"
			elif temp_value < -10:
				temp_text = "严寒"
			elif temp_value < 0:
				temp_text = "寒冷"
			elif temp_value < 10:
				temp_text = "凉爽"
			elif temp_value < 25:
				temp_text = "舒适"
			elif temp_value < 30:
				temp_text = "温暖"
			else:
				temp_text = "炎热"
		weather_temp_label.text = "%s | %.0f°C %s" % [weather_text, temp_value, temp_text]


func _update_player_list() -> void:
	# 清除旧的
	for child in player_list.get_children():
		child.queue_free()
	# 添加玩家
	for pid: int in GameManager.players.keys():
		var player: CharacterBody2D = GameManager.players[pid]
		if not is_instance_valid(player):
			continue
		var label := Label.new()
		var status_icon := "●" if not player.is_down else "✕"
		var status := "重伤" if player.is_down else "存活"
		label.text = "%s %s - %s (HP:%d)" % [status_icon, player.player_name, status, int(player.health)]
		label.add_theme_font_size_override("font_size", 12)
		# 根据状态设置颜色
		if player.is_down:
			label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
		else:
			label.add_theme_color_override("font_color", Color(0.8, 0.9, 0.8))
		player_list.add_child(label)


func _input(event: InputEvent) -> void:
	# 检测Enter键（同时支持chat动作和直接按键检测）
	var is_enter: bool = false
	if event.is_action_pressed("chat"):
		is_enter = true
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			is_enter = true
	if is_enter:
		# 如果输入框已经有焦点，不重复触发（让text_submitted处理）
		if chat_input and chat_input.has_focus():
			return
		_show_chat()
		get_viewport().set_input_as_handled()


func _show_chat() -> void:
	## 显示聊天窗口
	chat_visible = true
	chat_panel.show()
	chat_input.show()
	chat_input.grab_focus()
	# 重置自动隐藏计时器（用户正在输入，不自动隐藏）
	chat_hide_timer = 0.0


func _hide_chat() -> void:
	## 隐藏聊天窗口
	chat_visible = false
	chat_panel.hide()
	chat_input.hide()
	chat_hide_timer = 0.0


func _on_chat_submitted(text: String) -> void:
	if text.strip_edges().is_empty():
		# 空内容直接隐藏
		_hide_chat()
		return
	# 检测是否为调试命令（以 / 开头）
	if text.strip_edges().begins_with("/"):
		# 执行调试命令
		if debug_console and debug_console.has_method("execute_command_text"):
			debug_console.execute_command_text(text)
		else:
			_add_chat_message("系统", "调试控制台未就绪", Color(1.0, 0.5, 0.5))
		chat_input.clear()
		# 命令执行后保持聊天窗口可见5秒
		chat_hide_timer = CHAT_AUTO_HIDE_TIME
		chat_input.release_focus()
		return
	# 普通聊天消息
	GameManager.send_chat.rpc(text)
	chat_input.clear()
	# 发送后启动5秒自动隐藏计时器
	chat_hide_timer = CHAT_AUTO_HIDE_TIME
	# 保持聊天窗口可见，但输入框失去焦点
	chat_input.release_focus()


func _on_command_output(text: String, color: Color) -> void:
	## 调试命令输出回调，显示到聊天窗口
	_add_chat_message("控制台", text, color)


func _on_chat_received(peer_id: int, message: String) -> void:
	var name: String = GameManager.player_names.get(peer_id, "Unknown")
	_add_chat_message(name, message)
	# 收到新消息时显示聊天窗口，并启动5秒自动隐藏
	if not chat_visible:
		chat_panel.show()
		chat_visible = true
	# 重置自动隐藏计时器（有新消息，延长显示时间）
	chat_hide_timer = CHAT_AUTO_HIDE_TIME


func _add_chat_message(name: String, message: String, color: Color = Color(1, 1, 1)) -> void:
	var label := Label.new()
	label.text = "[%s] %s" % [name, message]
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	chat_box.add_child(label)
	# 限制聊天记录数量
	if chat_box.get_child_count() > 50:
		chat_box.get_child(0).queue_free()
	# 自动滚动到底部（延迟两帧，确保UI布局已完全更新）
	call_deferred("_scroll_chat_to_bottom")
	call_deferred("_scroll_chat_to_bottom")


func _scroll_chat_to_bottom() -> void:
	## 聊天窗口滚动到底部
	if not chat_box or not is_instance_valid(chat_box):
		return
	var scroll: ScrollContainer = chat_box.get_parent() as ScrollContainer
	if scroll and is_instance_valid(scroll):
		var vbar: VScrollBar = scroll.get_v_scroll_bar()
		if vbar and is_instance_valid(vbar):
			# 设置滚动到最大值
			scroll.scroll_vertical = vbar.max_value
			# 再次设置，确保生效
			call_deferred("_set_scroll_max", scroll)


func _set_scroll_max(scroll: ScrollContainer) -> void:
	## 辅助函数：设置滚动容器到最大值
	if scroll and is_instance_valid(scroll):
		var vbar: VScrollBar = scroll.get_v_scroll_bar()
		if vbar and is_instance_valid(vbar):
			scroll.scroll_vertical = vbar.max_value


func show_notification(text: String, duration: float = 3.0) -> void:
	notification.text = text
	notification.visible = true
	notification_timer = duration
