extends Node
## ResourceCacheManager - 统一资源缓存管理器
## 功能：
## 1. 统一资源加载和缓存入口
## 2. LRU（最近最少使用）淘汰机制
## 3. 内存统计和监控
## 4. 预加载队列（异步、优先级）
## 5. 资源分包/按需加载

# ==================== 信号 ====================
signal resource_loaded(path, resource)  # 资源加载完成
signal resource_unloaded(path)           # 资源被卸载
signal cache_cleared()                   # 缓存被清空
signal preload_progress(current, total)  # 预加载进度
signal preload_completed()               # 预加载完成
signal memory_limit_exceeded()           # 内存超限

# ==================== 配置 ====================
const DEFAULT_CACHE_LIMIT_MB = 256.0    # 默认缓存上限（MB）
const LRU_CHECK_INTERVAL = 5.0           # LRU检查间隔（秒）
const RESOURCE_SIZE_ESTIMATE = {         # 资源类型大小估算（字节）
	"PackedScene": 102400,
	"Texture2D": 204800,
	"AudioStream": 51200,
	"Font": 25600,
	"Shader": 10240,
	"Material": 5120,
	"default": 10240
}

# ==================== 状态变量 ====================
var cache_limit_mb = DEFAULT_CACHE_LIMIT_MB  # 缓存上限（MB）
var _resource_cache = {}                        # 资源缓存 {path: {resource, last_access, size, type}}
var _preload_queue = []                         # 预加载队列 [{path, priority, callback}]
var _is_preloading = false                      # 是否正在预加载
var _current_preload_index = 0                  # 当前预加载索引
var _total_preload_count = 0                    # 总预加载数量
var _lru_timer = 0.0                            # LRU计时器
var _stats = {                                   # 统计信息
	"total_loads": 0,
	"cache_hits": 0,
	"cache_misses": 0,
	"total_unloaded": 0,
	"current_cache_count": 0,
	"estimated_memory_usage": 0
}
var _resource_packages = {}                     # 资源分包 {package_name: [paths]}

# ==================== 生命周期 ====================

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[ResourceCache] 资源缓存管理器已启动，缓存上限: %.0f MB" % cache_limit_mb)
	_register_default_packages()


func _process(delta):
	# LRU检查
	_lru_timer += delta
	if _lru_timer >= LRU_CHECK_INTERVAL:
		_lru_timer = 0.0
		_check_lru_eviction()
	# 处理预加载队列
	if _is_preloading and _current_preload_index < _preload_queue.size():
		_process_preload_queue()


# ==================== 公共API - 资源加载 ====================

func load_resource(path, use_cache = true):
	## 加载资源（带缓存）
	if use_cache and _resource_cache.has(path):
		# 缓存命中
		_stats["cache_hits"] += 1
		var entry = _resource_cache[path]
		entry["last_access"] = Time.get_ticks_msec()
		return entry["resource"]
	# 缓存未命中，加载资源
	_stats["cache_misses"] += 1
	_stats["total_loads"] += 1
	var resource = ResourceLoader.load(path)
	if resource == null:
		print("[ResourceCache] 加载失败: %s" % path)
		return null
	# 加入缓存
	if use_cache:
		_add_to_cache(path, resource)
	resource_loaded.emit(path, resource)
	return resource


func get_resource(path):
	## 获取已缓存的资源（不加载）
	if _resource_cache.has(path):
		var entry = _resource_cache[path]
		entry["last_access"] = Time.get_ticks_msec()
		return entry["resource"]
	return null


func has_resource(path):
	## 检查资源是否已缓存
	return _resource_cache.has(path)


func unload_resource(path):
	## 卸载指定资源
	if _resource_cache.has(path):
		_resource_cache.erase(path)
		_stats["total_unloaded"] += 1
		_stats["current_cache_count"] = _resource_cache.size()
		_update_memory_usage()
		resource_unloaded.emit(path)
		print("[ResourceCache] 卸载资源: %s" % path)
		return true
	return false


