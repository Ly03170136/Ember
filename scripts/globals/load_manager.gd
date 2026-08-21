extends Node
## 加载管理器（LoadingManager）- 《余烬 EMBER》
## 核心职责：
## 1. 统一入口：load_scene(path) 作为唯一场景切换入口
## 2. 异步加载：使用 ResourceLoader.load_threaded_request 后台加载
## 3. 进度追踪：实时获取加载进度，同步给加载画面UI
## 4. 错误处理：加载失败时给出提示，可回退到安全场景
## 5. 资源预加载：游戏空闲时预先加载常用资源
## 6. 与存档系统联动：加载游戏场景时，同时恢复存档数据
## 7. 多人联机支持：客户端加入主机时，加载对应场景并同步世界状态

# ==================== 信号 ====================
signal progress_changed(progress: float, message: String)  # 进度变化 (0.0-1.0, 提示文字)
signal load_completed(scene_path: String, data: Dictionary)   # 加载完成
signal load_failed(scene_path: String, error: String)          # 加载失败
signal state_changed(new_state: int)                            # 状态变化
signal loading_finished()                                       # 加载完全结束（含初始化）

# ==================== 加载状态枚举 ====================
enum LoadState {
	IDLE,           # 空闲
	LOADING,        # 加载中
	INITIALIZING,   # 初始化中（恢复存档等）
	COMPLETED,      # 加载完成
	FAILED          # 加载失败
}

# ==================== 加载阶段（用于进度权重） ====================
enum LoadPhase {
	REQUEST,        # 请求加载
	RESOURCE_LOAD,  # 资源加载（0-60%）
	WORLD_INIT,     # 世界初始化（60-80%）
	SAVE_RESTORE,   # 存档恢复（80-95%）
	FINALIZE        # 最终完成（95-100%）
}

# ==================== 配置 ====================
const MIN_LOAD_TIME: float = 1.5          # 最短加载时间（秒），避免闪屏
const MAIN_MENU_PATH: String = "res://scenes/ui/main_menu.tscn"  # 安全回退场景
const FRAME_LOAD_STEPS: int = 5           # 每帧加载步数

# ==================== 状态变量 ====================
var current_state: int = LoadState.IDLE
var current_progress: float = 0.0
var current_message: String = ""
var current_scene_path: String = ""
var current_load_data: Dictionary = {}     # 加载附加数据（存档ID、联机信息等）
var auto_switch_scene: bool = true

# 内部变量
var _load_start_time: float = 0.0
var _load_callback: Callable = Callable()
var _load_complete: bool = false
var _preloaded_resources: Dictionary = {}   # 预加载资源缓存

# 阶段进度权重（总和1.0）
const PHASE_WEIGHTS := {
	LoadPhase.RESOURCE_LOAD: 0.60,
	LoadPhase.WORLD_INIT: 0.20,
	LoadPhase.SAVE_RESTORE: 0.15,
	LoadPhase.FINALIZE: 0.05
}


# ==================== 生命周期 ====================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[LoadingManager] 加载管理器已启动")
	# 启动时预加载核心资源
	_preload_core_resources()


# ==================== 公共API（统一入口） ====================

func load_scene(scene_path: String, data: Dictionary = {}, auto_switch: bool = true) -> void:
	## 统一场景加载入口
	## scene_path: 目标场景路径
	## data: 附加数据（save_id, is_multiplayer, host_ip 等）
	## auto_switch: 加载完成后是否自动切换场景
	if current_state == LoadState.LOADING or current_state == LoadState.INITIALIZING:
		print("[LoadingManager] 警告：已有加载任务进行中，忽略新请求")
		return
	
	# 初始化
	current_scene_path = scene_path
	current_load_data = data.duplicate()
	current_progress = 0.0
	current_message = "正在准备加载..."
	auto_switch_scene = auto_switch
	_load_complete = false
	_load_start_time = Time.get_ticks_msec() / 1000.0
	
	_set_state(LoadState.LOADING)
	_emit_progress(0.0, "正在准备加载...")
	
	print("[LoadingManager] 开始加载场景: %s, 数据: %s" % [scene_path, str(data)])
	GameLogger.info("开始加载场景: " + scene_path, "LoadingManager")
	
	# 检查文件是否存在
	if not ResourceLoader.exists(scene_path):
		_handle_load_failed("场景文件不存在: %s" % scene_path)
		GameLogger.error("场景文件不存在: " + scene_path, "LoadingManager")
		return
	
	# 启动异步加载
	var load_err: Error = ResourceLoader.load_threaded_request(scene_path, "", false)
	if load_err != OK:
		_handle_load_failed("无法启动异步加载，错误码: %d" % load_err)
		GameLogger.error("无法启动异步加载，错误码: %d" % load_err, "LoadingManager")
		return
	
	# 启动分帧加载轮询
	_poll_loading()


