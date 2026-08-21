extends Node
## TimerManager - 统一计时器管理器
## 功能：
## 1. 统一计时器创建和管理
## 2. 支持暂停/恢复（单个或全部）
## 3. 支持取消计时器
## 4. 支持时间缩放（加速/减速）
## 5. 支持定时任务（一次性、重复、延迟执行）
## 6. 游戏暂停时自动暂停（可选）

# ==================== 信号 ====================
signal timer_started(timer_id)           # 计时器开始
signal timer_completed(timer_id)         # 计时器完成
signal timer_cancelled(timer_id)         # 计时器被取消
signal timer_paused(timer_id)            # 计时器被暂停
signal timer_resumed(timer_id)           # 计时器被恢复
signal all_timers_cleared()              # 所有计时器被清除
signal time_scale_changed(new_scale)      # 时间缩放改变

# ==================== 配置 ====================
const MAX_TIMERS = 256                    # 最大计时器数量
const DEFAULT_TIME_SCALE = 1.0            # 默认时间缩放

# ==================== 状态变量 ====================
var _timers = {}                           # 计时器字典 {id: {duration, remaining, callback, repeat, ...}}
var _next_timer_id = 1                     # 下一个计时器ID
var _time_scale = DEFAULT_TIME_SCALE       # 当前时间缩放
var _global_paused = false                 # 全局暂停状态
var _auto_pause_with_game = true           # 游戏暂停时自动暂停计时器
var _stats = {                              # 统计信息
	"total_created": 0,
	"total_completed": 0,
	"total_cancelled": 0,
	"active_count": 0,
	"paused_count": 0
}

# ==================== 生命周期 ====================

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[TimerManager] 计时器管理器已启动，最大计时器数: %d" % MAX_TIMERS)


func _process(delta):
	# 如果全局暂停，不更新计时器
	if _global_paused:
		return
	# 使用时间缩放后的delta
	var scaled_delta = delta * _time_scale
	# 更新所有计时器
	var completed_ids = []
	for timer_id in _timers.keys():
		var timer = _timers[timer_id]
		# 跳过暂停的计时器
		if timer["paused"]:
			continue
		# 跳过已完成的计时器
		if timer["completed"]:
			continue
		# 更新剩余时间
		if timer["use_unscaled_time"]:
			timer["remaining"] -= delta
		else:
			timer["remaining"] -= scaled_delta
		# 检查是否完成
		if timer["remaining"] <= 0.0:
			completed_ids.append(timer_id)
	# 处理完成的计时器
	for timer_id in completed_ids:
		_complete_timer(timer_id)
	# 更新统计
	_update_stats()


# ==================== 公共API - 创建计时器 ====================

func create_timer(duration, callback, repeat = false, repeat_count = -1, use_unscaled_time = false):
	## 创建计时器
	## duration: 时长（秒）
	## callback: 回调函数 Callable
	## repeat: 是否重复
	## repeat_count: 重复次数（-1表示无限，仅在repeat=true时有效）
	## use_unscaled_time: 是否使用不受时间缩放影响的时间
	## 返回: 计时器ID（-1表示创建失败）
	if duration <= 0.0:
		print("[TimerManager] 错误：计时器时长必须大于0")
		return -1
	if _timers.size() >= MAX_TIMERS:
		print("[TimerManager] 错误：计时器数量已达上限 %d" % MAX_TIMERS)
		return -1
	var timer_id = _next_timer_id
	_next_timer_id += 1
	var timer = {
		"id": timer_id,
		"duration": duration,
		"remaining": duration,
		"callback": callback,
		"repeat": repeat,
		"repeat_count": repeat_count,
		"current_repeat": 0,
		"paused": false,
		"completed": false,
		"use_unscaled_time": use_unscaled_time,
		"created_time": Time.get_ticks_msec()
	}
	_timers[timer_id] = timer
	_stats["total_created"] += 1
	timer_started.emit(timer_id)
	return timer_id