func clear_cache(force = false):
	## 清空缓存
	var count = _resource_cache.size()
	_resource_cache.clear()
	_stats["total_unloaded"] += count
	_stats["current_cache_count"] = 0
	_stats["estimated_memory_usage"] = 0
	cache_cleared.emit()
	print("[ResourceCache] 缓存已清空，释放 %d 个资源" % count)


# ==================== 公共API - 预加载队列 ====================

func preload_resource(path, priority = 0, callback = Callable()):
	## 添加资源到预加载队列
	var item = {"path": path, "priority": priority, "callback": callback}
	_preload_queue.append(item)
	# 按优先级排序（数值越大优先级越高）
	_preload_queue.sort_custom(func(a, b): return a["priority"] > b["priority"])
	if not _is_preloading:
		_start_preload()


func preload_resources(paths, priority = 0, callback = Callable()):
	## 批量预加载资源
	for path in paths:
		_preload_queue.append({"path": path, "priority": priority, "callback": callback})
	_preload_queue.sort_custom(func(a, b): return a["priority"] > b["priority"])
	if not _is_preloading:
		_start_preload()


func cancel_preload():
	## 取消预加载
	_is_preloading = false
	_preload_queue.clear()
	_current_preload_index = 0
	_total_preload_count = 0


func get_preload_progress():
	## 获取预加载进度
	if _total_preload_count == 0:
		return 1.0
	return float(_current_preload_index) / float(_total_preload_count)


# ==================== 公共API - 资源分包 ====================

func register_package(package_name, paths):
	## 注册资源分包
	_resource_packages[package_name] = paths
	print("[ResourceCache] 注册资源分包: %s (%d个资源)" % [package_name, paths.size()])


func load_package(package_name, priority = 0):
	## 加载指定资源分包
	if not _resource_packages.has(package_name):
		print("[ResourceCache] 资源分包不存在: %s" % package_name)
		return false
	var paths = _resource_packages[package_name]
	preload_resources(paths, priority)
	print("[ResourceCache] 开始加载资源分包: %s (%d个资源)" % [package_name, paths.size()])
	return true


func unload_package(package_name):
	## 卸载指定资源分包
	if not _resource_packages.has(package_name):
		return false
	var paths = _resource_packages[package_name]
	var count = 0
	for path in paths:
		if unload_resource(path):
			count += 1
	print("[ResourceCache] 卸载资源分包: %s (释放 %d 个资源)" % [package_name, count])
	return true


func get_package_names():
	## 获取所有资源分包名称
	return _resource_packages.keys()


# ==================== 公共API - 统计和监控 ====================

func get_stats():
	## 获取统计信息
	_stats["current_cache_count"] = _resource_cache.size()
	_update_memory_usage()
	return _stats.duplicate()


func get_memory_usage_mb():
	## 获取内存使用量（MB）
	_update_memory_usage()
	return _stats["estimated_memory_usage"] / (1024.0 * 1024.0)


func get_cache_hit_rate():
	## 获取缓存命中率
	var total = _stats["cache_hits"] + _stats["cache_misses"]
	if total == 0:
		return 0.0
	return float(_stats["cache_hits"]) / float(total)


func get_cached_resources():
	## 获取所有已缓存资源路径
	return _resource_cache.keys()


func print_stats():
	## 打印统计信息
	var stats = get_stats()
	print("[ResourceCache] ===== 资源缓存统计 =====")
	print("[ResourceCache] 缓存资源数: %d" % stats["current_cache_count"])
	print("[ResourceCache] 估算内存使用: %.2f MB" % (stats["estimated_memory_usage"] / (1024.0 * 1024.0)))
	print("[ResourceCache] 缓存上限: %.0f MB" % cache_limit_mb)
	print("[ResourceCache] 总加载次数: %d" % stats["total_loads"])
	print("[ResourceCache] 缓存命中: %d" % stats["cache_hits"])
	print("[ResourceCache] 缓存未命中: %d" % stats["cache_misses"])
	print("[ResourceCache] 缓存命中率: %.1f%%" % (get_cache_hit_rate() * 100.0))
	print("[ResourceCache] 总卸载次数: %d" % stats["total_unloaded"])
	print("[ResourceCache] 资源分包数: %d" % _resource_packages.size())
	print("[ResourceCache] ========================")


