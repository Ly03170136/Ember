extends CanvasLayer
## 游戏内调试控制台
## 通过聊天窗口输入 /开头的命令执行，如 /help, /spawn zombie 5
## （原~键打开控制台的功能已移除）

signal command_output(text: String, color: Color)  # 命令输出信号，供聊天系统使用

# ==================== 配置 ====================
const MAX_HISTORY := 50  # 最大历史命令数
const MAX_OUTPUT_LINES := 200  # 最大输出行数

# ==================== UI节点 ====================
var panel: Panel = null
var vbox: VBoxContainer = null
var output_label: RichTextLabel = null
var input_box: LineEdit = null
var scroll_container: ScrollContainer = null

# ==================== 状态 ====================
var is_open: bool = false
var command_history: Array = []
var history_index: int = -1
var commands: Dictionary = {}  # 命令字典 {命令名: 函数引用}

# 调试模式状态
var god_mode: bool = false
var fly_mode: bool = false
var show_fps: bool = false
var time_scale: float = 1.0

# 引用
var game_world: Node2D = null
var local_player: Node2D = null


func _ready() -> void:
	layer = 1000  # 确保在最上层
	_build_ui()
	_register_commands()
	hide()
	print("[DebugConsole] 调试控制台已初始化，按 `~` 键打开")


func _build_ui() -> void:
	## 构建控制台UI
	# 主面板
	panel = Panel.new()
	panel.name = "ConsolePanel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 20.0
	panel.offset_top = 20.0
	panel.offset_right = -20.0
	panel.offset_bottom = -20.0
	panel.modulate = Color(0.1, 0.1, 0.1, 0.92)
	add_child(panel)
	
	# 垂直布局
	vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 15.0
	vbox.offset_top = 15.0
	vbox.offset_right = -15.0
	vbox.offset_bottom = -15.0
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)
	
	# 标题
	var title_label: Label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "=== 余烬 EMBER 调试控制台 ==="
	title_label.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0))
	title_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title_label)
	
	# 输出区域滚动容器
	scroll_container = ScrollContainer.new()
	scroll_container.name = "OutputScroll"
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll_container)
	
	# 输出文本
	output_label = RichTextLabel.new()
	output_label.name = "OutputLabel"
	output_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	output_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	output_label.bbcode_enabled = true
	output_label.scroll_following = true
	output_label.add_theme_color_override("default_color", Color(0.9, 0.9, 0.9))
	output_label.add_theme_font_size_override("normal_font_size", 14)
	scroll_container.add_child(output_label)
	
	# 输入框
	input_box = LineEdit.new()
	input_box.name = "InputBox"
	input_box.placeholder_text = "输入命令，按回车执行，输入 help 查看所有命令..."
	input_box.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	input_box.add_theme_color_override("caret_color", Color(1.0, 1.0, 1.0))
	input_box.add_theme_font_size_override("font_size", 15)
	input_box.text_submitted.connect(_on_input_submitted)
	vbox.add_child(input_box)
	
	# 提示文字
	var hint_label: Label = Label.new()
	hint_label.name = "HintLabel"
	hint_label.text = "提示: ↑↓ 历史命令 | Tab 自动补全 | Esc 关闭"
	hint_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	hint_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(hint_label)


func _register_commands() -> void:
	## 注册所有命令
	# 基础命令
	commands["help"] = _cmd_help
	commands["clear"] = _cmd_clear
	commands["quit"] = _cmd_quit
	commands["fps"] = _cmd_fps
	commands["version"] = _cmd_version
	
	# 玩家相关
	commands["god"] = _cmd_god
	commands["fly"] = _cmd_fly
	commands["heal"] = _cmd_heal
	commands["give"] = _cmd_give
	commands["tp"] = _cmd_tp
	commands["whereami"] = _cmd_whereami
	commands["stats"] = _cmd_stats
	commands["setstat"] = _cmd_setstat
	
	# 世界相关
	commands["time"] = _cmd_time
	commands["timespeed"] = _cmd_timespeed
	commands["day"] = _cmd_day
	commands["night"] = _cmd_night
	commands["weather"] = _cmd_weather
	commands["season"] = _cmd_season
	commands["month"] = _cmd_month
	
	# 实体相关
	commands["killall"] = _cmd_killall
	commands["spawn"] = _cmd_spawn
	commands["count"] = _cmd_count
	
	# 系统相关
	commands["save"] = _cmd_save
	commands["load"] = _cmd_load
	commands["log"] = _cmd_log

	# 性能监控相关
	commands["perf"] = _cmd_perf
	commands["perfshow"] = _cmd_perf_show
	commands["perfhide"] = _cmd_perf_hide
	commands["perfstats"] = _cmd_perf_stats
	commands["perfreset"] = _cmd_perf_reset
	commands["perflog"] = _cmd_perf_log

	# 错误捕获与崩溃报告相关
	commands["errors"] = _cmd_errors
	commands["crashreports"] = _cmd_crash_reports
	commands["exportcrash"] = _cmd_export_crash
	commands["clearerrors"] = _cmd_clear_errors

	# 输入管理相关
	commands["input"] = _cmd_input
	commands["inputreset"] = _cmd_input_reset
	commands["inputlist"] = _cmd_input_list


