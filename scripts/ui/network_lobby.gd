extends Control
## 网络大厅：IP加入 / 局域网服务器 / 网络服务器

signal connect_to_server(ip: String, player_name: String)
signal back_pressed

# 模拟服务器列表（后期对接真实扫描/后端）
var lan_servers: Array = [
	{"name": "幸存者营地", "players": "2/4", "map": "废墟城市", "ping": 12, "ip": "192.168.1.10"},
	{"name": "末日避难所", "players": "3/4", "map": "森林小镇", "ping": 28, "ip": "192.168.1.22"},
]
var net_servers: Array = [
	{"name": "官方服务器1", "players": "45/100", "map": "废墟城市", "ping": 45, "ip": "101.200.1.10"},
	{"name": "官方服务器2", "players": "23/100", "map": "沙漠据点", "ping": 68, "ip": "101.200.1.20"},
	{"name": "社区服务器", "players": "8/32", "map": "森林小镇", "ping": 120, "ip": "118.25.1.30"},
]

var selected_lan_index: int = -1
var selected_net_index: int = -1
var is_connecting: bool = false

@onready var tab_container: TabContainer = $MainPanel/TabContainer
@onready var ip_input: LineEdit = $MainPanel/TabContainer/IPTab/VBox/IPInput
@onready var port_input: LineEdit = $MainPanel/TabContainer/IPTab/VBox/PortInput
@onready var ip_name_input: LineEdit = $MainPanel/TabContainer/IPTab/VBox/NameInput
@onready var ip_connect_btn: Button = $MainPanel/TabContainer/IPTab/VBox/ConnectBtn
@onready var lan_list: VBoxContainer = $MainPanel/TabContainer/LanTab/Scroll/ServerList
@onready var lan_refresh_btn: Button = $MainPanel/TabContainer/LanTab/ButtonRow/RefreshBtn
@onready var lan_connect_btn: Button = $MainPanel/TabContainer/LanTab/ButtonRow/ConnectBtn
@onready var net_list: VBoxContainer = $MainPanel/TabContainer/NetTab/Scroll/ServerList
@onready var net_refresh_btn: Button = $MainPanel/TabContainer/NetTab/ButtonRow/RefreshBtn
@onready var net_connect_btn: Button = $MainPanel/TabContainer/NetTab/ButtonRow/ConnectBtn
@onready var status_label: Label = $StatusBar/StatusLabel
@onready var back_button: Button = $BackButton


func _ready() -> void:
	ip_input.text = "127.0.0.1"
	port_input.text = "7777"
	ip_name_input.text = "Player%d" % randi_range(1, 99)
	ip_connect_btn.pressed.connect(_on_ip_connect)
	lan_refresh_btn.pressed.connect(_on_lan_refresh)
	lan_connect_btn.pressed.connect(_on_lan_connect)
	net_refresh_btn.pressed.connect(_on_net_refresh)
	net_connect_btn.pressed.connect(_on_net_connect)
	back_button.pressed.connect(_on_back_pressed)
	# 监听连接状态
	if multiplayer:
		multiplayer.connected_to_server.connect(_on_connected_to_server)
		multiplayer.connection_failed.connect(_on_connection_failed)
	_build_lan_servers()
	_build_net_servers()
	_update_connect_buttons()


func _build_lan_servers() -> void:
	for child in lan_list.get_children():
		child.queue_free()
	for i in range(lan_servers.size()):
		var server: Dictionary = lan_servers[i]
		var panel: Panel = Panel.new()
		panel.custom_minimum_size = Vector2(0, 56)
		panel.name = "Server%d" % i
		var hbox: HBoxContainer = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		panel.add_child(hbox)
		var name_label: Label = Label.new()
		name_label.text = server.name
		name_label.custom_minimum_size = Vector2(140, 0)
		name_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
		name_label.add_theme_font_size_override("font_size", 14)
		hbox.add_child(name_label)
		var players_label: Label = Label.new()
		players_label.text = server.players
		players_label.custom_minimum_size = Vector2(60, 0)
		players_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.7))
		hbox.add_child(players_label)
		var map_label: Label = Label.new()
		map_label.text = server.map
		map_label.custom_minimum_size = Vector2(100, 0)
		map_label.add_theme_color_override("font_color", Color(0.7, 0.68, 0.65))
		hbox.add_child(map_label)
		var ping_label: Label = Label.new()
		ping_label.text = "%dms" % server.ping
		ping_label.custom_minimum_size = Vector2(60, 0)
		ping_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		ping_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.9))
		hbox.add_child(ping_label)
		panel.gui_input.connect(func(event): _on_server_clicked(event, i, "lan"))
		lan_list.add_child(panel)