func schedule_once(delay, callback, use_unscaled_time = false):
	## 延迟执行一次（一次性计时器）
	## delay: 延迟时间（秒）
	## callback: 回调函数
	## 返回: 计时器ID
	return create_timer(delay, callback, false, -1, use_unscaled_time)


func schedule_repeat(interval, callback, count = -1, use_unscaled_time = false):
	## 重复执行
	## interval: 间隔时间（秒）
	## callback: 回调函数
	## count: 重复次数（-1表示无限）
	## 返回: 计时器ID
	return create_timer(interval, callback, true, count, use_unscaled_time)


func schedule_frame(callback):
	## 下一帧执行
	## callback: 回调函数
	## 返回: 计时器ID
	return create_timer(0.001, callback, false, -1, true)


# ==================== 公共API - 计时器控制 ====================

func pause_timer(timer_id):
	## 暂停指定计时器
	if not _timers.has(timer_id):
		return false
	var timer = _timers[timer_id]
	if timer["paused"] or timer["completed"]:
		return false
	timer["paused"] = true
	timer_paused.emit(timer_id)
	return true


func resume_timer(timer_id):
	## 恢复指定计时器
	if not _timers.has(timer_id):
		return false
	var timer = _timers[timer_id]
	if not timer["paused"] or timer["completed"]:
		return false
	timer["paused"] = false
	timer_resumed.emit(timer_id)
	return true


func cancel_timer(timer_id):
	## 取消指定计时器
	if not _timers.has(timer_id):
		return false
	_timers.erase(timer_id)
	_stats["total_cancelled"] += 1
	timer_cancelled.emit(timer_id)
	return true


func reset_timer(timer_id):
	## 重置指定计时器（重新开始计时）
	if not _timers.has(timer_id):
		return false
	var timer = _timers[timer_id]
	timer["remaining"] = timer["duration"]
	timer["paused"] = false
	timer["completed"] = false
	timer["current_repeat"] = 0
	return true


func get_timer_remaining(timer_id):
	## 获取计时器剩余时间
	if not _timers.has(timer_id):
		return -1.0
	return _timers[timer_id]["remaining"]


func get_timer_progress(timer_id):
	## 获取计时器进度（0.0 - 1.0）
	if not _timers.has(timer_id):
		return -1.0
	var timer = _timers[timer_id]
	if timer["duration"] <= 0.0:
		return 1.0
	return 1.0 - (timer["remaining"] / timer["duration"])


func is_timer_active(timer_id):
	## 检查计时器是否活跃（未暂停、未完成）
	if not _timers.has(timer_id):
		return false
	var timer = _timers[timer_id]
	return not timer["paused"] and not timer["completed"]


func is_timer_paused(timer_id):
	## 检查计时器是否暂停
	if not _timers.has(timer_id):
		return false
	return _timers[timer_id]["paused"]


# ==================== 公共API - 全局控制 ====================

func pause_all():
	## 暂停所有计时器
	_global_paused = true
	for timer_id in _timers.keys():
		var timer = _timers[timer_id]
		if not timer["paused"] and not timer["completed"]:
			timer["paused"] = true
			timer_paused.emit(timer_id)
	print("[TimerManager] 所有计时器已暂停")


func resume_all():
	## 恢复所有计时器
	_global_paused = false
	for timer_id in _timers.keys():
		var timer = _timers[timer_id]
		if timer["paused"] and not timer["completed"]:
			timer["paused"] = false
			timer_resumed.emit(timer_id)
	print("[TimerManager] 所有计时器已恢复")


func cancel_all():
	## 取消所有计时器
	var count = _timers.size()
	_timers.clear()
	_stats["total_cancelled"] += count
	all_timers_cleared.emit()
	print("[TimerManager] 所有计时器已取消，共 %d 个" % count)


