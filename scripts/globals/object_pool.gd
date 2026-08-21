extends Node

var _pools = {}
const LOG_TAG = "[ObjectPool]"


func _ready():
	print(LOG_TAG, " 对象池系统已启动")


func init_pool(scene_path, count, pool_name, auto_expand = true):
	if pool_name in _pools:
		print(LOG_TAG, " 池 '", pool_name, "' 已存在，跳过")
		return
	var scene = load(scene_path)
	if scene == null:
		print(LOG_TAG, " 错误：无法加载场景 ", scene_path)
		return
	var pool = {
		"scene": scene,
		"available": [],
		"in_use": [],
		"auto_expand": auto_expand,
		"scene_path": scene_path
	}
	for i in range(count):
		var obj = scene.instantiate()
		obj.name = pool_name + "_" + str(i)
		obj.visible = false
		obj.set_process(false)
		obj.set_physics_process(false)
		pool["available"].append(obj)
	_pools[pool_name] = pool
	print(LOG_TAG, " 初始化池 '", pool_name, "' 完成，数量：", count)


func acquire(pool_name):
	if not (pool_name in _pools):
		print(LOG_TAG, " 错误：池 '", pool_name, "' 不存在")
		return null
	var pool = _pools[pool_name]
	if pool["available"].is_empty():
		if pool["auto_expand"]:
			var expand_count = max(int(pool["in_use"].size() * 0.5), 5)
			print(LOG_TAG, " 池 '", pool_name, "' 不足，自动扩容 ", expand_count)
			for i in range(expand_count):
				var obj = pool["scene"].instantiate()
				obj.name = pool_name + "_exp_" + str(Time.get_ticks_msec()) + "_" + str(i)
				obj.visible = false
				obj.set_process(false)
				obj.set_physics_process(false)
				pool["available"].append(obj)
		else:
			print(LOG_TAG, " 警告：池 '", pool_name, "' 已用尽")
			return null
	var obj = pool["available"].pop_back()
	obj.visible = true
	obj.set_process(true)
	obj.set_physics_process(true)
	pool["in_use"].append(obj)
	return obj


func recycle(pool_name, obj, reset_position = true):
	if not (pool_name in _pools):
		print(LOG_TAG, " 错误：池 '", pool_name, "' 不存在，销毁对象")
		obj.queue_free()
		return
	var pool = _pools[pool_name]
	if obj in pool["in_use"]:
		pool["in_use"].erase(obj)
	obj.visible = false
	obj.set_process(false)
	obj.set_physics_process(false)
	if reset_position and obj is Node2D:
		obj.position = Vector2.ZERO
	if obj.get_parent():
		obj.get_parent().remove_child(obj)
	pool["available"].append(obj)


func clear_pool(pool_name):
	if not (pool_name in _pools):
		return
	var pool = _pools[pool_name]
	for obj in pool["available"]:
		if obj and is_instance_valid(obj):
			obj.queue_free()
	for obj in pool["in_use"]:
		if obj and is_instance_valid(obj):
			obj.queue_free()
	_pools.erase(pool_name)
	print(LOG_TAG, " 池 '", pool_name, "' 已清空")


func clear_all_pools():
	for pool_name in _pools.keys():
		clear_pool(pool_name)
	print(LOG_TAG, " 所有池已清空")


func get_pool_info(pool_name):
	if not (pool_name in _pools):
		return null
	var pool = _pools[pool_name]
	return {
		"total": pool["available"].size() + pool["in_use"].size(),
		"available": pool["available"].size(),
		"in_use": pool["in_use"].size(),
		"auto_expand": pool["auto_expand"],
		"scene_path": pool["scene_path"]
	}


func get_all_pool_info():
	var result = {}
	for pool_name in _pools.keys():
		result[pool_name] = get_pool_info(pool_name)
	return result


func print_stats():
	print(LOG_TAG, " ===== 对象池统计 =====")
	if _pools.is_empty():
		print(LOG_TAG, " （无池）")
		return
	for pool_name in _pools.keys():
		var info = get_pool_info(pool_name)
		print(LOG_TAG, " [", pool_name, "] 总数:", info["total"],
			" 可用:", info["available"],
			" 使用中:", info["in_use"])
	print(LOG_TAG, " =====================")