func _input(event: InputEvent) -> void:
	## 处理输入（控制台打开时的特殊按键）
	# 注意：~键打开控制台的功能已移除，现在通过聊天窗口输入 /命令 执行
	# 控制台打开时处理特殊按键
	if is_open and event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_close()
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_UP:
			_history_up()
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_DOWN:
			_history_down()
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_TAB:
			_autocomplete()
			get_viewport().set_input_as_handled()
			return


func _toggle() -> void:
	## 切换控制台显示
	if is_open:
		_close()
	else:
		_open()


func _open() -> void:
	## 打开控制台
	is_open = true
	show()
	input_box.grab_focus()
	input_box.text = ""
	history_index = -1
	_print("控制台已打开，输入 help 查看命令", Color(0.5, 1.0, 0.5))
	# 暂停游戏（可选，这里不暂停以便实时调试）
	# get_tree().paused = true


func _close() -> void:
	## 关闭控制台
	is_open = false
	hide()
	input_box.release_focus()
	# get_tree().paused = false


func _on_input_submitted(text: String) -> void:
	## 输入提交处理
	if text.strip_edges() == "":
		return
	# 添加到历史
	_add_to_history(text)
	# 显示命令
	_print("> " + text, Color(1.0, 1.0, 0.7))
	# 执行命令
	_execute_command(text)
	# 清空输入
	input_box.text = ""


func execute_command_text(text: String) -> void:
	## 公共函数：执行命令文本（供聊天系统等外部调用）
	## 支持以 / 开头的命令，如 "/help", "/spawn zombie 5"
	var cmd_text: String = text.strip_edges()
	# 去掉开头的 /
	if cmd_text.begins_with("/"):
		cmd_text = cmd_text.substr(1)
	if cmd_text.is_empty():
		return
	# 显示命令（用黄色区分）
	_print("> /" + cmd_text, Color(1.0, 1.0, 0.7))
	# 执行命令
	_execute_command(cmd_text)


func _execute_command(text: String) -> void:
	## 执行命令
	var parts: PackedStringArray = text.strip_edges().split(" ", false)
	if parts.is_empty():
		return
	var cmd: String = parts[0].to_lower()
	var args: Array = []
	for i in range(1, parts.size()):
		args.append(parts[i])
	
	if commands.has(cmd):
		commands[cmd].call(args)
	else:
		_print("未知命令: " + cmd + "，输入 /help 查看所有命令", Color(1.0, 0.5, 0.5))


func _print(text: String, color: Color = Color(0.9, 0.9, 0.9)) -> void:
	## 输出文本到控制台
	# 发出信号，供聊天系统等外部使用
	command_output.emit(text, color)
	# 输出到控制台UI（如果存在）
	if not output_label:
		return
	var color_hex: String = "#%02x%02x%02x" % [
		int(color.r * 255), int(color.g * 255), int(color.b * 255)
	]
	output_label.append_text("[color=%s]%s[/color]\n" % [color_hex, text])
	# 限制最大行数
	var lines: PackedStringArray = output_label.text.split("\n")
	if lines.size() > MAX_OUTPUT_LINES:
		var new_text: String = ""
		for i in range(lines.size() - MAX_OUTPUT_LINES, lines.size()):
			new_text += lines[i] + "\n"
		output_label.text = new_text
	# 自动滚动到底部（延迟到下一帧，确保UI已更新）
	call_deferred("_scroll_to_bottom")


func _scroll_to_bottom() -> void:
	## 滚动到输出区域底部
	if scroll_container and is_instance_valid(scroll_container):
		var vbar: VScrollBar = scroll_container.get_v_scroll_bar()
		if vbar:
			scroll_container.scroll_vertical = vbar.max_value


func _add_to_history(text: String) -> void:
	## 添加命令到历史
	if command_history.size() > 0 and command_history[command_history.size() - 1] == text:
		return  # 不重复添加相同命令
	command_history.append(text)
	if command_history.size() > MAX_HISTORY:
		command_history.pop_front()


func _history_up() -> void:
	## 上一条历史命令
	if command_history.is_empty():
		return
	if history_index == -1:
		history_index = command_history.size() - 1
	elif history_index > 0:
		history_index -= 1
	input_box.text = command_history[history_index]
	input_box.caret_column = input_box.text.length()


