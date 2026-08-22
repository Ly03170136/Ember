extends Node
## 性能监控系统（Performance Monitor）- 《余烬 EMBER》
## 功能：
## 1. 实时监控FPS、帧时间、内存、draw call、对象数量
## 2. 性能图表（实时曲线）
## 3. 性能警告（FPS过低时提示）
## 4. UI显示（可切换显示/隐藏）
## 5. 性能日志记录
## 6. 控制台命令集成

# ==================== 信号 ====================
signal fps_changed(fps: int)
signal performance_warning(message: String)
signal monitor_toggled(visible: bool)

# ==================== 配置 ====================
const HISTORY_LENGTH: int = 120          # 历史数据长度（秒）
const WARNING_FPS_THRESHOLD: int = 30    # FPS警告阈值
const WARNING_FRAME_TIME: float = 50.0    # 帧时间警告阈值（毫秒）
const UPDATE_INTERVAL: float = 0.5         # 更新间隔（秒）

# ==================== 状态变量 ====================
var is_visible: bool = false
var _update_timer: float = 0.0

# 实时数据
var current_fps: int = 0
var current_frame_time: float = 0.0
var current_memory: int = 0                 # 内存使用（KB）
var current_draw_calls: int = 0
var current_object_count: int = 0
var current_node_count: int = 0

# 调试信息（扩展）
var player_position: Vector2 = Vector2.ZERO
var player_chunk: Vector2 = Vector2.ZERO
var entity_counts: Dictionary = {}  # 玩家、NPC、丧尸、物品、建筑等分类计数
var game_day: int = 1
var game_time: String = "00:00"
var game_weather: String = "晴朗"
var game_season: String = "春季"
var virus_progress: float = 0.0
var active_entities: int = 0
var frozen_entities: int = 0
var network_ping: int = 0
var network_players: int = 1

# 历史数据（用于图表）
var fps_history: Array = []
var frame_time_history: Array = []
var memory_history: Array = []

# 统计数据
var avg_fps: float = 0.0
var min_fps: int = 999
var max_fps: int = 0
var total_frames: int = 0
var warning_count: int = 0

# UI节点
var _canvas_layer: CanvasLayer = null
var _monitor_panel: Control = null
var _fps_label: Label = null
var _frame_time_label: Label = null
var _memory_label: Label = null
var _draw_calls_label: Label = null
var _objects_label: Label = null
var _fps_chart: Control = null
var _frame_time_chart: Control = null
var _memory_chart: Control = null
var _warning_label: Label = null

# 扩展调试UI标签
var _player_pos_label: Label = null
var _player_chunk_label: Label = null
var _entity_counts_label: Label = null
var _game_state_label: Label = null
var _chunk_info_label: Label = null
var _network_info_label: Label = null

# ==================== 生命周期 ====================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[PerformanceMonitor] 性能监控系统已启动")
	GameLogger.info("性能监控系统已启动", "Performance")
	# 延迟创建UI，确保场景已加载
	call_deferred("_create_ui")


func _process(delta: float) -> void:
	_update_timer += delta
	if _update_timer >= UPDATE_INTERVAL:
		_update_timer = 0.0
		_update_stats()
		_update_ui()
		_check_warnings()


func _input(event: InputEvent) -> void:
	## 处理快捷键（F12切换性能监控显示）
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F12:
			toggle()
			get_viewport().set_input_as_handled()


# ==================== 公共API ====================

func toggle() -> void:
	## 切换显示/隐藏
	is_visible = not is_visible
	if _monitor_panel:
		_monitor_panel.visible = is_visible
	monitor_toggled.emit(is_visible)
	print("[PerformanceMonitor] 性能监控: %s" % ["隐藏", "显示"][int(is_visible)])


func show() -> void:
	## 显示监控面板
	is_visible = true
	if _monitor_panel:
		_monitor_panel.visible = true
	monitor_toggled.emit(true)


func hide() -> void:
	## 隐藏监控面板
	is_visible = false
	if _monitor_panel:
		_monitor_panel.visible = false
	monitor_toggled.emit(false)


func get_stats() -> Dictionary:
	## 获取当前性能统计
	return {
		"fps": current_fps,
		"frame_time": current_frame_time,
		"memory_kb": current_memory,
		"memory_mb": float(current_memory) / 1024.0,
		"draw_calls": current_draw_calls,
		"object_count": current_object_count,
		"node_count": current_node_count,
		"avg_fps": avg_fps,
		"min_fps": min_fps,
		"max_fps": max_fps,
		"warning_count": warning_count
	}


