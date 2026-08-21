extends Node
## 错误捕获与崩溃报告系统（CrashReporter）- 《余烬 EMBER》
## 功能：
## 1. 手动报告错误API
## 2. 错误统计与计数
## 3. 崩溃报告生成与保存
## 4. 崩溃报告列表管理
## 5. 错误统计持久化

# ==================== 信号 ====================
signal error_caught(error_info: Dictionary)
signal crash_report_saved(report_path: String)
signal fatal_error_occurred(error_info: Dictionary)

# ==================== 配置 ====================
const MAX_REPORTS: int = 10
const CRASH_REPORT_DIR: String = "user://crash_reports/"
const ERROR_LOG_FILE: String = "user://logs/errors.log"
const SEPARATOR: String = "============================================================"

# ==================== 状态变量 ====================
var error_count: int = 0
var warning_count: int = 0
var fatal_error_count: int = 0
var last_error: Dictionary = {}
var error_stats: Dictionary = {}

# ==================== 生命周期 ====================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[CrashReporter] 错误捕获与崩溃报告系统已启动")
	if GameLogger:
		GameLogger.info("错误捕获与崩溃报告系统已启动", "CrashReporter")
	_ensure_crash_report_dir()


func _exit_tree() -> void:
	_save_error_stats()


# ==================== 公共API ====================

func report_error(error_message: String, error_type: String = "runtime", stack_trace: String = "", is_fatal: bool = false) -> Dictionary:
	## 手动报告一个错误
	var timestamp: String = Time.get_datetime_string_from_system()
	var error_info: Dictionary = {
		"timestamp": timestamp,
		"error_type": error_type,
		"message": error_message,
		"stack_trace": stack_trace,
		"is_fatal": is_fatal,
		"game_state": _get_game_state_snapshot(),
		"system_info": _get_system_info()
	}
	_process_error(error_info)
	return error_info


func get_error_stats() -> Dictionary:
	## 获取错误统计
	return {
		"total_errors": error_count,
		"total_warnings": warning_count,
		"fatal_errors": fatal_error_count,
		"by_type": error_stats.duplicate(),
		"last_error": last_error.duplicate()
	}


func get_crash_reports() -> Array:
	## 获取所有崩溃报告文件列表
	var reports: Array = []
	if DirAccess.dir_exists_absolute(CRASH_REPORT_DIR):
		var dir: DirAccess = DirAccess.open(CRASH_REPORT_DIR)
		if dir:
			dir.list_dir_begin()
			var file_name: String = dir.get_next()
			while file_name != "":
				if file_name.ends_with(".log") or file_name.ends_with(".txt"):
					reports.append(CRASH_REPORT_DIR + file_name)
				file_name = dir.get_next()
			dir.list_dir_end()
	return reports


func clear_old_reports() -> void:
	## 清理旧的崩溃报告（保留最新的MAX_REPORTS个）
	var reports: Array = get_crash_reports()
	if reports.size() <= MAX_REPORTS:
		return
	# 按文件名排序（文件名包含时间戳，按字母序即可按时间排序）
	reports.sort()
	# 删除最旧的报告（前面的）
	var to_delete: int = reports.size() - MAX_REPORTS
	for i in range(to_delete):
		var path: String = reports[i]
		DirAccess.remove_absolute(path)
		print("[CrashReporter] 已删除旧崩溃报告: ", path)


func export_latest_report() -> String:
	## 导出最近一次崩溃报告，返回报告内容
	if last_error.is_empty():
		return "暂无错误记录"
	return _format_crash_report(last_error)


# ==================== 错误处理 ====================

func _process_error(error_info: Dictionary) -> void:
	## 处理错误信息
	error_count += 1
	last_error = error_info
	# 按类型统计
	var error_type: String = error_info.get("error_type", "unknown")
	if not error_stats.has(error_type):
		error_stats[error_type] = 0
	error_stats[error_type] += 1
	# 记录到日志
	if GameLogger:
		GameLogger.error(
			"[%s] %s" % [error_type, error_info.get("message", "")],
			"CrashReporter"
		)
	# 发出信号
	error_caught.emit(error_info)
	# 如果是致命错误，生成崩溃报告
	if error_info.get("is_fatal", false):
		fatal_error_count += 1
		fatal_error_occurred.emit(error_info)
		_generate_crash_report(error_info)
	else:
		_show_in_game_error(error_info)


func _show_in_game_error(error_info: Dictionary) -> void:
	## 显示游戏内错误提示（非致命错误）
	var main_scene: Node = null
	if get_tree():
		main_scene = get_tree().current_scene
	if main_scene and main_scene.has_node("HUD"):
		var hud: Node = main_scene.get_node("HUD")
		if hud and hud.has_method("show_notification"):
			hud.show_notification("错误: " + str(error_info.get("message", "")), Color(1, 0.3, 0.3))


# ==================== 崩溃报告 ====================