func _history_down() -> void:
	## 下一条历史命令
	if command_history.is_empty() or history_index == -1:
		return
	if history_index < command_history.size() - 1:
		history_index += 1
		input_box.text = command_history[history_index]
	else:
		history_index = -1
		input_box.text = ""
	input_box.caret_column = input_box.text.length()


func _autocomplete() -> void:
	## 自动补全
	var current: String = input_box.text.to_lower()
	if current == "":
		return
	var matches: Array = []
	for cmd in commands.keys():
		if cmd.begins_with(current):
			matches.append(cmd)
	if matches.size() == 1:
		input_box.text = matches[0] + " "
		input_box.caret_column = input_box.text.length()
	elif matches.size() > 1:
		_print("可能的命令: " + ", ".join(matches), Color(0.7, 0.7, 1.0))


# ==================== 命令实现 ====================

func _cmd_help(args: Array) -> void:
	## 显示帮助
	_print("=== 可用命令列表 ===", Color(0.8, 0.8, 1.0))
	_print("【基础命令】", Color(0.6, 1.0, 0.6))
	_print("  help       - 显示此帮助信息")
	_print("  clear      - 清空控制台输出")
	_print("  quit       - 退出游戏")
	_print("  fps        - 切换FPS显示")
	_print("  version    - 显示游戏版本")
	_print("【玩家命令】", Color(0.6, 1.0, 0.6))
	_print("  god        - 切换无敌模式")
	_print("  fly        - 切换飞行模式")
	_print("  heal       - 恢复满状态")
	_print("  give <物品> <数量> - 给予物品")
	_print("  tp <x> <y> - 传送到指定坐标")
	_print("  whereami   - 显示当前位置")
	_print("  stats      - 显示玩家属性")
	_print("  setstat <属性> <值> - 设置属性值")
	_print("【世界命令】", Color(0.6, 1.0, 0.6))
	_print("  time <0-1> - 设置时间（0=黎明, 0.5=正午, 1=次日黎明）")
	_print("  timespeed <倍率> - 设置时间流速")
	_print("  day        - 跳到白天")
	_print("  night      - 跳到夜晚")
	_print("  weather <类型> - 设置天气（clear/cloudy/rain/storm/snow/fog）")
	_print("  season <季节> - 设置季节（spring/summer/autumn/winter）")
	_print("  month <1-12> - 设置月份")
	_print("【实体命令】", Color(0.6, 1.0, 0.6))
	_print("  killall    - 杀死所有丧尸")
	_print("  spawn <类型> <数量> - 生成实体（zombie/tree/rock/npc）")
	_print("  count      - 统计实体数量")
	_print("【系统命令】", Color(0.6, 1.0, 0.6))
	_print("  save [存档位]  - 保存游戏（存档位0-2，默认0）")
	_print("  load [存档位]  - 读取游戏数据（存档位0-2，默认0）")
	_print("  log <级别> - 设置日志级别（debug/info/warning/error）")
	_print("【性能监控命令】", Color(0.6, 1.0, 0.6))
	_print("  perf       - 切换性能监控显示（快捷键F3）")
	_print("  perfshow   - 显示性能监控")
	_print("  perfhide   - 隐藏性能监控")
	_print("  perfstats  - 显示详细性能统计")
	_print("  perfreset  - 重置性能统计数据")
	_print("  perflog    - 记录当前性能到日志")
	_print("【错误捕获命令】", Color(0.6, 1.0, 0.6))
	_print("  errors     - 查看错误统计")
	_print("  crashreports - 查看崩溃报告列表")
	_print("  exportcrash - 导出最近一次崩溃报告")
	_print("  clearerrors - 清除错误统计")
	_print("【输入管理命令】", Color(0.6, 1.0, 0.6))
	_print("  input      - 查看输入管理状态")
	_print("  inputlist  - 列出所有动作绑定")
	_print("  inputreset - 重置输入配置为默认")
	_print("====================", Color(0.8, 0.8, 1.0))


func _cmd_clear(args: Array) -> void:
	## 清空输出
	output_label.clear()


func _cmd_quit(args: Array) -> void:
	## 退出游戏
	_print("正在退出游戏...", Color(1.0, 0.7, 0.5))
	get_tree().quit()


func _cmd_fps(args: Array) -> void:
	## 切换FPS显示
	show_fps = not show_fps
	Engine.set_max_fps(0 if show_fps else 60)
	_print("FPS显示: " + ("开启" if show_fps else "关闭"), Color(0.5, 1.0, 0.5))


func _cmd_version(args: Array) -> void:
	## 显示版本
	_print("游戏版本: 余烬 EMBER v0.9", Color(0.8, 0.8, 1.0))
	_print("Godot版本: " + Engine.get_version_info()["string"], Color(0.8, 0.8, 1.0))


