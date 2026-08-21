extends Control
## 主菜单：一级菜单（创建/加入）+ 二级菜单（职业选择）

# 一级菜单节点
@onready var main_panel: Panel = $MainPanel
@onready var name_input: LineEdit = $MainPanel/VBox/NameInput
@onready var host_button: Button = $MainPanel/VBox/HostButton
@onready var ip_input: LineEdit = $MainPanel/VBox/IPRow/IPInput
@onready var join_button: Button = $MainPanel/VBox/IPRow/JoinButton
@onready var status_label: Label = $MainPanel/VBox/StatusLabel

# 二级菜单节点
@onready var class_select_panel: Panel = $ClassSelectPanel
@onready var player_name_label: Label = $ClassSelectPanel/VBox/PlayerNameLabel
@onready var class_grid: GridContainer = $ClassSelectPanel/VBox/ClassGrid
@onready var selected_class_label: Label = $ClassSelectPanel/VBox/SelectedClassLabel
@onready var class_desc_label: Label = $ClassSelectPanel/VBox/ClassDescLabel
@onready var back_button: Button = $ClassSelectPanel/VBox/ButtonRow/BackButton
@onready var start_button: Button = $ClassSelectPanel/VBox/ButtonRow/StartButton

var selected_class: String = "warrior"
const CLASS_MAP := {
	"战士": "warrior",
	"工匠": "craftsman",
	"医生": "doctor",
	"农民": "farmer",
	"汽修工": "mechanic",
	"厨师": "chef",
	"伐木工": "lumberjack",
	"工程师": "engineer",
}
const CLASS_DESC := {
	"warrior": "战斗属性高，能改造高级武器。擅长近战和防御，是团队的主要战斗力。",
	"craftsman": "建造时间减半，能建造高级建筑。其他人无法建造高级建筑。",
	"doctor": "能治疗和制药，救人。倒地玩家只有医生能救起，其他人无法治疗。",
	"farmer": "能种植农作物，其他人不能种植。需要寻找农业书籍才能解锁。",
	"mechanic": "能修理和改装载具，其他人不能修车。地图残骸只有汽修工能拆卸。",
	"chef": "能做高级食物，烹饪效率高。高级食物可以恢复生命值。",
	"lumberjack": "力量高，获取资源效率高。伐木和采矿速度比其他职业快。",
	"engineer": "能建造电力系统和自动化防御。发电机、炮塔等只有工程师能建造。",
}


func _ready() -> void:
	# 确保游戏未暂停（从游戏返回主菜单时可能处于暂停状态）
	get_tree().paused = false
	# 一级菜单按钮
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	name_input.text = "Player%d" % randi_range(1, 99)
	ip_input.text = "127.0.0.1"
	status_label.text = ""

	# 二级菜单按钮
	back_button.pressed.connect(_on_back_pressed)
	start_button.pressed.connect(_on_start_pressed)

	# 职业按钮
	for btn in class_grid.get_children():
		if btn is Button:
			btn.pressed.connect(_on_class_selected.bind(btn.text))

	# 默认选中战士
	_update_class_selection()


# ==================== 一级菜单 ====================

func _on_host_pressed() -> void:
	var name := name_input.text.strip_edges()
	if name.is_empty():
		name = "Host"
		name_input.text = name
	# 进入二级职业选择菜单
	player_name_label.text = "玩家：%s" % name
	main_panel.visible = false
	class_select_panel.visible = true


func _on_join_pressed() -> void:
	var name := name_input.text.strip_edges()
	if name.is_empty():
		name = "Guest"
	var ip := ip_input.text.strip_edges()
	if ip.is_empty():
		status_label.text = "请输入主机IP地址"
		return
	status_label.text = "正在连接 %s..." % ip
	# 加入游戏默认用战士职业
	GameManager.join_game(ip, name, "warrior")
	await get_tree().create_timer(3.0).timeout
	if not GameManager.is_connected:
		status_label.text = "连接失败，请检查IP和网络"


# ==================== 二级菜单 ====================

func _on_back_pressed() -> void:
	# 返回一级菜单
	class_select_panel.visible = false
	main_panel.visible = true


func _on_start_pressed() -> void:
	var name := name_input.text.strip_edges()
	if name.is_empty():
		name = "Host"
	status_label.text = "正在创建主机..."
	# 使用选择的职业创建主机
	GameManager.host_game(name, selected_class)


func _on_class_selected(class_name_str: String) -> void:
	selected_class = CLASS_MAP.get(class_name_str, "warrior")
	_update_class_selection()


func _update_class_selection() -> void:
	selected_class_label.text = "当前职业：%s" % PlayerSprite.get_class_name(selected_class)
	class_desc_label.text = CLASS_DESC.get(selected_class, "")
	for btn in class_grid.get_children():
		if btn is Button:
			if CLASS_MAP.get(btn.text, "") == selected_class:
				btn.modulate = Color(0.6, 1, 0.6)
			else:
				btn.modulate = Color.WHITE