# ==================== 内部方法 - 缓存管理 ====================

func _add_to_cache(path, resource):
	## 添加资源到缓存
	var resource_type = resource.get_class()
	var size = _estimate_resource_size(resource, resource_type)
	var entry = {
		"resource": resource,
		"last_access": Time.get_ticks_msec(),
		"size": size,
		"type": resource_type
	}
	_resource_cache[path] = entry
	_stats["current_cache_count"] = _resource_cache.size()
	_update_memory_usage()
	# 检查是否超过缓存上限
	if get_memory_usage_mb() > cache_limit_mb:
		memory_limit_exceeded.emit()
		_evict_lru_resources()


func _estimate_resource_size(resource, resource_type):
	## 估算资源大小
	if RESOURCE_SIZE_ESTIMATE.has(resource_type):
		return RESOURCE_SIZE_ESTIMATE[resource_type]
	return RESOURCE_SIZE_ESTIMATE["default"]


func _update_memory_usage():
	## 更新内存使用统计
	var total = 0
	for path in _resource_cache.keys():
		total += _resource_cache[path]["size"]
	_stats["estimated_memory_usage"] = total


# ==================== 内部方法 - LRU淘汰 ====================

func _check_lru_eviction():
	## 检查是否需要LRU淘汰
	if get_memory_usage_mb() > cache_limit_mb:
		_evict_lru_resources()


func _evict_lru_resources():
	## 淘汰最久未使用的资源
	# 按最后访问时间排序
	var sorted_paths = _resource_cache.keys()
	sorted_paths.sort_custom(func(a, b):
		return _resource_cache[a]["last_access"] < _resource_cache[b]["last_access"]
	)
	# 淘汰直到内存使用低于上限的80%
	var target_mb = cache_limit_mb * 0.8
	var evicted = 0
	for path in sorted_paths:
		if get_memory_usage_mb() <= target_mb:
			break
		_resource_cache.erase(path)
		_stats["total_unloaded"] += 1
		evicted += 1
		resource_unloaded.emit(path)
	if evicted > 0:
		_stats["current_cache_count"] = _resource_cache.size()
		_update_memory_usage()
		print("[ResourceCache] LRU淘汰 %d 个资源，当前内存: %.2f MB" % [evicted, get_memory_usage_mb()])


# ==================== 内部方法 - 预加载队列 ====================

func _start_preload():
	## 开始预加载
	_is_preloading = true
	_current_preload_index = 0
	_total_preload_count = _preload_queue.size()
	print("[ResourceCache] 开始预加载队列，共 %d 个资源" % _total_preload_count)


func _process_preload_queue():
	## 处理预加载队列
	if _current_preload_index >= _preload_queue.size():
		_finish_preload()
		return
	var item = _preload_queue[_current_preload_index]
	var path = item["path"]
	# 加载资源（带缓存）
	var resource = load_resource(path, true)
	# 调用回调
	if item["callback"] != Callable() and item["callback"].is_valid():
		item["callback"].call(path, resource)
	# 更新进度
	_current_preload_index += 1
	preload_progress.emit(_current_preload_index, _total_preload_count)
	# 如果队列处理完，结束预加载
	if _current_preload_index >= _preload_queue.size():
		_finish_preload()


func _finish_preload():
	## 完成预加载
	_is_preloading = false
	_preload_queue.clear()
	_current_preload_index = 0
	_total_preload_count = 0
	preload_completed.emit()
	print("[ResourceCache] 预加载队列完成")


# ==================== 内部方法 - 默认资源分包 ====================

func _register_default_packages():
	## 注册默认资源分包
	# UI资源分包
	register_package("ui", [
		"res://scenes/ui/main_menu.tscn",
		"res://scenes/ui/settings_menu.tscn",
		"res://scenes/ui/loading_screen.tscn"
	])
	# 游戏核心资源分包
	register_package("game_core", [
		"res://scenes/main.tscn",
		"res://scenes/entities/player.tscn"
	])
	# 实体资源分包
	register_package("entities", [
		"res://scenes/entities/npc.tscn",
		"res://scenes/entities/zombie.tscn"
	])
	print("[ResourceCache] 默认资源分包注册完成")