func _cmd_god(args: Array) -> void:
	## 无敌模式（恢复满状态，真正无敌需在player.gd中集成）
	god_mode = not god_mode
	var player: Node2D = _get_local_player()
	if player:
		# 恢复满状态
		player.health = player.max_health
		player.hunger = player.max_hunger
		player.thirst = player.max_thirst
		player.stamina = player.max_stamina
		player.sanity = 100.0
		player.is_down = false
	if god_mode:
		_print("无敌模式: 开启（已恢复满状态，真正无敌需在player.gd中集成take_damage检查）", Color(1.0, 0.8, 0.3))
	else:
		_print("无敌模式: 关闭", Color(1.0, 0.8, 0.3))


func _cmd_fly(args: Array) -> void:
	## 飞行模式
	fly_mode = not fly_mode
	var player: Node2D = _get_local_player()
	if player:
		if fly_mode:
			player.set_collision_layer(0)
			player.set_collision_mask(0)
		else:
			player.set_collision_layer(1)
			player.set_collision_mask(1)
	_print("飞行模式: " + ("开启" if fly_mode else "关闭"), Color(0.5, 0.8, 1.0))


func _cmd_heal(args: Array) -> void:
	## 恢复满状态
	var player: Node2D = _get_local_player()
	if not player:
		_print("未找到本地玩家", Color(1.0, 0.5, 0.5))
		return
	player.health = player.max_health
	player.hunger = player.max_hunger
	player.thirst = player.max_thirst
	player.stamina = player.max_stamina
	player.sanity = 100.0
	player.is_down = false
	_print("玩家状态已完全恢复", Color(0.5, 1.0, 0.5))


func _cmd_give(args: Array) -> void:
	## 给予物品
	if args.size() < 1:
		_print("用法: give <物品ID> [数量]", Color(1.0, 0.5, 0.5))
		return
	var item_id: String = args[0]
	var count: int = 1
	if args.size() >= 2:
		count = int(args[1])
	var player: Node2D = _get_local_player()
	if not player or not player.inventory:
		_print("未找到玩家或背包", Color(1.0, 0.5, 0.5))
		return
	player.inventory.add_item(item_id, count)
	_print("已给予 %d 个 %s" % [count, item_id], Color(0.5, 1.0, 0.5))


func _cmd_tp(args: Array) -> void:
	## 传送
	if args.size() < 2:
		_print("用法: tp <x> <y>", Color(1.0, 0.5, 0.5))
		return
	var x: float = float(args[0])
	var y: float = float(args[1])
	var player: Node2D = _get_local_player()
	if not player:
		_print("未找到本地玩家", Color(1.0, 0.5, 0.5))
		return
	player.global_position = Vector2(x, y)
	_print("已传送到 (%.1f, %.1f)" % [x, y], Color(0.5, 1.0, 0.5))


func _cmd_whereami(args: Array) -> void:
	## 显示当前位置
	var player: Node2D = _get_local_player()
	if not player:
		_print("未找到本地玩家", Color(1.0, 0.5, 0.5))
		return
	var pos: Vector2 = player.global_position
	_print("当前位置: (%.1f, %.1f)" % [pos.x, pos.y], Color(0.7, 0.7, 1.0))


func _cmd_stats(args: Array) -> void:
	## 显示玩家属性
	var player: Node2D = _get_local_player()
	if not player:
		_print("未找到本地玩家", Color(1.0, 0.5, 0.5))
		return
	_print("=== 玩家属性 ===", Color(0.8, 0.8, 1.0))
	_print("生命: %.1f / %.1f" % [player.health, player.max_health])
	_print("饥饿: %.1f / %.1f" % [player.hunger, player.max_hunger])
	_print("口渴: %.1f / %.1f" % [player.thirst, player.max_thirst])
	_print("体力: %.1f / %.1f" % [player.stamina, player.max_stamina])
	_print("理智: %.1f / 100" % player.sanity)
	_print("等级: %d (经验: %.1f / %.1f)" % [player.level, player.experience, player.experience_to_next])
	_print("力量: %d  敏捷: %d  体质: %d  潜行: %d" % [player.strength, player.agility, player.vitality, player.stealth])
	_print("职业: " + player.player_class)
	_print("================", Color(0.8, 0.8, 1.0))