func clear_completed():
	## 清除已完成的计时器
	var removed = 0
	for timer_id in _timers.keys():
		if _timers[timer_id]["completed"]:
			_timers.erase(timer_id)
			removed += 1
	if removed > 0:
		print("[TimerManager] 清除了 %d 个已完成的计时器" % removed)


# ==================== 公共API - 时间缩放 ====================

func set_time_scale(scale):
	## 设置时间缩放（1.0=正常，2.0=2倍速，0.5=半速，0=暂停）
	if scale < 0.0:
		scale = 0.0
	_time_scale = scale
	time_scale_changed.emit(_time_scale)
	print("[TimerManager] 时间缩放设置为: %.2fx" % _time_scale)


func get_time_scale():
	## 获取当前时间缩放
	return _time_scale


func reset_time_scale():
	## 重置时间缩放为默认值
	set_time_scale(DEFAULT_TIME_SCALE)


# ==================== 公共API - 游戏暂停联动 ====================

func set_auto_pause_with_game(enabled):
	## 设置是否在游戏暂停时自动暂停计时器
	_auto_pause_with_game = enabled


func on_game_paused():
	## 游戏暂停时调用（自动暂停计时器）
	if _auto_pause_with_game:
		pause_all()


func on_game_resumed():
	## 游戏恢复时调用（自动恢复计时器）
	if _auto_pause_with_game:
		resume_all()


# ==================== 公共API - 统计和监控 ====================

func get_stats():
	## 获取统计信息
	_update_stats()
	return _stats.duplicate()


func get_active_timer_count():
	## 获取活跃计时器数量
	var count = 0
	for timer_id in _timers.keys():
		var timer = _timers[timer_id]
		if not timer["paused"] and not timer["completed"]:
			count += 1
	return count


func get_paused_timer_count():
	## 获取暂停计时器数量
	var count = 0
	for timer_id in _timers.keys():
		if _timers[timer_id]["paused"]:
			count += 1
	return count


func get_all_timer_ids():
	## 获取所有计时器ID
	return _timers.keys()


func print_stats():
	## 打印统计信息
	var stats = get_stats()
	print("[TimerManager] ===== 计时器统计 =====")
	print("[TimerManager] 总创建数: %d" % stats["total_created"])
	print("[TimerManager] 总完成数: %d" % stats["total_completed"])
	print("[TimerManager] 总取消数: %d" % stats["total_cancelled"])
	print("[TimerManager] 当前活跃数: %d" % stats["active_count"])
	print("[TimerManager] 当前暂停数: %d" % stats["paused_count"])
	print("[TimerManager] 时间缩放: %.2fx" % _time_scale)
	print("[TimerManager] 全局暂停: %s" % str(_global_paused))
	print("[TimerManager] ========================")


# ==================== 内部方法 ====================

func _complete_timer(timer_id):
	## 完成计时器
	if not _timers.has(timer_id):
		return
	var timer = _timers[timer_id]
	# 标记为完成
	timer["completed"] = true
	_stats["total_completed"] += 1
	# 调用回调
	if timer["callback"] != Callable() and timer["callback"].is_valid():
		timer["callback"].call(timer_id)
	# 发出完成信号
	timer_completed.emit(timer_id)
	# 如果是重复计时器，重置并继续
	if timer["repeat"]:
		timer["current_repeat"] += 1
		# 检查是否达到重复次数
		if timer["repeat_count"] > 0 and timer["current_repeat"] >= timer["repeat_count"]:
			# 已达到重复次数，移除计时器
			_timers.erase(timer_id)
		else:
			# 重置计时器，继续重复
			timer["remaining"] = timer["duration"]
			timer["completed"] = false
	else:
		# 一次性计时器，移除
		_timers.erase(timer_id)


func _update_stats():
	## 更新统计信息
	var active = 0
	var paused = 0
	for timer_id in _timers.keys():
		var timer = _timers[timer_id]
		if timer["completed"]:
			continue
		if timer["paused"]:
			paused += 1
		else:
			active += 1
	_stats["active_count"] = active
	_stats["paused_count"] = paused
