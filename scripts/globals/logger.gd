extends Node
## 全局日志系统 Logger
## 功能：
## 1. 四个日志级别：DEBUG、INFO、WARNING、ERROR
## 2. 输出到 Godot 控制台和本地文件 user://logs/game.log
## 3. 日志格式：[时间戳] [级别] [模块名] 消息内容
## 4. 运行时设置日志级别
## 5. 文件自动轮转（超过5MB重命名，保留最近3个）
## 6. 异步写入（内存队列，定时批量写入）

# ==================== 日志级别枚举 ====================
enum Level {
	DEBUG = 0,
	INFO = 1,
	WARNING = 2,
	ERROR = 3
}

# 级别名称映射
const LEVEL_NAMES := {
	Level.DEBUG: "DEBUG",
	Level.INFO: "INFO",
	Level.WARNING: "WARNING",
	Level.ERROR: "ERROR"
}

# ==================== 配置 ====================
const LOG_DIR: String = "user://logs"
const LOG_FILE: String = "user://logs/game.log"
const MAX_FILE_SIZE: int = 5 * 1024 * 1024  # 5MB
const MAX_LOG_FILES: int = 3  # 保留最近3个日志文件
const FLUSH_INTERVAL: float = 1.0  # 定时刷盘间隔（秒）
const QUEUE_MAX_SIZE: int = 1000  # 内存队列最大长度

# ==================== 状态变量 ====================
var _current_level: int = Level.DEBUG
var _log_queue: Array = []  # 内存日志队列
var _file: FileAccess = null  # 文件句柄
var _flush_timer: float = 0.0
var _initialized: bool = false


# ==================== 生命周期 ====================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_init_log_system()
	info("游戏启动", "Logger")
	debug("日志系统初始化完成", "Logger")


func _process(delta: float) -> void:
	if not _initialized:
		return
	_flush_timer += delta
	if _flush_timer >= FLUSH_INTERVAL:
		_flush_timer = 0.0
		_flush_queue()


func _exit_tree() -> void:
	# 退出时刷盘
	_flush_queue()
	if _file:
		_file.close()
		_file = null


# ==================== 公共API ====================

func debug(message: String, module: String = "General") -> void:
	## 记录 DEBUG 级别日志
	_log(Level.DEBUG, message, module)


func info(message: String, module: String = "General") -> void:
	## 记录 INFO 级别日志
	_log(Level.INFO, message, module)


func warning(message: String, module: String = "General") -> void:
	## 记录 WARNING 级别日志
	_log(Level.WARNING, message, module)


func error(message: String, module: String = "General") -> void:
	## 记录 ERROR 级别日志
	_log(Level.ERROR, message, module)


func set_level(level: int) -> void:
	## 设置当前日志级别，低于该级别的日志不输出
	if level >= Level.DEBUG and level <= Level.ERROR:
		_current_level = level
		print("[Logger] 日志级别设置为: ", LEVEL_NAMES[level])


func get_level() -> int:
	## 获取当前日志级别
	return _current_level


func get_level_name() -> String:
	## 获取当前日志级别名称
	return LEVEL_NAMES[_current_level]


func flush() -> void:
	## 手动刷盘
	_flush_queue()


func log_script_error(message: String) -> void:
	## 记录脚本错误（供外部调用）
	error("脚本错误: " + message, "Script")


# ==================== 内部实现 ====================

func _init_log_system() -> void:
	## 初始化日志系统
	# 确保日志目录存在
	if not DirAccess.dir_exists_absolute(LOG_DIR):
		var err := DirAccess.make_dir_recursive_absolute(LOG_DIR)
		if err != OK:
			push_error("[Logger] 无法创建日志目录: " + LOG_DIR)
			return
	
	# 检查文件大小，必要时轮转
	_check_and_rotate()
	
	# 打开文件（追加模式）
	_file = FileAccess.open(LOG_FILE, FileAccess.WRITE_READ)
	if not _file:
		push_error("[Logger] 无法打开日志文件: " + LOG_FILE)
		return
	
	# 移动到文件末尾
	_file.seek_end()
	
	_initialized = true
	print("[Logger] 日志系统初始化完成，日志文件: ", LOG_FILE)