func _cmd_setstat(args: Array) -> void:
	## 设置属性
	if args.size() < 2:
		_print("用法: setstat <属性> <值>", Color(1.0, 0.5, 0.5))
		_print("可用属性: health, hunger, thirst, stamina, sanity, level, strength, agility, vitality, stealth", Color(0.7, 0.7, 0.7))
		return
	var stat: String = args[0].to_lower()
	var value: float = float(args[1])
	var player: Node2D = _get_local_player()
	if not player:
		_print("未找到本地玩家", Color(1.0, 0.5, 0.5))
		return
	match stat:
		"health":
			player.health = value
			player.max_health = max(player.max_health, value)
		"hunger":
			player.hunger = value
		"thirst":
			player.thirst = value
		"stamina":
			player.stamina = value
		"sanity":
			player.sanity = value
		"level":
			player.level = int(value)
		"strength":
			player.strength = int(value)
		"agility":
			player.agility = int(value)
		"vitality":
			player.vitality = int(value)
		"stealth":
			player.stealth = int(value)
		_:
			_print("未知属性: " + stat, Color(1.0, 0.5, 0.5))
			return
	_print("属性 %s 已设置为 %.1f" % [stat, value], Color(0.5, 1.0, 0.5))


func _cmd_time(args: Array) -> void:
	## 设置时间
	var world: Node2D = _get_game_world()
	if not world:
		_print("未找到游戏世界", Color(1.0, 0.5, 0.5))
		return
	if args.size() < 1:
		_print("当前时间: %.2f (0=黎明, 0.5=正午, 1=次日黎明)" % world.current_time, Color(0.7, 0.7, 1.0))
		_print("用法: time <0-1>", Color(0.7, 0.7, 0.7))
		return
	world.current_time = float(args[0])
	world.is_night = world.current_time > 0.7 or world.current_time < 0.2
	_print("时间已设置为 %.2f" % world.current_time, Color(0.5, 1.0, 0.5))


func _cmd_timespeed(args: Array) -> void:
	## 设置时间流速
	if args.size() < 1:
		_print("当前时间流速: %.1fx" % time_scale, Color(0.7, 0.7, 1.0))
		_print("用法: timespeed <倍率>", Color(0.7, 0.7, 0.7))
		return
	time_scale = float(args[0])
	Engine.time_scale = time_scale
	_print("时间流速已设置为 %.1fx" % time_scale, Color(0.5, 1.0, 0.5))


func _cmd_day(args: Array) -> void:
	## 跳到白天
	var world: Node2D = _get_game_world()
	if not world:
		_print("未找到游戏世界", Color(1.0, 0.5, 0.5))
		return
	world.current_time = 0.35
	world.is_night = false
	_print("已跳到白天", Color(0.5, 1.0, 0.5))


func _cmd_night(args: Array) -> void:
	## 跳到夜晚
	var world: Node2D = _get_game_world()
	if not world:
		_print("未找到游戏世界", Color(1.0, 0.5, 0.5))
		return
	world.current_time = 0.85
	world.is_night = true
	_print("已跳到夜晚", Color(0.5, 0.5, 1.0))


func _cmd_weather(args: Array) -> void:
	## 设置天气
	var world: Node2D = _get_game_world()
	if not world:
		_print("未找到游戏世界", Color(1.0, 0.5, 0.5))
		return
	if args.size() < 1:
		_print("当前天气: " + world.weather, Color(0.7, 0.7, 1.0))
		_print("可用天气: clear, cloudy, rain, storm, snow, fog", Color(0.7, 0.7, 0.7))
		return
	var w: String = args[0].to_lower()
	if world.WEATHER_TYPES.has(w):
		world.weather = w
		_print("天气已设置为: " + w, Color(0.5, 1.0, 0.5))
	else:
		_print("未知天气类型: " + w, Color(1.0, 0.5, 0.5))


func _cmd_season(args: Array) -> void:
	## 设置季节
	var world: Node2D = _get_game_world()
	if not world:
		_print("未找到游戏世界", Color(1.0, 0.5, 0.5))
		return
	if args.size() < 1:
		_print("当前季节: " + world.season, Color(0.7, 0.7, 1.0))
		_print("可用季节: spring, summer, autumn, winter", Color(0.7, 0.7, 0.7))
		return
	var s: String = args[0].to_lower()
	if world.SEASONS.has(s):
		world.season = s
		_print("季节已设置为: " + s, Color(0.5, 1.0, 0.5))
	else:
		_print("未知季节: " + s, Color(1.0, 0.5, 0.5))


func _cmd_month(args: Array) -> void:
	## 设置月份
	var world: Node2D = _get_game_world()
	if not world:
		_print("未找到游戏世界", Color(1.0, 0.5, 0.5))
		return
	if args.size() < 1:
		_print("当前月份: %d月" % (world.current_month + 1), Color(0.7, 0.7, 1.0))
		_print("用法: month <1-12>", Color(0.7, 0.7, 0.7))
		return
	var m: int = int(args[0]) - 1
	if m >= 0 and m < 12:
		world.current_month = m
		world.season = world.MONTH_SEASONS[m]
		_print("月份已设置为 %d月，季节: %s" % [m + 1, world.season], Color(0.5, 1.0, 0.5))
	else:
		_print("月份范围: 1-12", Color(1.0, 0.5, 0.5))