func reset_stats() -> void:
	## 重置统计数据
	avg_fps = 0.0
	min_fps = 999
	max_fps = 0
	total_frames = 0
	warning_count = 0
	fps_history.clear()
	frame_time_history.clear()
	memory_history.clear()
	print("[PerformanceMonitor] 统计数据已重置")


func log_performance() -> void:
	## 记录当前性能到日志
	var stats: Dictionary = get_stats()
	GameLogger.info(
		"性能: FPS=%d, 帧时间=%.1fms, 内存=%.1fMB, draw calls=%d, 对象=%d, 节点=%d" % [
			stats.fps, stats.frame_time, stats.memory_mb,
			stats.draw_calls, stats.object_count, stats.node_count
		],
		"Performance"
	)


# ==================== 内部方法 ====================

func _update_stats() -> void:
	## 更新性能统计
	# FPS
	current_fps = Engine.get_frames_per_second()
	current_frame_time = 1000.0 / float(max(current_fps, 1))

	# 内存
	current_memory = int(OS.get_static_memory_usage() / 1024)

	# draw calls（Godot 4.7中Performance无直接监控常量，暂设为0）
	current_draw_calls = 0

	# 对象和节点数量
	current_object_count = Performance.get_monitor(Performance.OBJECT_COUNT)
	current_node_count = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)

	# 收集扩展调试信息
	_collect_debug_info()

	# 更新历史数据
	fps_history.append(current_fps)
	if fps_history.size() > HISTORY_LENGTH:
		fps_history.pop_front()

	frame_time_history.append(current_frame_time)
	if frame_time_history.size() > HISTORY_LENGTH:
		frame_time_history.pop_front()

	memory_history.append(current_memory)
	if memory_history.size() > HISTORY_LENGTH:
		memory_history.pop_front()

	# 更新统计
	total_frames += 1
	avg_fps = (avg_fps * (total_frames - 1) + current_fps) / total_frames
	min_fps = min(min_fps, current_fps)
	max_fps = max(max_fps, current_fps)

	fps_changed.emit(current_fps)


func _collect_debug_info() -> void:
	## 收集扩展调试信息
	# 重置实体计数
	entity_counts = {
		"players": 0,
		"npcs": 0,
		"zombies": 0,
		"items": 0,
		"buildings": 0,
		"vehicles": 0,
		"resources": 0
	}
	active_entities = 0
	frozen_entities = 0

	# 遍历场景树，统计实体
	var main_scene = get_tree().current_scene
	if main_scene:
		# 查找玩家
		var players = main_scene.find_children("*", "CharacterBody2D", true, false)
		for p in players:
			if p.name.begins_with("Player_"):
				entity_counts["players"] += 1
				if entity_counts["players"] == 1:
					player_position = p.position

		# 查找NPC（通过组或名称）
		var npcs = main_scene.find_children("*", "", true, false)
		for n in npcs:
			var name_str = str(n.name)
			if name_str.begins_with("NPC_") or name_str.begins_with("Citizen_") or name_str.begins_with("Police_"):
				entity_counts["npcs"] += 1
			elif name_str.begins_with("Zombie_") or name_str.begins_with("zombie_"):
				entity_counts["zombies"] += 1
			elif name_str.begins_with("Item_") or name_str.begins_with("Pickup_"):
				entity_counts["items"] += 1
			elif name_str.begins_with("Building_") or name_str.begins_with("building_"):
				entity_counts["buildings"] += 1
			elif name_str.begins_with("Vehicle_") or name_str.begins_with("vehicle_"):
				entity_counts["vehicles"] += 1
			elif name_str.begins_with("Tree_") or name_str.begins_with("Rock_") or name_str.begins_with("Berry_") or name_str.begins_with("Resource_"):
				entity_counts["resources"] += 1

	# 从GameManager获取游戏状态
	if GameManager:
		game_day = GameManager.get("game_day") if "game_day" in GameManager else 1
		network_players = GameManager.player_names.size() if "player_names" in GameManager else 1

	# 网络信息
	if multiplayer and multiplayer.multiplayer_peer:
		network_ping = 0  # Godot ENet没有直接的ping API，暂设为0
		network_players = multiplayer.get_peers().size() + 1

	# 区块信息（直接从main节点获取Chunk统计）
	if main_scene and "total_active_entities" in main_scene:
		active_entities = main_scene.total_active_entities
	if main_scene and "total_frozen_entities" in main_scene:
		frozen_entities = main_scene.total_frozen_entities


