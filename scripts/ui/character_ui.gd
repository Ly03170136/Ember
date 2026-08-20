extends Control
## 人物属性UI面板：显示等级、经验、属性、属性点分配
## I键打开/关闭

var is_open: bool = false
var player: Node = null

@onready var panel: Panel = $Panel
@onready var name_label: Label = $Panel/InfoBar/NameLabel
@onready var class_label: Label = $Panel/InfoBar/ClassLabel
@onready var level_label: Label = $Panel/InfoBar/LevelRow/LevelLabel
@onready var exp_bar: ProgressBar = $Panel/InfoBar/LevelRow/ExpBar
@onready var exp_label: Label = $Panel/InfoBar/ExpLabel
@onready var attr_points_label: Label = $Panel/InfoBar/AttrPointsLabel
@onready var close_btn: Button = $Panel/Header/CloseBtn
@onready var strength_label: Label = $Panel/Attributes/Strength/Value
@onready var agility_label: Label = $Panel/Attributes/Agility/Value
@onready var vitality_label: Label = $Panel/Attributes/Vitality/Value
@onready var stealth_label: Label = $Panel/Attributes/Stealth/Value


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group("ui_menu")
	# 连接关闭按钮
	if close_btn:
		close_btn.pressed.connect(toggle)
	# 连接属性按钮
	if has_node("Panel/Attributes/Strength/AddBtn"):
		$Panel/Attributes/Strength/AddBtn.pressed.connect(_on_add_strength)
	if has_node("Panel/Attributes/Agility/AddBtn"):
		$Panel/Attributes/Agility/AddBtn.pressed.connect(_on_add_agility)
	if has_node("Panel/Attributes/Vitality/AddBtn"):
		$Panel/Attributes/Vitality/AddBtn.pressed.connect(_on_add_vitality)
	if has_node("Panel/Attributes/Stealth/AddBtn"):
		$Panel/Attributes/Stealth/AddBtn.pressed.connect(_on_add_stealth)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_I:
			toggle()
			get_viewport().set_input_as_handled()


func toggle() -> void:
	is_open = not is_open
	panel.visible = is_open
	if AudioManager:
		if is_open:
			AudioManager.play_sfx(AudioManager.SFX.UI_OPEN)
		else:
			AudioManager.play_sfx(AudioManager.SFX.UI_CLOSE)
	if is_open:
		mouse_filter = Control.MOUSE_FILTER_STOP
		move_to_front()
		# 关闭其他菜单
		var hud: Node = get_parent()
		if hud:
			for menu_name in ["InventoryUI", "CraftUI", "BuildUI", "MapUI"]:
				var menu = hud.get_node_or_null(menu_name)
				if menu and menu.is_open:
					menu.is_open = false
					if "panel" in menu:
						menu.panel.visible = false
					menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
		refresh()
	else:
		mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_player(p: Node) -> void:
	player = p
	refresh()


func refresh() -> void:
	if not player or not is_instance_valid(player):
		return
	# 基本信息
	name_label.text = player.player_name
	level_label.text = "等级 %d" % player.level
	# 经验条
	exp_bar.max_value = player.experience_to_next
	exp_bar.value = player.experience
	exp_label.text = "经验: %.0f / %.0f" % [player.experience, player.experience_to_next]
	# 属性点
	attr_points_label.text = "可用属性点: %d" % player.attribute_points
	# 属性值
	strength_label.text = str(player.strength)
	agility_label.text = str(player.agility)
	vitality_label.text = str(player.vitality)
	stealth_label.text = str(player.stealth)
	# 属性加成显示
	if has_node("Panel/Attributes/Strength/Bonus"):
		$Panel/Attributes/Strength/Bonus.text = "+%d%% 伤害" % int((player.strength - 5) * 2)
	if has_node("Panel/Attributes/Agility/Bonus"):
		$Panel/Attributes/Agility/Bonus.text = "+%d%% 速度" % int((player.agility - 5) * 1.5)
	if has_node("Panel/Attributes/Vitality/Bonus"):
		$Panel/Attributes/Vitality/Bonus.text = "+%d 生命" % int((player.vitality - 5) * 10)
	if has_node("Panel/Attributes/Stealth/Bonus"):
		$Panel/Attributes/Stealth/Bonus.text = "-%d%% 被发现" % int((1.0 - player.get_stealth_multiplier()) * 100)


func _on_add_strength() -> void:
	if player and player.spend_attribute_point("strength"):
		refresh()
		if AudioManager:
			AudioManager.play_sfx(AudioManager.SFX.SUCCESS)


func _on_add_agility() -> void:
	if player and player.spend_attribute_point("agility"):
		refresh()
		if AudioManager:
			AudioManager.play_sfx(AudioManager.SFX.SUCCESS)


func _on_add_vitality() -> void:
	if player and player.spend_attribute_point("vitality"):
		refresh()
		if AudioManager:
			AudioManager.play_sfx(AudioManager.SFX.SUCCESS)


func _on_add_stealth() -> void:
	if player and player.spend_attribute_point("stealth"):
		refresh()
		if AudioManager:
			AudioManager.play_sfx(AudioManager.SFX.SUCCESS)