func _cmd_killall(args: Array) -> void:
	## 杀死所有丧尸
	var world: Node2D = _get_game_world()
	if not world:
		_print("未找到游戏世界", Color(1.0, 0.5, 0.5))
		return
	var zombies: Array = world.get_tree().get_nodes_in_group("zombie")
	var count: int = zombies.size()
	for z in zombies:
		if z and is_instance_valid(z):
			if z.has_method("take_damage"):
				z.take_damage(99999.0)
			else:
				z.queue_free()
	_print("已杀死 %d 个丧尸" % count, Color(1.0, 0.5, 0.5))


func _cmd_spawn(args: Array) -> void:
	## 生成实体
	if args.size() < 1:
		_print("用法: spawn <类型> [数量]", Color(1.0, 0.5, 0.5))
		_print("可用类型: zombie, tree, rock, npc, berry", Color(0.7, 0.7, 0.7))
		return
	var entity_type: String = args[0].to_lower()
	var count: int = 1
	if args.size() >= 2:
		count = int(args[1])
	var world: Node2D = _get_game_world()
	var player: Node2D = _get_local_player()
	if not world or not player:
		_print("未找到游戏世界或玩家", Color(1.0, 0.5, 0.5))
		return
	var spawn_pos: Vector2 = player.global_position + Vector2(randf_range(-100, 100), randf_range(-100, 100))
	var scene_path: String = ""
	match entity_type:
		"zombie":
			scene_path = "res://scenes/entities/zombie.tscn"
		"tree":
			scene_path = "res://scenes/entities/tree.tscn"
		"rock":
			scene_path = "res://scenes/entities/rock.tscn"
		"berry":
			scene_path = "res://scenes/entities/berry.tscn"
		"npc":
			scene_path = "res://scenes/entities/npc.tscn"
		_:
			_print("未知实体类型: " + entity_type, Color(1.0, 0.5, 0.5))
			return
	var scene: PackedScene = load(scene_path)
	if not scene:
		_print("无法加载场景: " + scene_path, Color(1.0, 0.5, 0.5))
		return
	for i in range(count):
		var entity: Node2D = scene.instantiate()
		entity.global_position = spawn_pos + Vector2(randf_range(-50, 50), randf_range(-50, 50))
		world.world_layer.add_child(entity)
	_print("已生成 %d 个 %s" % [count, entity_type], Color(0.5, 1.0, 0.5))


func _cmd_count(args: Array) -> void:
	## 统计实体数量
	var world: Node2D = _get_game_world()
	if not world:
		_print("未找到游戏世界", Color(1.0, 0.5, 0.5))
		return
	var tree = world.get_tree()
	_print("=== 实体统计 ===", Color(0.8, 0.8, 1.0))
	_print("玩家: %d" % tree.get_nodes_in_group("player").size())
	_print("丧尸: %d" % tree.get_nodes_in_group("zombie").size())
	_print("NPC: %d" % tree.get_nodes_in_group("npc").size())
	_print("树木: %d" % tree.get_nodes_in_group("tree").size())
	_print("石头: %d" % tree.get_nodes_in_group("rock").size())
	_print("建筑: %d" % tree.get_nodes_in_group("building").size())
	_print("载具: %d" % tree.get_nodes_in_group("vehicle").size())
	_print("================", Color(0.8, 0.8, 1.0))


func _cmd_save(args: Array) -> void:
	## 保存游戏
	var slot: int = 0
	if args.size() >= 1:
		slot = int(args[0])
	if slot < 0 or slot > 2:
		_print("存档位范围: 0-2", Color(1.0, 0.5, 0.5))
		return
	var world: Node2D = _get_game_world()
	if not world:
		_print("未找到游戏世界", Color(1.0, 0.5, 0.5))
		return
	if SaveManager and SaveManager.has_method("save_game"):
		var result: bool = SaveManager.save_game(slot, world)
		if result:
			_print("游戏已保存到存档位 %d" % slot, Color(0.5, 1.0, 0.5))
		else:
			_print("保存失败", Color(1.0, 0.5, 0.5))
	else:
		_print("SaveManager 不可用", Color(1.0, 0.5, 0.5))


func _cmd_load(args: Array) -> void:
	## 加载游戏
	var slot: int = 0
	if args.size() >= 1:
		slot = int(args[0])
	if slot < 0 or slot > 2:
		_print("存档位范围: 0-2", Color(1.0, 0.5, 0.5))
		return
	if SaveManager and SaveManager.has_method("load_game"):
		var data: Dictionary = SaveManager.load_game(slot)
		if data.is_empty():
			_print("存档位 %d 为空或加载失败" % slot, Color(1.0, 0.5, 0.5))
		else:
			_print("已从存档位 %d 读取游戏数据（需重新进入游戏应用）" % slot, Color(0.5, 1.0, 0.5))
	else:
		_print("SaveManager 不可用", Color(1.0, 0.5, 0.5))