func _check_warnings() -> void:
	## 检查性能警告
	var warning_msg: String = ""
	if current_fps < WARNING_FPS_THRESHOLD:
		warning_msg = "FPS过低: %d (阈值: %d)" % [current_fps, WARNING_FPS_THRESHOLD]
	elif current_frame_time > WARNING_FRAME_TIME:
		warning_msg = "帧时间过高: %.1fms (阈值: %.1fms)" % [current_frame_time, WARNING_FRAME_TIME]

	if warning_msg != "":
		warning_count += 1
		performance_warning.emit(warning_msg)
		if _warning_label:
			_warning_label.text = "⚠ " + warning_msg
			_warning_label.visible = true
			# 3秒后自动隐藏
			_warning_label.modulate = Color(1, 0.3, 0.3)
			get_tree().create_timer(3.0).timeout.connect(func(): _warning_label.visible = false)
		GameLogger.warning(warning_msg, "Performance")


func _update_ui() -> void:
	## 更新UI显示
	if not _monitor_panel or not is_visible:
		return

	_fps_label.text = "FPS: %d" % current_fps
	_fps_label.add_theme_color_override("font_color", Color(1, 1, 1))  # 白色字体

	_frame_time_label.text = "帧时间: %.1fms" % current_frame_time
	_memory_label.text = "内存: %.1fMB" % (float(current_memory) / 1024.0)
	_objects_label.text = "对象: %d | 节点: %d" % [current_object_count, current_node_count]

	# 玩家信息
	_player_pos_label.text = "坐标: (%.0f, %.0f)" % [player_position.x, player_position.y]
	_player_chunk_label.text = "区块: (%d, %d)" % [int(player_position.x / 1024), int(player_position.y / 1024)]

	# 实体计数
	_entity_counts_label.text = "玩家:%d NPC:%d 丧尸:%d" % [
		entity_counts.get("players", 0),
		entity_counts.get("npcs", 0),
		entity_counts.get("zombies", 0)
	]
	_chunk_info_label.text = "物品:%d 建筑:%d 资源:%d 载具:%d" % [
		entity_counts.get("items", 0),
		entity_counts.get("buildings", 0),
		entity_counts.get("resources", 0),
		entity_counts.get("vehicles", 0)
	]

	# 激活/冻结实体
	var active_label = _monitor_panel.find_child("ActiveEntitiesLabel", true, false)
	if active_label:
		active_label.text = "激活:%d 冻结:%d" % [active_entities, frozen_entities]

	# 游戏状态
	_game_state_label.text = "第%d天 %s %s %s" % [game_day, game_time, game_season, game_weather]

	# 病毒扩散进度
	var virus_label = _monitor_panel.find_child("VirusProgressLabel", true, false)
	if virus_label:
		virus_label.text = "病毒扩散: %.1f%%" % virus_progress

	# 网络信息
	_network_info_label.text = "玩家:%d 延迟:%dms" % [network_players, network_ping]

	# 重绘图表
	if _fps_chart:
		_fps_chart.queue_redraw()
	if _frame_time_chart:
		_frame_time_chart.queue_redraw()
	if _memory_chart:
		_memory_chart.queue_redraw()


func _get_fps_color(fps: int) -> Color:
	## 根据FPS获取颜色
	if fps >= 60:
		return Color(0.3, 1, 0.3)  # 绿色
	elif fps >= 30:
		return Color(1, 0.9, 0.3)  # 黄色
	else:
		return Color(1, 0.3, 0.3)  # 红色


# ==================== UI创建 ====================