func _build_net_servers() -> void:
	for child in net_list.get_children():
		child.queue_free()
	for i in range(net_servers.size()):
		var server: Dictionary = net_servers[i]
		var panel: Panel = Panel.new()
		panel.custom_minimum_size = Vector2(0, 56)
		panel.name = "Server%d" % i
		var hbox: HBoxContainer = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		panel.add_child(hbox)
		var name_label: Label = Label.new()
		name_label.text = server.name
		name_label.custom_minimum_size = Vector2(140, 0)
		name_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
		name_label.add_theme_font_size_override("font_size", 14)
		hbox.add_child(name_label)
		var players_label: Label = Label.new()
		players_label.text = server.players
		players_label.custom_minimum_size = Vector2(60, 0)
		players_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.7))
		hbox.add_child(players_label)
		var map_label: Label = Label.new()
		map_label.text = server.map
		map_label.custom_minimum_size = Vector2(100, 0)
		map_label.add_theme_color_override("font_color", Color(0.7, 0.68, 0.65))
		hbox.add_child(map_label)
		var ping_label: Label = Label.new()
		ping_label.text = "%dms" % server.ping
		ping_label.custom_minimum_size = Vector2(60, 0)
		ping_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		ping_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.9))
		hbox.add_child(ping_label)
		panel.gui_input.connect(func(event): _on_server_clicked(event, i, "net"))
		net_list.add_child(panel)


func _on_server_clicked(event: InputEvent, index: int, server_type: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if server_type == "lan":
			selected_lan_index = index
			selected_net_index = -1
			_highlight_server(lan_list, index)
			_highlight_server(net_list, -1)
		else:
			selected_net_index = index
			selected_lan_index = -1
			_highlight_server(net_list, index)
			_highlight_server(lan_list, -1)
		_update_connect_buttons()
		if event.double_click:
			if server_type == "lan":
				_on_lan_connect()
			else:
				_on_net_connect()


func _highlight_server(list: VBoxContainer, index: int) -> void:
	for i in range(list.get_child_count()):
		var panel: Panel = list.get_child(i)
		if i == index:
			panel.modulate = Color(1, 0.95, 0.7)
		else:
			panel.modulate = Color.WHITE


func _update_connect_buttons() -> void:
	lan_connect_btn.disabled = selected_lan_index < 0 or is_connecting
	net_connect_btn.disabled = selected_net_index < 0 or is_connecting
	ip_connect_btn.disabled = is_connecting


func _on_ip_connect() -> void:
	var ip: String = ip_input.text.strip_edges()
	var player_name: String = ip_name_input.text.strip_edges()
	if ip.is_empty():
		_set_status("请输入服务器IP地址", Color(1, 0.5, 0.4))
		return
	if player_name.is_empty():
		player_name = "Player"
	_start_connect(ip, player_name)


func _on_lan_connect() -> void:
	if selected_lan_index < 0:
		return
	var server: Dictionary = lan_servers[selected_lan_index]
	_start_connect(server.ip, "Player")


func _on_net_connect() -> void:
	if selected_net_index < 0:
		return
	var server: Dictionary = net_servers[selected_net_index]
	_start_connect(server.ip, "Player")


func _start_connect(ip: String, player_name: String) -> void:
	is_connecting = true
	_update_connect_buttons()
	_set_status("正在连接 %s ..." % ip, Color(0.8, 0.8, 0.5))
	# 存储IP和玩家名，切换到准备大厅（加入模式）
	# 准备大厅会读取这些全局变量
	LobbyMenu.pending_server_ip = ip
	LobbyMenu.pending_player_name = player_name
	# 延迟一下显示连接状态，然后切换场景
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://scenes/ui/lobby_menu.tscn")


func _on_connected_to_server() -> void:
	is_connecting = false
	_set_status("连接成功，正在同步...", Color(0.5, 1, 0.5))
	_update_connect_buttons()


func _on_connection_failed() -> void:
	is_connecting = false
	_set_status("连接失败：超时或服务器无响应", Color(1, 0.5, 0.4))
	_update_connect_buttons()


func _on_lan_refresh() -> void:
	_set_status("正在扫描局域网服务器...", Color(0.8, 0.8, 0.5))
	# 后期实现UDP广播扫描，现在刷新模拟数据
	await get_tree().create_timer(1.0).timeout
	_build_lan_servers()
	_set_status("扫描完成，发现 %d 个服务器" % lan_servers.size(), Color(0.5, 1, 0.5))


func _on_net_refresh() -> void:
	_set_status("正在获取网络服务器列表...", Color(0.8, 0.8, 0.5))
	await get_tree().create_timer(1.0).timeout
	_build_net_servers()
	_set_status("刷新完成，共 %d 个服务器" % net_servers.size(), Color(0.5, 1, 0.5))


func _set_status(text: String, color: Color) -> void:
	status_label.text = text
	status_label.add_theme_color_override("font_color", color)


func _on_back_pressed() -> void:
	# 返回主菜单
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