func _cmd_log(args: Array) -> void:
	## 设置日志级别
	if args.size() < 1:
		_print("用法: log <级别>", Color(1.0, 0.5, 0.5))
		_print("可用级别: debug, info, warning, error", Color(0.7, 0.7, 0.7))
		return
	var level: String = args[0].to_lower()
	if GameLogger and GameLogger.has_method("set_level"):
		match level:
			"debug":
				GameLogger.set_level(GameLogger.Level.DEBUG)
			"info":
				GameLogger.set_level(GameLogger.Level.INFO)
			"warning":
				GameLogger.set_level(GameLogger.Level.WARNING)
			"error":
				GameLogger.set_level(GameLogger.Level.ERROR)
			_:
				_print("未知日志级别: " + level, Color(1.0, 0.5, 0.5))
				return
		_print("日志级别已设置为: " + level, Color(0.5, 1.0, 0.5))
	else:
		_print("GameLogger 不可用", Color(1.0, 0.5, 0.5))


# ==================== 性能监控命令 ====================

func _cmd_perf(args: Array) -> void:
	## 切换性能监控显示
	if PerformanceMonitor and PerformanceMonitor.has_method("toggle"):
		PerformanceMonitor.toggle()
		_print("性能监控已%s" % ["隐藏", "显示"][int(PerformanceMonitor.is_visible)], Color(0.5, 1.0, 0.5))
	else:
		_print("PerformanceMonitor 不可用", Color(1.0, 0.5, 0.5))


func _cmd_perf_show(args: Array) -> void:
	## 显示性能监控
	if PerformanceMonitor and PerformanceMonitor.has_method("show"):
		PerformanceMonitor.show()
		_print("性能监控已显示", Color(0.5, 1.0, 0.5))
	else:
		_print("PerformanceMonitor 不可用", Color(1.0, 0.5, 0.5))


func _cmd_perf_hide(args: Array) -> void:
	## 隐藏性能监控
	if PerformanceMonitor and PerformanceMonitor.has_method("hide"):
		PerformanceMonitor.hide()
		_print("性能监控已隐藏", Color(0.5, 1.0, 0.5))
	else:
		_print("PerformanceMonitor 不可用", Color(1.0, 0.5, 0.5))


func _cmd_perf_stats(args: Array) -> void:
	## 显示性能统计
	if PerformanceMonitor and PerformanceMonitor.has_method("get_stats"):
		var stats: Dictionary = PerformanceMonitor.get_stats()
		_print("=== 性能统计 ===", Color(0.8, 0.8, 1.0))
		_print("当前FPS: %d" % stats.fps)
		_print("帧时间: %.1fms" % stats.frame_time)
		_print("内存: %.1fMB" % stats.memory_mb)
		_print("Draw Calls: %d" % stats.draw_calls)
		_print("对象数: %d" % stats.object_count)
		_print("节点数: %d" % stats.node_count)
		_print("平均FPS: %.1f" % stats.avg_fps)
		_print("最低FPS: %d" % stats.min_fps)
		_print("最高FPS: %d" % stats.max_fps)
		_print("警告次数: %d" % stats.warning_count)
		_print("================", Color(0.8, 0.8, 1.0))
	else:
		_print("PerformanceMonitor 不可用", Color(1.0, 0.5, 0.5))


func _cmd_perf_reset(args: Array) -> void:
	## 重置性能统计
	if PerformanceMonitor and PerformanceMonitor.has_method("reset_stats"):
		PerformanceMonitor.reset_stats()
		_print("性能统计已重置", Color(0.5, 1.0, 0.5))
	else:
		_print("PerformanceMonitor 不可用", Color(1.0, 0.5, 0.5))


func _cmd_perf_log(args: Array) -> void:
	## 记录性能到日志
	if PerformanceMonitor and PerformanceMonitor.has_method("log_performance"):
		PerformanceMonitor.log_performance()
		_print("性能数据已记录到日志", Color(0.5, 1.0, 0.5))
	else:
		_print("PerformanceMonitor 不可用", Color(1.0, 0.5, 0.5))


# ==================== 错误捕获与崩溃报告命令 ====================