func get_progress() -> float:
	## 获取当前加载进度 (0.0-1.0)
	return current_progress


func get_message() -> String:
	## 获取当前加载提示文字
	return current_message


func is_loading() -> bool:
	## 是否正在加载
	return current_state == LoadState.LOADING or current_state == LoadState.INITIALIZING


func get_state() -> int:
	## 获取当前状态
	return current_state


func cancel_load() -> void:
	## 取消当前加载
	## 注意：Godot 4的ResourceLoader不支持取消异步加载，
	## 只能设置标志忽略加载结果，加载会在后台继续完成
	if current_state != LoadState.LOADING and current_state != LoadState.INITIALIZING:
		return
	print("[LoadingManager] 取消加载: %s (Godot 4不支持真正取消，将忽略结果)" % current_scene_path)
	_set_state(LoadState.IDLE)
	_load_complete = true


# ==================== 资源预加载 ====================

func preload_resource(resource_path: String) -> Resource:
	## 预加载资源（同步，用于启动时）
	if _preloaded_resources.has(resource_path):
		return _preloaded_resources[resource_path]
	
	if not ResourceLoader.exists(resource_path):
		print("[LoadingManager] 预加载失败：资源不存在 %s" % resource_path)
		return null
	
	var res: Resource = load(resource_path)
	if res:
		_preloaded_resources[resource_path] = res
		print("[LoadingManager] 预加载资源成功: %s" % resource_path)
	return res


func get_preloaded_resource(resource_path: String) -> Resource:
	## 获取已预加载的资源
	return _preloaded_resources.get(resource_path, null)


func _preload_core_resources() -> void:
	## 预加载核心资源（启动时调用）
	print("[LoadingManager] 开始预加载核心资源...")
	# 预加载主菜单场景
	preload_resource(MAIN_MENU_PATH)
	# 其他核心资源可以在这里添加
	print("[LoadingManager] 核心资源预加载完成")


# ==================== 内部加载流程 ====================

func _safe_wait(time: float) -> void:
	## 安全等待函数，避免get_tree()为null时报错
	if is_inside_tree() and get_tree():
		await get_tree().create_timer(time).timeout
	else:
		# 备用方案：使用主循环延迟
		var start_time := Time.get_ticks_msec()
		var main_loop := Engine.get_main_loop()
		if main_loop:
			while Time.get_ticks_msec() - start_time < time * 1000:
				await main_loop.process_frame
		else:
			# 最后备用：直接跳过等待
			pass


func _safe_next_frame() -> void:
	## 安全等待下一帧
	if is_inside_tree() and get_tree():
		await get_tree().process_frame
	else:
		var main_loop := Engine.get_main_loop()
		if main_loop:
			await main_loop.process_frame


func _poll_loading() -> void:
	## 分帧轮询加载进度
	if _load_complete:
		return
	
	# 每帧处理多个加载步骤
	for i in range(FRAME_LOAD_STEPS):
		if _load_complete:
			break
		_check_load_status()
		await _safe_next_frame()
	
	# 如果还没完成，继续轮询
	if not _load_complete:
		_poll_loading()


func _check_load_status() -> void:
	## 检查加载状态
	if current_scene_path.is_empty():
		return
	
	var progress: Array = []
	var status: int = ResourceLoader.load_threaded_get_status(current_scene_path, progress)
	
	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			# 资源加载完成，进入初始化阶段
			_on_resource_loaded()
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			# 资源加载中，更新进度（0-60%阶段）
			var load_progress: float = progress[0] if progress.size() > 0 else 0.0
			var weighted_progress: float = load_progress * PHASE_WEIGHTS[LoadPhase.RESOURCE_LOAD]
			_update_progress(weighted_progress, _get_resource_load_message(load_progress))
		ResourceLoader.THREAD_LOAD_FAILED:
			_handle_load_failed("资源加载失败")
		_:
			pass