func _generate_crash_report(error_info: Dictionary) -> void:
	## 生成崩溃报告并保存到文件
	var report_content: String = _format_crash_report(error_info)
	var timestamp: String = str(error_info.get("timestamp", "unknown"))
	timestamp = timestamp.replace(" ", "_").replace(":", "-")
	var report_path: String = CRASH_REPORT_DIR + "crash_" + timestamp + ".log"
	# 保存报告
	var file: FileAccess = FileAccess.open(report_path, FileAccess.WRITE)
	if file:
		file.store_string(report_content)
		file.close()
		print("[CrashReporter] 崩溃报告已保存: ", report_path)
		if GameLogger:
			GameLogger.error("崩溃报告已保存: " + report_path, "CrashReporter")
		crash_report_saved.emit(report_path)
	else:
		print("[CrashReporter] 无法保存崩溃报告: ", report_path)
	# 清理旧报告
	clear_old_reports()


func _format_crash_report(error_info: Dictionary) -> String:
	## 格式化崩溃报告内容
	var report: String = ""
	report += SEPARATOR + "\n"
	report += "余烬 EMBER - 崩溃报告\n"
	report += SEPARATOR + "\n\n"
	# 错误信息
	report += "【错误信息】\n"
	report += "时间: " + str(error_info.get("timestamp", "")) + "\n"
	report += "类型: " + str(error_info.get("error_type", "")) + "\n"
	report += "消息: " + str(error_info.get("message", "")) + "\n"
	report += "文件: " + str(error_info.get("error_file", "")) + "\n"
	report += "行号: " + str(error_info.get("error_line", 0)) + "\n"
	report += "是否致命: " + str(error_info.get("is_fatal", false)) + "\n\n"
	# 堆栈跟踪
	if error_info.get("stack_trace", "") != "":
		report += "【堆栈跟踪】\n"
		report += str(error_info.get("stack_trace", "")) + "\n\n"
	# 系统信息
	var sys_info: Dictionary = error_info.get("system_info", {})
	if not sys_info.is_empty():
		report += "【系统信息】\n"
		for key in sys_info.keys():
			report += str(key) + ": " + str(sys_info[key]) + "\n"
		report += "\n"
	# 游戏状态
	var game_state: Dictionary = error_info.get("game_state", {})
	if not game_state.is_empty():
		report += "【游戏状态】\n"
		for key in game_state.keys():
			report += str(key) + ": " + str(game_state[key]) + "\n"
		report += "\n"
	# 错误统计
	report += "【错误统计】\n"
	report += "总错误数: " + str(error_count) + "\n"
	report += "总警告数: " + str(warning_count) + "\n"
	report += "致命错误数: " + str(fatal_error_count) + "\n"
	report += "按类型统计:\n"
	for error_type in error_stats.keys():
		report += "  " + str(error_type) + ": " + str(error_stats[error_type]) + "\n"
	report += "\n"
	report += SEPARATOR + "\n"
	report += "报告结束\n"
	report += SEPARATOR + "\n"
	return report


# ==================== 辅助函数 ====================

func _ensure_crash_report_dir() -> void:
	## 确保崩溃报告目录存在
	if not DirAccess.dir_exists_absolute(CRASH_REPORT_DIR):
		DirAccess.make_dir_recursive_absolute(CRASH_REPORT_DIR)
		print("[CrashReporter] 崩溃报告目录已创建: ", CRASH_REPORT_DIR)


func _get_system_info() -> Dictionary:
	## 获取系统信息快照
	var memory_mb: int = 0
	if Performance:
		memory_mb = int(Performance.get_monitor(Performance.MEMORY_STATIC) / 1024 / 1024)
	var screen_size_str: String = "unknown"
	if DisplayServer:
		screen_size_str = str(DisplayServer.screen_get_size())
	return {
		"godot_version": str(Engine.get_version_info().get("string", "unknown")),
		"os_name": str(OS.get_name()),
		"os_version": str(OS.get_version()),
		"processor_count": str(OS.get_processor_count()),
		"memory_usage_mb": str(memory_mb),
		"screen_size": screen_size_str,
		"locale": str(OS.get_locale()),
		"cmdline": str(OS.get_cmdline_args())
	}


func _get_game_state_snapshot() -> Dictionary:
	## 获取游戏状态快照
	var current_scene_name: String = "null"
	var is_paused: bool = false
	var fps_val: int = 0
	var time_scale_val: float = 1.0
	if get_tree():
		if get_tree().current_scene:
			current_scene_name = get_tree().current_scene.name
		is_paused = get_tree().paused
	fps_val = Engine.get_frames_per_second()
	time_scale_val = Engine.time_scale
	var snapshot: Dictionary = {
		"current_scene": current_scene_name,
		"fps": str(fps_val),
		"time_scale": str(time_scale_val),
		"paused": str(is_paused)
	}
	# 尝试获取玩家信息
	if GameManager and GameManager.has_method("get_local_player"):
		var player: Node = GameManager.get_local_player()
		if player:
			if "position" in player:
				snapshot["player_position"] = str(player.position)
			if "health" in player:
				snapshot["player_health"] = str(player.health)
	# 尝试获取游戏世界信息
	if GameManager and GameManager.has_method("get_game_world"):
		var world: Node = GameManager.get_game_world()
		if world:
			snapshot["world_children"] = str(world.get_child_count())
	return snapshot


func _save_error_stats() -> void:
	## 保存错误统计到文件
	var stats: Dictionary = get_error_stats()
	var file: FileAccess = FileAccess.open(ERROR_LOG_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(stats, "\t"))
		file.close()
		print("[CrashReporter] 错误统计已保存: ", ERROR_LOG_FILE)