func _cmd_errors(args: Array) -> void:
	## 查看错误统计
	if CrashReporter and CrashReporter.has_method("get_error_stats"):
		var stats: Dictionary = CrashReporter.get_error_stats()
		_print("=== 错误统计 ===", Color(0.8, 0.8, 1.0))
		_print("总错误数: %d" % stats.total_errors)
		_print("总警告数: %d" % stats.total_warnings)
		_print("致命错误数: %d" % stats.fatal_errors)
		_print("按类型统计:", Color(0.7, 0.7, 0.7))
		for error_type in stats.by_type.keys():
			_print("  %s: %d" % [error_type, stats.by_type[error_type]])
		if not stats.last_error.is_empty():
			_print("最近错误: %s" % stats.last_error.get("message", ""), Color(1, 0.5, 0.5))
		_print("================", Color(0.8, 0.8, 1.0))
	else:
		_print("CrashReporter 不可用", Color(1.0, 0.5, 0.5))


func _cmd_crash_reports(args: Array) -> void:
	## 查看崩溃报告列表
	if CrashReporter and CrashReporter.has_method("get_crash_reports"):
		var reports: Array = CrashReporter.get_crash_reports()
		if reports.is_empty():
			_print("暂无崩溃报告", Color(0.7, 0.7, 0.7))
		else:
			_print("=== 崩溃报告列表 (%d个) ===" % reports.size(), Color(0.8, 0.8, 1.0))
			for i in range(reports.size()):
				_print("%d. %s" % [i + 1, reports[i]])
			_print("============================", Color(0.8, 0.8, 1.0))
	else:
		_print("CrashReporter 不可用", Color(1.0, 0.5, 0.5))


func _cmd_export_crash(args: Array) -> void:
	## 导出最近一次崩溃报告
	if CrashReporter and CrashReporter.has_method("export_latest_report"):
		var report: String = CrashReporter.export_latest_report()
		_print("=== 最近崩溃报告 ===", Color(0.8, 0.8, 1.0))
		_print(report)
		_print("====================", Color(0.8, 0.8, 1.0))
	else:
		_print("CrashReporter 不可用", Color(1.0, 0.5, 0.5))


func _cmd_clear_errors(args: Array) -> void:
	## 清除错误统计
	if CrashReporter:
		CrashReporter.error_count = 0
		CrashReporter.warning_count = 0
		CrashReporter.fatal_error_count = 0
		CrashReporter.error_stats.clear()
		CrashReporter.last_error = {}
		_print("错误统计已清除", Color(0.5, 1.0, 0.5))
	else:
		_print("CrashReporter 不可用", Color(1.0, 0.5, 0.5))


# ==================== 输入管理命令 ====================

func _cmd_input(args: Array) -> void:
	## 查看输入管理状态
	if InputManager:
		_print("=== 输入管理状态 ===", Color(0.8, 0.8, 1.0))
		_print("UI焦点: %s" % ("是" if InputManager.is_ui_focused() else "否"))
		_print("鼠标位置: %s" % str(InputManager.get_mouse_position()))
		_print("当前按下的动作:", Color(0.7, 0.7, 0.7))
		var pressed: Dictionary = InputManager._pressed_actions
		if pressed.is_empty():
			_print("  (无)")
		else:
			for action in pressed.keys():
				_print("  - %s" % action)
		_print("====================", Color(0.8, 0.8, 1.0))
	else:
		_print("InputManager 不可用", Color(1.0, 0.5, 0.5))


func _cmd_input_reset(args: Array) -> void:
	## 重置输入配置为默认
	if InputManager and InputManager.has_method("reset_to_default"):
		InputManager.reset_to_default()
		_print("输入配置已重置为默认", Color(0.5, 1.0, 0.5))
	else:
		_print("InputManager 不可用", Color(1.0, 0.5, 0.5))


func _cmd_input_list(args: Array) -> void:
	## 列出所有动作绑定
	if InputManager and InputManager.has_method("get_action_bindings"):
		var bindings: Dictionary = InputManager.get_action_bindings()
		_print("=== 动作绑定列表 ===", Color(0.8, 0.8, 1.0))
		for action in bindings.keys():
			var keys: Array = bindings[action]
			var key_names: String = ""
			for i in range(keys.size()):
				if i > 0:
					key_names += ", "
				key_names += InputManager.get_key_name(keys[i])
			_print("  %s: %s" % [action, key_names])
		_print("====================", Color(0.8, 0.8, 1.0))
	else:
		_print("InputManager 不可用", Color(1.0, 0.5, 0.5))


# ==================== 辅助函数 ====================

func _get_local_player() -> Node2D:
	## 获取本地玩家
	if local_player and is_instance_valid(local_player):
		return local_player
	if GameManager and GameManager.has_method("get_local_player"):
		local_player = GameManager.get_local_player()
	return local_player


func _get_game_world() -> Node2D:
	## 获取游戏世界
	if game_world and is_instance_valid(game_world):
		return game_world
	if GameManager and GameManager.has_method("get_game_world"):
		game_world = GameManager.get_game_world()
	return game_world
