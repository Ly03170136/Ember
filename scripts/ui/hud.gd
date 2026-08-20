extends CanvasLayer
## 游戏内HUD：状态栏、时间、聊天、通知

@onready var health_bar: ProgressBar = $BottomLeft/HealthBar
@onready var hunger_bar: ProgressBar = $BottomLeft/HungerBar
@onready var thirst_bar: ProgressBar = $BottomLeft/ThirstBar
@onready var stamina_bar: ProgressBar = $BottomLeft/StaminaBar
@onready var time_label: Label = $TopRight/TimeLabel
@onready var day_label: Label = $TopRight/DayLabel
@onready var chat_box: VBoxContainer = $Chat/Scroll/ChatBox
@onready var chat_input: LineEdit = $Chat/ChatInput
@onready var notification: Label = $Notification
@onready var player_list: VBoxContainer = $BottomRight/PlayerList

var notification_timer: float = 0.0
var chat_visible: bool = false


func _ready() -> void:
	GameManager.chat_received.connect(_on_chat_received)
	chat_input.text_submitted.connect(_on_chat_submitted)
	chat_input.hide()
	# 初始显示
	_add_chat_message("系统", "欢迎来到余烬！WASD移动，Enter聊天")


func _process(delta: float) -> void:
	_update_stats()
	_update_time()
	_update_player_list()
	# 通知计时
	if notification_timer > 0:
		notification_timer -= delta
		if notification_timer <= 0:
			notification.visible = false


func _update_stats() -> void:
	var player: CharacterBody2D = GameManager.get_local_player()
	if player and is_instance_valid(player):
		health_bar.value = player.health
		hunger_bar.value = player.hunger
		thirst_bar.value = player.thirst
		stamina_bar.value = player.stamina


func _update_time() -> void:
	var main: Node = get_tree().current_scene
	if main and main.has_method("get_time_of_day"):
		var t: float = main.get_time_of_day()
		var hour := int(t * 24)
		var minute := int((t * 24 - hour) * 60)
		time_label.text = "%02d:%02d" % [hour, minute]
		# 显示季节、天数和天气
		var season: String = main.get_season() if main.has_method("get_season") else "spring"
		var weather: String = main.get_weather() if main.has_method("get_weather") else "clear"
		var season_names: Dictionary = {"spring": "春", "summer": "夏", "autumn": "秋", "winter": "冬"}
		var weather_names: Dictionary = {"clear": "晴", "cloudy": "多云", "rain": "小雨", "storm": "暴雨", "snow": "大雪", "fog": "大雾"}
		var season_text: String = season_names.get(season, season)
		var weather_text: String = weather_names.get(weather, weather)
		day_label.text = "%s 第%d天 %s" % [season_text, main.get_day_count(), weather_text]


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
	if event.is_action_pressed("chat"):
		chat_visible = not chat_visible
		if chat_visible:
			chat_input.show()
			chat_input.grab_focus()
		else:
			chat_input.hide()


func _on_chat_submitted(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	GameManager.send_chat.rpc(text)
	chat_input.clear()
	chat_input.hide()
	chat_visible = false


func _on_chat_received(peer_id: int, message: String) -> void:
	var name: String = GameManager.player_names.get(peer_id, "Unknown")
	_add_chat_message(name, message)


func _add_chat_message(name: String, message: String) -> void:
	var label := Label.new()
	label.text = "[%s] %s" % [name, message]
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	chat_box.add_child(label)
	# 限制聊天记录数量
	if chat_box.get_child_count() > 50:
		chat_box.get_child(0).queue_free()


func show_notification(text: String, duration: float = 3.0) -> void:
	notification.text = text
	notification.visible = true
	notification_timer = duration
