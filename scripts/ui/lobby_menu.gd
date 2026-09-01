extends Control
class_name LobbyMenu
## 准备大厅：职业选择 + 玩家配置 + 玩家坑位
## 两种模式：create（创建游戏）/ join（加入游戏）
## 支持多人网络同步：玩家加入/离开、准备状态、开始游戏

signal start_game(player_name: String, player_class: String)
signal join_game(player_name: String, player_class: String)
signal back_pressed

# 静态变量：网络大厅传递过来的待连接信息
static var pending_server_ip: String = ""
static var pending_player_name: String = ""

# 模式
enum Mode { CREATE, JOIN }
var current_mode: Mode = Mode.CREATE

# 服务器IP（仅join模式用）
var server_ip: String = ""

# 选中的职业
var selected_class: String = "warrior"

# 玩家准备状态（本地缓存）
var is_ready: bool = false

# 职业定义
const CLASSES := {
	"warrior": {"name": "战士", "desc": "战斗属性高，能改造高级武器。擅长近战和防御，是团队的主要战斗力。"},
	"craftsman": {"name": "工匠", "desc": "建造时间减半，能建造高级建筑。其他人无法建造高级建筑。"},
	"doctor": {"name": "医生", "desc": "能治疗和制药，救人。倒地玩家只有医生能救起。"},
	"farmer": {"name": "农民", "desc": "能种植农作物，其他人不能种植。需要寻找农业书籍解锁。"},
	"mechanic": {"name": "汽修工", "desc": "能修理和改装载具，其他人不能修车。地图残骸只有汽修工能拆卸。"},
	"chef": {"name": "厨师", "desc": "能做高级食物，烹饪效率高。高级食物可以恢复生命值。"},
	"lumberjack": {"name": "伐木工", "desc": "力量高，获取资源效率高。伐木和采矿速度比其他职业快。"},
	"engineer": {"name": "工程师", "desc": "能建造电力系统和自动化防御。发电机、炮塔等只有工程师能建造。"},
}

# 节点引用
@onready var title_label: Label = $TitleLabel
@onready var class_grid: GridContainer = $MainContainer/LeftPanel/VBox/ClassScroll/ClassGrid
@onready var name_input: LineEdit = $MainContainer/LeftPanel/VBox/NameInput
@onready var class_image: ColorRect = $MainContainer/RightPanel/VBox/ClassImage
@onready var class_desc_label: Label = $MainContainer/RightPanel/VBox/ClassDescLabel
@onready var slots_grid: GridContainer = $MainContainer/BottomLeftPanel/VBox/SlotsGrid
@onready var ready_button: Button = $MainContainer/BottomRightPanel/VBox/ReadyButton
@onready var start_button: Button = $MainContainer/BottomRightPanel/VBox/StartButton
@onready var back_button: Button = $MainContainer/BottomRightPanel/VBox/BackButton
@onready var kick_popup: PopupPanel = $KickPopup
@onready var kick_button: Button = $KickPopup/VBox/KickBtn
@onready var kick_cancel_button: Button = $KickPopup/VBox/CancelBtn

var _selected_slot_index: int = -1
var _slot_panels: Array = []
var _slot_peer_ids: Array = []  # 每个坑位对应的peer_id


func _ready() -> void:
	_build_class_buttons()
	_build_empty_slots()
	_update_class_selection()
	_update_button_visibility()
	# 默认玩家名
	name_input.text = "Player%d" % randi_range(1, 99)
	# 信号连接
	start_button.pressed.connect(_on_start_pressed)
	ready_button.pressed.connect(_on_ready_pressed)
	back_button.pressed.connect(_on_back_pressed)
	kick_button.pressed.connect(_on_kick_confirmed)
	kick_cancel_button.pressed.connect(func(): kick_popup.hide())
	# 监听GameManager的准备大厅信号
	if GameManager:
		GameManager.lobby_player_joined.connect(_on_lobby_players_changed)
		GameManager.lobby_player_left.connect(_on_lobby_players_changed)
		GameManager.lobby_ready_changed.connect(_on_lobby_ready_changed)
	# 监听连接失败
	if multiplayer:
		multiplayer.connection_failed.connect(_on_connection_failed)
	# 检查是否从网络大厅传递了待连接信息
	if not pending_server_ip.is_empty():
		var ip: String = pending_server_ip
		var pname: String = pending_player_name
		pending_server_ip = ""
		pending_player_name = ""
		setup_mode(Mode.JOIN, ip)
		if not pname.is_empty():
			name_input.text = pname
		# 加入模式：连接服务器
		title_label.text = "正在连接 %s ..." % ip
		if GameManager:
			var player_name: String = name_input.text.strip_edges()
			if player_name.is_empty():
				player_name = "Player"
			GameManager.join_game(ip, player_name, selected_class)
	else:
		setup_mode(Mode.CREATE)
		# 创建模式：创建主机（不立即进入游戏，停留在准备大厅）
		if GameManager:
			var player_name: String = name_input.text.strip_edges()
			if player_name.is_empty():
				player_name = "Player"
			GameManager.host_game(player_name, selected_class)
	# 延迟刷新坑位（确保GameManager状态已同步）
	await get_tree().process_frame
	_refresh_slots_from_network()
	# 加入模式下，连接成功后恢复标题
	if current_mode == Mode.JOIN:
		title_label.text = "加入游戏 - 准备大厅"