func _create_ui() -> void:
	## 创建性能监控UI（直接在PerformanceMonitor节点下创建，不依赖主场景）
	# 如果已经创建过，先销毁
	if _canvas_layer and is_instance_valid(_canvas_layer):
		_canvas_layer.queue_free()
		_canvas_layer = null

	# 创建自己的CanvasLayer（直接作为PerformanceMonitor的子节点）
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 1000  # 确保在最上层
	add_child(_canvas_layer)

	# 创建监控面板（用Control代替Panel，无默认背景）
	_monitor_panel = Control.new()
	_monitor_panel.name = "PerformanceMonitorPanel"
	_monitor_panel.visible = is_visible
	_monitor_panel.custom_minimum_size = Vector2(320, 420)
	_monitor_panel.position = Vector2(10, 10)
	_canvas_layer.add_child(_monitor_panel)

	# 创建布局
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	vbox.position = Vector2(8, 8)
	vbox.custom_minimum_size = Vector2(304, 404)
	_monitor_panel.add_child(vbox)

	# 标题（白色）
	var title_label: Label = Label.new()
	title_label.text = "=== 调试面板 (F12) ==="
	title_label.add_theme_color_override("font_color", Color(1, 1, 1))
	title_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(title_label)

	# 性能信息分隔线
	var perf_sep: Label = Label.new()
	perf_sep.text = "--- 性能 ---"
	perf_sep.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	perf_sep.add_theme_font_size_override("font_size", 10)
	vbox.add_child(perf_sep)

	# FPS（白色）
	_fps_label = Label.new()
	_fps_label.text = "FPS: 0"
	_fps_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_fps_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_fps_label)

	# 帧时间（白色）
	_frame_time_label = Label.new()
	_frame_time_label.text = "帧时间: 0.0ms"
	_frame_time_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_frame_time_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_frame_time_label)

	# 内存（白色）
	_memory_label = Label.new()
	_memory_label.text = "内存: 0.0MB"
	_memory_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_memory_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_memory_label)

	# 对象数量（白色）
	_objects_label = Label.new()
	_objects_label.text = "对象: 0 | 节点: 0"
	_objects_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_objects_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_objects_label)

	# 玩家信息分隔线
	var player_sep: Label = Label.new()
	player_sep.text = "--- 玩家 ---"
	player_sep.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	player_sep.add_theme_font_size_override("font_size", 10)
	vbox.add_child(player_sep)

	# 玩家坐标
	_player_pos_label = Label.new()
	_player_pos_label.text = "坐标: (0, 0)"
	_player_pos_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_player_pos_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_player_pos_label)

	# 玩家区块
	_player_chunk_label = Label.new()
	_player_chunk_label.text = "区块: (0, 0)"
	_player_chunk_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_player_chunk_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_player_chunk_label)

	# 实体计数分隔线
	var entity_sep: Label = Label.new()
	entity_sep.text = "--- 实体计数 ---"
	entity_sep.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	entity_sep.add_theme_font_size_override("font_size", 10)
	vbox.add_child(entity_sep)

	# 实体计数
	_entity_counts_label = Label.new()
	_entity_counts_label.text = "玩家:0 NPC:0 丧尸:0"
	_entity_counts_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_entity_counts_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_entity_counts_label)

	# 资源/物品/建筑计数
	_chunk_info_label = Label.new()
	_chunk_info_label.text = "物品:0 建筑:0 资源:0"
	_chunk_info_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_chunk_info_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_chunk_info_label)

	# 激活/冻结实体
	var active_label: Label = Label.new()
	active_label.name = "ActiveEntitiesLabel"
	active_label.text = "激活:0 冻结:0"
	active_label.add_theme_color_override("font_color", Color(1, 1, 1))
	active_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(active_label)

	# 游戏状态分隔线
	var game_sep: Label = Label.new()
	game_sep.text = "--- 游戏状态 ---"
	game_sep.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	game_sep.add_theme_font_size_override("font_size", 10)
	vbox.add_child(game_sep)

	# 游戏状态
	_game_state_label = Label.new()
	_game_state_label.text = "第1天 00:00 春季 晴朗"
	_game_state_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_game_state_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_game_state_label)

	# 病毒扩散进度
	var virus_label: Label = Label.new()
	virus_label.name = "VirusProgressLabel"
	virus_label.text = "病毒扩散: 0%"
	virus_label.add_theme_color_override("font_color", Color(1, 1, 1))
	virus_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(virus_label)

	# 网络信息分隔线
	var net_sep: Label = Label.new()
	net_sep.text = "--- 网络 ---"
	net_sep.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	net_sep.add_theme_font_size_override("font_size", 10)
	vbox.add_child(net_sep)

	# 网络信息
	_network_info_label = Label.new()
	_network_info_label.text = "玩家:1 延迟:0ms"
	_network_info_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_network_info_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_network_info_label)

	# 图表区域
	var chart_hbox: HBoxContainer = HBoxContainer.new()
	chart_hbox.add_theme_constant_override("separation", 4)
	chart_hbox.custom_minimum_size = Vector2(304, 40)
	vbox.add_child(chart_hbox)

	# FPS图表
	_fps_chart = Control.new()
	_fps_chart.custom_minimum_size = Vector2(96, 40)
	_fps_chart.draw.connect(_draw_fps_chart)
	chart_hbox.add_child(_fps_chart)

	# 帧时间图表
	_frame_time_chart = Control.new()
	_frame_time_chart.custom_minimum_size = Vector2(96, 40)
	_frame_time_chart.draw.connect(_draw_frame_time_chart)
	chart_hbox.add_child(_frame_time_chart)

	# 内存图表
	_memory_chart = Control.new()
	_memory_chart.custom_minimum_size = Vector2(96, 40)
	_memory_chart.draw.connect(_draw_memory_chart)
	chart_hbox.add_child(_memory_chart)

	# 警告标签
	_warning_label = Label.new()
	_warning_label.text = ""
	_warning_label.visible = false
	_warning_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	_warning_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(_warning_label)

	print("[PerformanceMonitor] UI创建完成（扩展调试面板，F12切换，透明背景，白色字体）")