func _log(level: int, message: String, module: String) -> void:
	## 记录日志
	# 级别过滤
	if level < _current_level:
		return
	
	# 格式化日志
	var timestamp: String = _get_timestamp()
	var level_name: String = LEVEL_NAMES.get(level, "UNKNOWN")
	var log_line: String = "[%s] [%s] [%s] %s" % [timestamp, level_name, module, message]
	
	# 输出到控制台
	match level:
		Level.DEBUG:
			print(log_line)
		Level.INFO:
			print(log_line)
		Level.WARNING:
			push_warning(log_line)
		Level.ERROR:
			push_error(log_line)
	
	# 加入内存队列（异步写入文件）
	if _initialized:
		_log_queue.append(log_line)
		# 队列过长时立即刷盘
		if _log_queue.size() >= QUEUE_MAX_SIZE:
			_flush_queue()


func _get_timestamp() -> String:
	## 获取当前时间戳，格式：YYYY-MM-DD HH:MM:SS
	var now: Dictionary = Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d %02d:%02d:%02d" % [
		now.year, now.month, now.day,
		now.hour, now.minute, now.second
	]


func _flush_queue() -> void:
	## 将内存队列中的日志写入文件
	if not _initialized or _log_queue.is_empty():
		return
	
	if not _file:
		# 尝试重新打开文件
		_file = FileAccess.open(LOG_FILE, FileAccess.WRITE_READ)
		if not _file:
			return
		_file.seek_end()
	
	# 批量写入
	var content: String = ""
	for line in _log_queue:
		content += line + "\n"
	
	_file.store_string(content)
	_file.flush()  # 确保写入磁盘
	
	_log_queue.clear()
	
	# 检查文件大小，必要时轮转
	_check_and_rotate()


func _check_and_rotate() -> void:
	## 检查日志文件大小，超过5MB时轮转
	if not FileAccess.file_exists(LOG_FILE):
		return
	
	var file_size: int = FileAccess.get_file_as_bytes(LOG_FILE).size()
	if file_size < MAX_FILE_SIZE:
		return
	
	# 关闭当前文件
	if _file:
		_file.close()
		_file = null
	
	# 生成新文件名：game_YYYYMMDD_HHMMSS.log
	var now: Dictionary = Time.get_datetime_dict_from_system()
	var timestamp: String = "%04d%02d%02d_%02d%02d%02d" % [
		now.year, now.month, now.day,
		now.hour, now.minute, now.second
	]
	var new_name: String = "user://logs/game_%s.log" % timestamp
	
	# 重命名当前文件
	DirAccess.rename_absolute(LOG_FILE, new_name)
	
	# 删除旧的日志文件，只保留最近 MAX_LOG_FILES 个
	_cleanup_old_logs()
	
	# 重新打开新的日志文件
	_file = FileAccess.open(LOG_FILE, FileAccess.WRITE_READ)
	if _file:
		_file.seek_end()
	
	print("[Logger] 日志文件已轮转: ", new_name)


func _cleanup_old_logs() -> void:
	## 清理旧的日志文件，只保留最近 MAX_LOG_FILES 个
	var dir := DirAccess.open(LOG_DIR)
	if not dir:
		return
	
	# 收集所有轮转的日志文件
	var log_files: Array = []
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name.begins_with("game_") and file_name.ends_with(".log"):
			var full_path: String = LOG_DIR + "/" + file_name
			log_files.append({
				"name": file_name,
				"path": full_path,
				"time": FileAccess.get_modified_time(full_path)
			})
		file_name = dir.get_next()
	dir.list_dir_end()
	
	# 按修改时间排序（最新的在前）
	log_files.sort_custom(func(a, b): return a.time > b.time)
	
	# 删除超过 MAX_LOG_FILES 的旧文件
	for i in range(MAX_LOG_FILES, log_files.size()):
		var old_file: Dictionary = log_files[i]
		DirAccess.remove_absolute(old_file.path)
		print("[Logger] 删除旧日志文件: ", old_file.name)