func setup_mode(mode: Mode, ip: String = "") -> void:
	current_mode = mode
	server_ip = ip
	if mode == Mode.CREATE:
		title_label.text = "创建游戏 - 准备大厅"
	else:
		title_label.text = "加入游戏 - 准备大厅"
	_update_button_visibility()


func _build_class_buttons() -> void:
	for child in class_grid.get_children():
		child.queue_free()
	for class_id in CLASSES.keys():
		var class_data: Dictionary = CLASSES[class_id]
		var btn: Button = Button.new()
		btn.text = class_data.name
		btn.custom_minimum_size = Vector2(100, 40)
		btn.name = class_id
		btn.pressed.connect(_on_class_selected.bind(class_id))
		class_grid.add_child(btn)


func _build_empty_slots() -> void:
	## 构建8个空坑位
	_slot_panels.clear()
	_slot_peer_ids.clear()
	for i in range(8):
		_slot_peer_ids.append(0)
		var slot: Panel = Panel.new()
		slot.custom_minimum_size = Vector2(140, 60)
		slot.name = "Slot%d" % i
		var vbox: VBoxContainer = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 2)
		slot.add_child(vbox)
		var name_label: Label = Label.new()
		name_label.text = "空坑位"
		name_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(name_label)
		var status_label: Label = Label.new()
		status_label.text = ""
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(status_label)
		slot.gui_input.connect(func(event): _on_slot_clicked(event, i))
		slots_grid.add_child(slot)
		_slot_panels.append({"panel": slot, "name_label": name_label, "status_label": status_label})


func _refresh_slots_from_network() -> void:
	## 从GameManager.lobby_players读取数据，更新坑位显示
	if not GameManager:
		return
	var players: Dictionary = GameManager.lobby_players
	var peer_ids: Array = players.keys()
	peer_ids.sort()
	# 清空所有坑位
	for i in range(8):
		_slot_peer_ids[i] = 0
		_set_slot_display(i, "空坑位", "", Color(0.5, 0.5, 0.5), false, false)
	# 填充玩家
	var slot_idx: int = 0
	for pid in peer_ids:
		if slot_idx >= 8:
			break
		var pdata: Dictionary = players[pid]
		var pname: String = pdata.get("name", "Player")
		var pclass: String = pdata.get("class", "warrior")
		var pready: bool = pdata.get("ready", false)
		var is_host: bool = (pid == 1)
		var class_display_name: String = CLASSES.get(pclass, {}).get("name", pclass)
		_slot_peer_ids[slot_idx] = pid
		_set_slot_display(slot_idx, "%s (%s)" % [pname, class_display_name], "", Color(0.9, 0.85, 0.7), is_host, pready)
		slot_idx += 1
	# 更新开始按钮状态
	_update_start_button_state()


func _set_slot_display(index: int, name_text: String, status_text: String, name_color: Color, is_host: bool, is_ready: bool) -> void:
	if index < 0 or index >= _slot_panels.size():
		return
	var slot_data: Dictionary = _slot_panels[index]
	slot_data.name_label.text = name_text
	slot_data.name_label.add_theme_color_override("font_color", name_color)
	if is_host:
		slot_data.status_label.text = "【主机】"
		slot_data.status_label.add_theme_color_override("font_color", Color(1, 0.8, 0.4))
	elif is_ready:
		slot_data.status_label.text = "已准备"
		slot_data.status_label.add_theme_color_override("font_color", Color(0.5, 1, 0.5))
	elif status_text != "":
		slot_data.status_label.text = status_text
	else:
		slot_data.status_label.text = "未准备"
		slot_data.status_label.add_theme_color_override("font_color", Color(0.8, 0.5, 0.5))


func _update_class_selection() -> void:
	for btn in class_grid.get_children():
		if btn is Button:
			if btn.name == selected_class:
				btn.modulate = Color(1, 0.9, 0.6)
			else:
				btn.modulate = Color.WHITE
	var class_data: Dictionary = CLASSES.get(selected_class, {})
	class_desc_label.text = class_data.get("desc", "")
	class_image.modulate = _get_class_color(selected_class)


func _get_class_color(class_id: String) -> Color:
	match class_id:
		"warrior": return Color(0.7, 0.2, 0.2)
		"craftsman": return Color(0.8, 0.7, 0.2)
		"doctor": return Color(0.9, 0.2, 0.2)
		"farmer": return Color(0.5, 0.6, 0.2)
		"mechanic": return Color(0.2, 0.5, 0.8)
		"chef": return Color(0.9, 0.5, 0.2)
		"lumberjack": return Color(0.5, 0.35, 0.2)
		"engineer": return Color(0.2, 0.7, 0.7)
	return Color.GRAY


