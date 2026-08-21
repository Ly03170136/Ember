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
var _monitor_panel: Panel = null
var _fps_label: Label = null
var _frame_time_label: Label = null
var _memory_label: Label = null
var _draw_calls_label: Label = null
var _objects_label: Label = null
var _fps_chart: Control = null
var _frame_time_chart: Control = null
var _memory_chart: Control = null
var _warning_label: Label = null

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
	## 处理快捷键（F3切换性能监控显示）
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3:
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
	_fps_label.add_theme_color_override("font_color", _get_fps_color(current_fps))

	_frame_time_label.text = "帧时间: %.1fms" % current_frame_time
	_memory_label.text = "内存: %.1fMB" % (float(current_memory) / 1024.0)
	_draw_calls_label.text = "Draw Calls: %d" % current_draw_calls
	_objects_label.text = "对象: %d | 节点: %d" % [current_object_count, current_node_count]

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
	## 创建性能监控UI
	if not get_tree() or not get_tree().current_scene:
		# 延迟到场景加载后再创建
		get_tree().scene_changed.connect(_on_scene_changed)
		return

	# 查找HUD的CanvasLayer
	var canvas_layer: CanvasLayer = null
	var main_scene: Node = get_tree().current_scene
	if main_scene and main_scene.has_node("HUD"):
		var hud: Node = main_scene.get_node("HUD")
		if hud and hud.has_node("CanvasLayer"):
			canvas_layer = hud.get_node("CanvasLayer") as CanvasLayer

	if canvas_layer == null:
		# 创建自己的CanvasLayer
		canvas_layer = CanvasLayer.new()
		canvas_layer.layer = 100
		main_scene.add_child(canvas_layer)

	# 创建监控面板
	_monitor_panel = Panel.new()
	_monitor_panel.name = "PerformanceMonitor"
	_monitor_panel.visible = is_visible
	_monitor_panel.custom_minimum_size = Vector2(280, 200)
	_monitor_panel.position = Vector2(10, 10)
	_monitor_panel.modulate = Color(0.1, 0.1, 0.1, 0.85)
	canvas_layer.add_child(_monitor_panel)

	# 创建布局
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.position = Vector2(8, 8)
	vbox.custom_minimum_size = Vector2(264, 184)
	_monitor_panel.add_child(vbox)

	# 标题
	var title_label: Label = Label.new()
	title_label.text = "=== 性能监控 ==="
	title_label.add_theme_color_override("font_color", Color(0.8, 0.8, 1))
	title_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(title_label)

	# FPS
	_fps_label = Label.new()
	_fps_label.text = "FPS: 0"
	_fps_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_fps_label)

	# 帧时间
	_frame_time_label = Label.new()
	_frame_time_label.text = "帧时间: 0.0ms"
	_frame_time_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_frame_time_label)

	# 内存
	_memory_label = Label.new()
	_memory_label.text = "内存: 0.0MB"
	_memory_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_memory_label)

	# Draw Calls
	_draw_calls_label = Label.new()
	_draw_calls_label.text = "Draw Calls: 0"
	_draw_calls_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_draw_calls_label)

	# 对象数量
	_objects_label = Label.new()
	_objects_label.text = "对象: 0 | 节点: 0"
	_objects_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_objects_label)

	# 图表区域
	var chart_hbox: HBoxContainer = HBoxContainer.new()
	chart_hbox.add_theme_constant_override("separation", 4)
	chart_hbox.custom_minimum_size = Vector2(264, 50)
	vbox.add_child(chart_hbox)

	# FPS图表
	_fps_chart = Control.new()
	_fps_chart.custom_minimum_size = Vector2(80, 50)
	_fps_chart.draw.connect(_draw_fps_chart)
	chart_hbox.add_child(_fps_chart)

	# 帧时间图表
	_frame_time_chart = Control.new()
	_frame_time_chart.custom_minimum_size = Vector2(80, 50)
	_frame_time_chart.draw.connect(_draw_frame_time_chart)
	chart_hbox.add_child(_frame_time_chart)

	# 内存图表
	_memory_chart = Control.new()
	_memory_chart.custom_minimum_size = Vector2(80, 50)
	_memory_chart.draw.connect(_draw_memory_chart)
	chart_hbox.add_child(_memory_chart)

	# 警告标签
	_warning_label = Label.new()
	_warning_label.text = ""
	_warning_label.visible = false
	_warning_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	_warning_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(_warning_label)

	print("[PerformanceMonitor] UI创建完成")


func _on_scene_changed() -> void:
	## 场景变化时重新创建UI
	if _monitor_panel and is_instance_valid(_monitor_panel):
		_monitor_panel.queue_free()
		_monitor_panel = null
	call_deferred("_create_ui")


# ==================== 图表绘制 ====================

func _draw_fps_chart() -> void:
	## 绘制FPS图表
	if not _fps_chart or fps_history.is_empty():
		return
	var size: Vector2 = _fps_chart.size
	var max_fps_val: float = 120.0
	var bar_width: float = size.x / float(HISTORY_LENGTH)

	# 背景
	_fps_chart.draw_rect(Rect2(0, 0, size.x, size.y), Color(0, 0, 0, 0.3))

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

	# 背景
	_frame_time_chart.draw_rect(Rect2(0, 0, size.x, size.y), Color(0, 0, 0, 0.3))

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

	# 背景
	_memory_chart.draw_rect(Rect2(0, 0, size.x, size.y), Color(0, 0, 0, 0.3))

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