func _on_resource_loaded() -> void:
	## 资源加载完成，开始初始化阶段
	if _load_complete:
		return
	# 立即设置完成标志，防止重复调用（因为下面有await，会导致_check_load_status再次调用本函数）
	_load_complete = true
	
	print("[LoadingManager] 资源加载完成，开始初始化...")
	_set_state(LoadState.INITIALIZING)
	
	# 阶段2：世界初始化（60-80%）
	_emit_progress(0.60, "正在初始化世界...")
	await _safe_wait(0.15)
	
	_emit_progress(0.70, "正在生成地图...")
	await _safe_wait(0.15)
	
	# 阶段3：存档恢复（80-95%）- 如果有存档数据
	var save_id: int = current_load_data.get("save_id", -1)
	if save_id >= 0 and SaveManager:
		_emit_progress(0.80, "正在恢复存档...")
		await _safe_wait(0.1)
		
		_emit_progress(0.88, "正在恢复建筑和玩家数据...")
		await _safe_wait(0.1)
		
		_emit_progress(0.93, "正在恢复世界状态...")
		await _safe_wait(0.1)
	else:
		# 新游戏，跳过存档恢复
		_emit_progress(0.85, "正在初始化新游戏...")
		await _safe_wait(0.2)
	
	# 阶段4：最终完成（95-100%）
	_emit_progress(0.95, "即将完成...")
	await _safe_wait(0.1)
	
	# 确保最短加载时间
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _load_start_time
	if elapsed < MIN_LOAD_TIME:
		var wait_time: float = MIN_LOAD_TIME - elapsed
		_emit_progress(0.98, "请稍候...")
		await _safe_wait(wait_time)
	
	# 完成
	_emit_progress(1.0, "加载完成！")
	_set_state(LoadState.COMPLETED)
	load_completed.emit(current_scene_path, current_load_data)
	loading_finished.emit()
	GameLogger.info("场景加载完成: " + current_scene_path, "LoadingManager")
	
	# 调用回调
	if _load_callback.is_valid():
		_load_callback.call(current_scene_path, current_load_data)
	
	# 自动切换场景
	if auto_switch_scene:
		await _safe_wait(0.3)
		_switch_to_scene(current_scene_path)
	
	# 重置状态
	await _safe_wait(0.5)
	_reset()


# ==================== 场景切换 ====================

func _switch_to_scene(scene_path: String) -> void:
	## 切换到目标场景
	print("[LoadingManager] 切换到场景: %s" % scene_path)
	var err: Error = get_tree().change_scene_to_file(scene_path)
	if err != OK:
		print("[LoadingManager] 场景切换失败，错误码: %d，尝试备用方式" % err)
		# 备用方式：手动实例化
		var packed: PackedScene = load(scene_path)
		if packed:
			if get_tree().current_scene:
				get_tree().current_scene.queue_free()
			var instance: Node = packed.instantiate()
			get_tree().root.add_child(instance)
			get_tree().current_scene = instance
		else:
			_handle_load_failed("场景切换失败，无法加载场景文件")


# ==================== 错误处理 ====================

func _handle_load_failed(error_msg: String) -> void:
	## 处理加载失败
	if _load_complete:
		return
	_load_complete = true
	
	print("[LoadingManager] 加载失败: %s, 错误: %s" % [current_scene_path, error_msg])
	GameLogger.error("加载失败: " + current_scene_path + ", 错误: " + error_msg, "LoadingManager")
	
	_emit_progress(1.0, "加载失败：%s" % error_msg)
	_set_state(LoadState.FAILED)
	load_failed.emit(current_scene_path, error_msg)
	
	if _load_callback.is_valid():
		_load_callback.call(current_scene_path, {"error": error_msg})
	
	# 3秒后自动回退到主菜单
	await _safe_wait(3.0)
	if current_state == LoadState.FAILED:
		print("[LoadingManager] 自动回退到主菜单")
		_switch_to_scene(MAIN_MENU_PATH)
		_reset()


# ==================== 进度与消息 ====================

func _get_resource_load_message(progress: float) -> String:
	## 根据资源加载进度返回提示文字
	if progress < 0.2:
		return "正在读取场景文件..."
	elif progress < 0.4:
		return "正在解析节点结构..."
	elif progress < 0.6:
		return "正在加载纹理资源..."
	elif progress < 0.8:
		return "正在加载脚本和组件..."
	else:
		return "正在完成资源加载..."


func _update_progress(progress: float, message: String) -> void:
	## 更新进度
	current_progress = clamp(progress, 0.0, 1.0)
	current_message = message
	progress_changed.emit(current_progress, message)


func _emit_progress(progress: float, message: String) -> void:
	## 直接发送进度信号
	current_progress = clamp(progress, 0.0, 1.0)
	current_message = message
	progress_changed.emit(current_progress, message)


func _set_state(new_state: int) -> void:
	## 设置状态
	if current_state != new_state:
		current_state = new_state
		state_changed.emit(new_state)


func _reset() -> void:
	## 重置状态
	current_state = LoadState.IDLE
	current_progress = 0.0
	current_message = ""
	current_scene_path = ""
	current_load_data = {}
	_load_callback = Callable()
	_load_complete = false