func _update_button_visibility() -> void:
	if current_mode == Mode.CREATE:
		ready_button.visible = false
		start_button.text = "开始游戏"
	else:
		ready_button.visible = true
		start_button.text = "加入游戏"
		start_button.visible = false  # 客机不显示开始/加入按钮，由主机开始
	_update_ready_state()
	_update_start_button_state()


func _update_ready_state() -> void:
	if is_ready:
		ready_button.text = "取消准备"
		ready_button.modulate = Color(0.6, 1, 0.6)
	else:
		ready_button.text = "准备"
		ready_button.modulate = Color.WHITE


func _update_start_button_state() -> void:
	## 更新开始按钮的可点击状态
	if current_mode != Mode.CREATE:
		return
	if not GameManager or not GameManager.in_lobby:
		start_button.disabled = false
		return
	var players: Dictionary = GameManager.lobby_players
	var all_ready: bool = true
	var player_count: int = 0
	for pid in players.keys():
		player_count += 1
		if pid == 1:
			continue  # 主机默认准备
		if not players[pid].get("ready", false):
			all_ready = false
			break
	# 单人时可以直接开始；多人时需要所有人准备
	if player_count <= 1:
		start_button.disabled = false
	else:
		start_button.disabled = not all_ready


func _on_class_selected(class_id: String) -> void:
	selected_class = class_id
	_update_class_selection()
	# 如果是客机，职业变化后需要重新注册到主机
	if current_mode == Mode.JOIN and GameManager and GameManager.in_lobby:
		var pname: String = name_input.text.strip_edges()
		if pname.is_empty():
			pname = "Player"
		# 重新注册（更新职业）
		GameManager.player_names[GameManager.local_peer_id] = pname
		GameManager.player_classes[GameManager.local_peer_id] = class_id
		if GameManager.lobby_players.has(GameManager.local_peer_id):
			GameManager.lobby_players[GameManager.local_peer_id].class = class_id
		# 通过RPC重新注册
		GameManager._lobby_register.rpc_id(1, pname, class_id)


func _on_start_pressed() -> void:
	var player_name: String = name_input.text.strip_edges()
	if player_name.is_empty():
		player_name = "Player"
		name_input.text = player_name
	if current_mode == Mode.CREATE:
		# 主机开始游戏（会检查所有人准备状态）
		if GameManager:
			# 更新主机的名字和职业
			GameManager.player_names[1] = player_name
			GameManager.player_classes[1] = selected_class
			if GameManager.lobby_players.has(1):
				GameManager.lobby_players[1].name = player_name
				GameManager.lobby_players[1].class = selected_class
			GameManager.start_lobby_game()
	else:
		# 客机不应该走到这里（开始按钮隐藏）
		pass


func _on_ready_pressed() -> void:
	is_ready = not is_ready
	_update_ready_state()
	# 通知主机准备状态
	if GameManager and GameManager.in_lobby:
		GameManager.lobby_set_ready(is_ready)


func _on_back_pressed() -> void:
	# 返回主菜单，重置网络状态
	if GameManager:
		GameManager.reset_network_state()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _on_slot_clicked(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if current_mode == Mode.CREATE and index > 0:
			# 主机点击非自己的坑位，显示踢人弹窗
			var pid: int = _slot_peer_ids[index]
			if pid > 0 and pid != 1:
				_selected_slot_index = index
				kick_popup.position = get_viewport().get_mouse_position()
				kick_popup.show()


func _on_kick_confirmed() -> void:
	if _selected_slot_index >= 0 and _selected_slot_index < _slot_peer_ids.size():
		var pid: int = _slot_peer_ids[_selected_slot_index]
		if pid > 0 and GameManager:
			GameManager.lobby_kick_player(pid)
	kick_popup.hide()
	_selected_slot_index = -1


# ==================== GameManager信号处理 ====================

func _on_lobby_players_changed(_peer_id: int) -> void:
	## 大厅玩家列表变化（加入/离开）
	_refresh_slots_from_network()


func _on_lobby_ready_changed(_peer_id: int, _is_ready: bool) -> void:
	## 玩家准备状态变化
	_refresh_slots_from_network()


func _on_connection_failed() -> void:
	## 连接服务器失败
	if current_mode != Mode.JOIN:
		return
	title_label.text = "连接失败：服务器无响应"
	title_label.add_theme_color_override("font_color", Color(1, 0.5, 0.4))
	# 延迟返回网络大厅
	await get_tree().create_timer(2.0).timeout
	if GameManager:
		GameManager.reset_network_state()
	get_tree().change_scene_to_file("res://scenes/ui/network_lobby.tscn")