func _on_scene_changed() -> void:
	## 场景变化时不需要重新创建UI（因为UI直接挂载在PerformanceMonitor节点下）
	pass


# ==================== 图表绘制 ====================

func _draw_fps_chart() -> void:
	## 绘制FPS图表
	if not _fps_chart or fps_history.is_empty():
		return
	var size: Vector2 = _fps_chart.size
	var max_fps_val: float = 120.0
	var bar_width: float = size.x / float(HISTORY_LENGTH)

	# 无背景（透明）

	# 绘制历史曲线
	for i in range(fps_history.size()):
		var fps_val: float = float(fps_history[i])
		var bar_height: float = (fps_val / max_fps_val) * size.y
		var x: float = i * bar_width
		var color: Color = _get_fps_color(int(fps_val))
		_fps_chart.draw_rect(Rect2(x, size.y - bar_height, max(bar_width - 1, 1), bar_height), color)

	# 标签
	_fps_chart.draw_string(
		ThemeDB.fallback_font,
		Vector2(2, 12),
		"FPS",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		9,
		Color(0.8, 0.8, 0.8)
	)


func _draw_frame_time_chart() -> void:
	## 绘制帧时间图表
	if not _frame_time_chart or frame_time_history.is_empty():
		return
	var size: Vector2 = _frame_time_chart.size
	var max_frame_time: float = 100.0
	var bar_width: float = size.x / float(HISTORY_LENGTH)

	# 无背景（透明）

	# 绘制历史曲线
	for i in range(frame_time_history.size()):
		var ft: float = float(frame_time_history[i])
		var bar_height: float = (min(ft, max_frame_time) / max_frame_time) * size.y
		var x: float = i * bar_width
		var color: Color = Color(0.3, 0.8, 1) if ft < 33 else Color(1, 0.6, 0.3)
		_frame_time_chart.draw_rect(Rect2(x, size.y - bar_height, max(bar_width - 1, 1), bar_height), color)

	# 标签
	_frame_time_chart.draw_string(
		ThemeDB.fallback_font,
		Vector2(2, 12),
		"帧时",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		9,
		Color(0.8, 0.8, 0.8)
	)


func _draw_memory_chart() -> void:
	## 绘制内存图表
	if not _memory_chart or memory_history.is_empty():
		return
	var size: Vector2 = _memory_chart.size
	var max_memory: float = 2048.0  # 2GB
	var bar_width: float = size.x / float(HISTORY_LENGTH)

	# 无背景（透明）

	# 绘制历史曲线
	for i in range(memory_history.size()):
		var mem: float = float(memory_history[i]) / 1024.0  # 转换为MB
		var bar_height: float = (min(mem, max_memory) / max_memory) * size.y
		var x: float = i * bar_width
		var color: Color = Color(0.6, 0.4, 1)
		_memory_chart.draw_rect(Rect2(x, size.y - bar_height, max(bar_width - 1, 1), bar_height), color)

	# 标签
	_memory_chart.draw_string(
		ThemeDB.fallback_font,
		Vector2(2, 12),
		"内存",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		9,
		Color(0.8, 0.8, 0.8)
	)
