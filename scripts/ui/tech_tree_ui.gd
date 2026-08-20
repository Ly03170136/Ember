extends Control
## 科技树UI：按T打开，显示公共科技和职业专属科技，可解锁科技

@onready var points_label: Label = $Panel/TopBar/PointsLabel
@onready var public_tab: Button = $Panel/TopBar/TabContainer/PublicTab
@onready var class_tab: Button = $Panel/TopBar/TabContainer/ClassTab
@onready var public_scroll: ScrollContainer = $Panel/PublicScroll
@onready var class_scroll: ScrollContainer = $Panel/ClassScroll
@onready var public_grid: GridContainer = $Panel/PublicScroll/PublicGrid
@onready var class_grid: GridContainer = $Panel/ClassScroll/ClassGrid
@onready var close_btn: Button = $Panel/TopBar/CloseBtn
@onready var desc_label: Label = $Panel/DescPanel/DescLabel

var is_open: bool = false
var current_tab: String = "public"
var selected_tech: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_to_group("ui_menu")
	# 连接按钮
	close_btn.pressed.connect(toggle)
	public_tab.pressed.connect(_on_public_tab)
	class_tab.pressed.connect(_on_class_tab)
	# 初始化
	_refresh_tech_tree()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_T:
			# T键打开或关闭科技树
			toggle()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and is_open:
			# ESC键只在科技树打开时关闭
			toggle()
			get_viewport().set_input_as_handled()


func toggle() -> void:
	is_open = not is_open
	visible = is_open
	# 播放菜单音效
	if AudioManager:
		if is_open:
			AudioManager.play_sfx(AudioManager.SFX.UI_OPEN)
		else:
			AudioManager.play_sfx(AudioManager.SFX.UI_CLOSE)
	if is_open:
		get_tree().paused = true
		_refresh_tech_tree()
	else:
		get_tree().paused = false


func _on_public_tab() -> void:
	current_tab = "public"
	public_scroll.visible = true
	class_scroll.visible = false
	_refresh_tech_tree()


func _on_class_tab() -> void:
	current_tab = "class"
	public_scroll.visible = false
	class_scroll.visible = true
	_refresh_tech_tree()


func _refresh_tech_tree() -> void:
	var player: Node = GameManager.get_local_player()
	if not player:
		return
	# 更新科技点
	points_label.text = "科技点: %d" % player.skill_points
	# 清空旧的
	for child in public_grid.get_children():
		child.queue_free()
	for child in class_grid.get_children():
		child.queue_free()
	# 生成公共科技
	var public_techs: Dictionary = TechTree.get_all_public_techs()
	for tech_id in public_techs.keys():
		var tech: Dictionary = public_techs[tech_id]
		var btn: Button = _create_tech_button(tech_id, tech, player)
		public_grid.add_child(btn)
	# 生成职业专属科技
	var player_class: String = player.player_class
	var class_techs: Dictionary = TechTree.get_class_techs(player_class)
	for tech_id in class_techs.keys():
		var tech: Dictionary = class_techs[tech_id]
		var btn: Button = _create_tech_button(tech_id, tech, player)
		class_grid.add_child(btn)


func _create_tech_button(tech_id: String, tech: Dictionary, player: Node) -> Button:
	var btn := Button.new()
	var is_unlocked: bool = tech_id in player.unlocked_techs
	var can_unlock: bool = TechTree.can_unlock_tech(tech_id, player)
	# 按钮文本
	var tier_text: String = "T%d" % tech.get("tier", 1)
	btn.text = "%s\n%s\n(%d点)" % [tier_text, tech.name, tech.get("cost", 1)]
	btn.custom_minimum_size = Vector2(120, 60)
	# 颜色状态
	if is_unlocked:
		btn.modulate = Color(0.5, 1.0, 0.5)  # 绿色=已解锁
	elif can_unlock:
		btn.modulate = Color(1.0, 1.0, 0.7)  # 黄色=可解锁
	else:
		btn.modulate = Color(0.7, 0.7, 0.7)  # 灰色=不可解锁
	# 点击事件
	btn.pressed.connect(func(): _on_tech_clicked(tech_id, tech, player))
	return btn


func _on_tech_clicked(tech_id: String, tech: Dictionary, player: Node) -> void:
	selected_tech = tech_id
	var is_unlocked: bool = tech_id in player.unlocked_techs
	var can_unlock: bool = TechTree.can_unlock_tech(tech_id, player)
	# 显示描述
	var desc: String = "【%s】\n\n%s\n\n" % [tech.name, tech.desc]
	desc += "消耗: %d 科技点\n" % tech.get("cost", 1)
	desc += "层级: T%d\n" % tech.get("tier", 1)
	if tech.has("requires") and tech.requires.size() > 0:
		desc += "前置: "
		for req in tech.requires:
			desc += TechTree.get_tech_name(req) + " "
		desc += "\n"
	desc += "\n状态: "
	if is_unlocked:
		desc += "已解锁 ✓"
	elif can_unlock:
		desc += "可解锁（点击解锁）"
		# 尝试解锁
		if TechTree.unlock_tech(tech_id, player):
			desc += "\n\n解锁成功！"
			_refresh_tech_tree()
	else:
		desc += "条件不足 ✗"
	desc_label.text = desc
