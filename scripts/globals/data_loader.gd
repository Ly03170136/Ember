extends Node

var _data_cache = {}

const DATA_PATHS = {
	"items": "res://data/items/",
	"recipes": "res://data/recipes/recipes.json",
	"buildings": "res://data/buildings/buildings.json",
	"zombies": "res://data/zombies/zombies.json",
	"professions": "res://data/professions/professions.json",
	"tech_tree": "res://data/tech_tree/tech_tree.json",
	"world": "res://data/world/world_config.json",
}

const DIRECTORY_TYPES = ["items"]

const VALIDATION_RULES = {
	"items": {
		"required_fields": ["name", "desc", "type", "max_stack", "weight"],
		"valid_types": ["resource", "tool", "weapon", "food", "medicine", "ammo", "misc"],
		"numeric_fields": {"max_stack": 1, "weight": 0},
		"array_fields": {"color": 3}
	},
	"recipes": {
		"required_fields": ["name", "output", "ingredients"],
		"output_required_fields": ["id", "count"],
		"ingredient_required_fields": ["id", "count"],
		"numeric_fields": {"craft_time": 0}
	},
	"buildings": {
		"required_fields": ["name", "desc", "category", "size", "max_health", "build_materials"],
		"valid_categories": ["basic", "production", "agriculture", "defense", "power", "vehicle", "medical", "storage"],
		"array_fields": {"size": 2},
		"material_required_fields": ["id", "count"],
		"numeric_fields": {"max_health": 1, "build_time": 0}
	}
}

# 校验错误统计
var _validation_errors = []
var _validation_warnings = []

var _file_watchers = {}
var hot_reload_enabled = true  # 已修复，使用文件大小检测变化
var validation_enabled = true

signal data_updated(data_type)
signal all_data_updated()


func _ready():
	print("[DataLoader] Data loader started")
	_load_all_data()
	if hot_reload_enabled:
		_setup_file_watchers()


func _load_all_data():
	# 先加载物品数据（其他数据需要引用物品ID进行完整性检查）
	var load_order = ["items", "recipes", "buildings", "zombies", "professions", "tech_tree", "world"]
	for data_type in load_order:
		if DATA_PATHS.has(data_type):
			_load_data(data_type)
	print("[DataLoader] All data loaded, total %d types" % DATA_PATHS.size())
	# 所有数据加载完成后，输出校验总结
	_print_validation_summary()


func _load_data(data_type):
	if not DATA_PATHS.has(data_type):
		return {}
	var path = DATA_PATHS[data_type]
	var is_directory = DIRECTORY_TYPES.has(data_type)
	var data = {}
	if is_directory:
		data = _load_directory(path)
	else:
		data = _load_single_file(path)
	if validation_enabled and VALIDATION_RULES.has(data_type):
		_validate_data(data_type, data)
	_data_cache[data_type] = data
	print("[DataLoader] Loaded %s: %d records" % [data_type, data.size()])
	return data


func _load_single_file(file_path):
	if not FileAccess.file_exists(file_path):
		return {}
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return {}
	var json_text = file.get_as_text()
	file.close()
	if json_text.is_empty():
		return {}
	var parsed = JSON.parse_string(json_text)
	if parsed == null:
		return {}
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var cleaned_data = {}
	for key in parsed.keys():
		if not key.begins_with("_"):
			cleaned_data[key] = parsed[key]
	return cleaned_data


func _load_directory(dir_path):
	var merged_data = {}
	if not DirAccess.dir_exists_absolute(dir_path):
		return merged_data
	var dir = DirAccess.open(dir_path)
	if not dir:
		return merged_data
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json") and not file_name.begins_with("_"):
			var file_path = dir_path + file_name
			var file_data = _load_single_file(file_path)
			for key in file_data.keys():
				if merged_data.has(key):
					print("[DataLoader] Warning: duplicate item ID '%s' in file %s" % [key, file_name])
				merged_data[key] = file_data[key]
		file_name = dir.get_next()
	dir.list_dir_end()
	return merged_data


func _validate_data(data_type, data):
	## 完善的数据校验
	_validation_errors.clear()
	_validation_warnings.clear()
	
	if data_type == "items":
		_validate_items(data)
	elif data_type == "recipes":
		_validate_recipes(data)
	elif data_type == "buildings":
		_validate_buildings(data)
	
	# 输出校验结果
	if _validation_errors.size() > 0:
		print("[DataLoader] ===== %s 校验错误 (%d个) =====" % [data_type, _validation_errors.size()])
		for err in _validation_errors:
			print("  [ERROR] %s" % err)
	if _validation_warnings.size() > 0:
		print("[DataLoader] ===== %s 校验警告 (%d个) =====" % [data_type, _validation_warnings.size()])
		for warn in _validation_warnings:
			print("  [WARN] %s" % warn)
	if _validation_errors.size() == 0 and _validation_warnings.size() == 0:
		print("[DataLoader] %s validation passed (0 errors, 0 warnings)" % data_type)
	else:
		print("[DataLoader] %s validation: %d errors, %d warnings" % [data_type, _validation_errors.size(), _validation_warnings.size()])


func _add_validation_error(message):
	_validation_errors.append(message)


func _add_validation_warning(message):
	_validation_warnings.append(message)


func _validate_items(data):
	## 校验物品数据
	var rules = VALIDATION_RULES["items"]
	var required_fields = rules["required_fields"]
	var valid_types = rules["valid_types"]
	var numeric_fields = rules["numeric_fields"]
	var array_fields = rules["array_fields"]
	
	for item_id in data.keys():
		var item = data[item_id]
		if typeof(item) != TYPE_DICTIONARY:
			_add_validation_error("物品 '%s' 不是字典类型" % item_id)
			continue
		
		# 检查必填字段
		for field in required_fields:
			if not item.has(field):
				_add_validation_error("物品 '%s' 缺少必填字段 '%s'" % [item_id, field])
		
		# 检查类型有效性
		if item.has("type") and not valid_types.is_empty():
			if not valid_types.has(item["type"]):
				_add_validation_error("物品 '%s' 类型 '%s' 无效，有效值: %s" % [item_id, item["type"], str(valid_types)])
		
		# 检查数值字段
		for field in numeric_fields.keys():
			if item.has(field):
				var value = item[field]
				if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
					_add_validation_error("物品 '%s' 字段 '%s' 应为数值类型，当前为 %s" % [item_id, field, typeof(value)])
				elif value < numeric_fields[field]:
					_add_validation_error("物品 '%s' 字段 '%s' 值 %s 小于最小值 %s" % [item_id, field, str(value), str(numeric_fields[field])])
		
		# 检查数组字段
		for field in array_fields.keys():
			if item.has(field):
				var value = item[field]
				if typeof(value) != TYPE_ARRAY:
					_add_validation_error("物品 '%s' 字段 '%s' 应为数组类型" % [item_id, field])
				elif value.size() != array_fields[field]:
					_add_validation_warning("物品 '%s' 字段 '%s' 数组长度应为 %d，当前为 %d" % [item_id, field, array_fields[field], value.size()])


func _validate_recipes(data):
	## 校验配方数据
	var rules = VALIDATION_RULES["recipes"]
	var required_fields = rules["required_fields"]
	var output_required_fields = rules["output_required_fields"]
	var ingredient_required_fields = rules["ingredient_required_fields"]
	var numeric_fields = rules["numeric_fields"]
	
	# 获取物品列表用于引用完整性检查
	var items = _data_cache.get("items", {})
	
	for recipe_id in data.keys():
		var recipe = data[recipe_id]
		if typeof(recipe) != TYPE_DICTIONARY:
			_add_validation_error("配方 '%s' 不是字典类型" % recipe_id)
			continue
		
		# 检查必填字段
		for field in required_fields:
			if not recipe.has(field):
				_add_validation_error("配方 '%s' 缺少必填字段 '%s'" % [recipe_id, field])
		
		# 检查output格式
		if recipe.has("output"):
			var output = recipe["output"]
			if typeof(output) != TYPE_DICTIONARY:
				_add_validation_error("配方 '%s' output 应为字典类型" % recipe_id)
			else:
				for field in output_required_fields:
					if not output.has(field):
						_add_validation_error("配方 '%s' output 缺少字段 '%s'" % [recipe_id, field])
				# 引用完整性检查：output.id必须存在于物品数据库
				if output.has("id") and not items.is_empty():
					if not items.has(output["id"]):
						_add_validation_error("配方 '%s' output.id '%s' 不存在于物品数据库" % [recipe_id, output["id"]])
				# 检查count数值
				if output.has("count"):
					if typeof(output["count"]) != TYPE_INT or output["count"] <= 0:
						_add_validation_error("配方 '%s' output.count 应为正整数" % recipe_id)
		
		# 检查ingredients格式
		if recipe.has("ingredients"):
			var ingredients = recipe["ingredients"]
			if typeof(ingredients) != TYPE_ARRAY:
				_add_validation_error("配方 '%s' ingredients 应为数组类型" % recipe_id)
			else:
				for i in range(ingredients.size()):
					var ing = ingredients[i]
					if typeof(ing) != TYPE_DICTIONARY:
						_add_validation_error("配方 '%s' ingredients[%d] 应为字典类型" % [recipe_id, i])
					else:
						for field in ingredient_required_fields:
							if not ing.has(field):
								_add_validation_error("配方 '%s' ingredients[%d] 缺少字段 '%s'" % [recipe_id, i, field])
						# 引用完整性检查：ingredient.id必须存在于物品数据库
						if ing.has("id") and not items.is_empty():
							if not items.has(ing["id"]):
								_add_validation_error("配方 '%s' ingredients[%d].id '%s' 不存在于物品数据库" % [recipe_id, i, ing["id"]])
						# 检查count数值
						if ing.has("count"):
							if typeof(ing["count"]) != TYPE_INT or ing["count"] <= 0:
								_add_validation_error("配方 '%s' ingredients[%d].count 应为正整数" % [recipe_id, i])
		
		# 检查数值字段
		for field in numeric_fields.keys():
			if recipe.has(field):
				var value = recipe[field]
				if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
					_add_validation_error("配方 '%s' 字段 '%s' 应为数值类型" % [recipe_id, field])
				elif value < numeric_fields[field]:
					_add_validation_error("配方 '%s' 字段 '%s' 值 %s 小于最小值 %s" % [recipe_id, field, str(value), str(numeric_fields[field])])


func _validate_buildings(data):
	## 校验建筑数据
	var rules = VALIDATION_RULES["buildings"]
	var required_fields = rules["required_fields"]
	var valid_categories = rules["valid_categories"]
	var array_fields = rules["array_fields"]
	var material_required_fields = rules["material_required_fields"]
	var numeric_fields = rules["numeric_fields"]
	
	# 获取物品列表用于引用完整性检查
	var items = _data_cache.get("items", {})
	
	for building_id in data.keys():
		var building = data[building_id]
		if typeof(building) != TYPE_DICTIONARY:
			_add_validation_error("建筑 '%s' 不是字典类型" % building_id)
			continue
		
		# 检查必填字段
		for field in required_fields:
			if not building.has(field):
				_add_validation_error("建筑 '%s' 缺少必填字段 '%s'" % [building_id, field])
		
		# 检查类别有效性
		if building.has("category") and not valid_categories.is_empty():
			if not valid_categories.has(building["category"]):
				_add_validation_warning("建筑 '%s' 类别 '%s' 不在标准类别列表中" % [building_id, building["category"]])
		
		# 检查数组字段（如size）
		for field in array_fields.keys():
			if building.has(field):
				var value = building[field]
				if typeof(value) != TYPE_ARRAY:
					_add_validation_error("建筑 '%s' 字段 '%s' 应为数组类型" % [building_id, field])
				elif value.size() != array_fields[field]:
					_add_validation_error("建筑 '%s' 字段 '%s' 数组长度应为 %d，当前为 %d" % [building_id, field, array_fields[field], value.size()])
		
		# 检查build_materials格式
		if building.has("build_materials"):
			var materials = building["build_materials"]
			if typeof(materials) != TYPE_ARRAY:
				_add_validation_error("建筑 '%s' build_materials 应为数组类型" % building_id)
			else:
				for i in range(materials.size()):
					var mat = materials[i]
					if typeof(mat) != TYPE_DICTIONARY:
						_add_validation_error("建筑 '%s' build_materials[%d] 应为字典类型" % [building_id, i])
					else:
						for field in material_required_fields:
							if not mat.has(field):
								_add_validation_error("建筑 '%s' build_materials[%d] 缺少字段 '%s'" % [building_id, i, field])
						# 引用完整性检查：material.id必须存在于物品数据库
						if mat.has("id") and not items.is_empty():
							if not items.has(mat["id"]):
								_add_validation_error("建筑 '%s' build_materials[%d].id '%s' 不存在于物品数据库" % [building_id, i, mat["id"]])
						# 检查count数值
						if mat.has("count"):
							if typeof(mat["count"]) != TYPE_INT or mat["count"] <= 0:
								_add_validation_error("建筑 '%s' build_materials[%d].count 应为正整数" % [building_id, i])
		
		# 检查数值字段
		for field in numeric_fields.keys():
			if building.has(field):
				var value = building[field]
				if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
					_add_validation_error("建筑 '%s' 字段 '%s' 应为数值类型" % [building_id, field])
				elif value < numeric_fields[field]:
					_add_validation_error("建筑 '%s' 字段 '%s' 值 %s 小于最小值 %s" % [building_id, field, str(value), str(numeric_fields[field])])


func get_validation_errors():
	## 获取校验错误列表
	return _validation_errors.duplicate()


func get_validation_warnings():
	## 获取校验警告列表
	return _validation_warnings.duplicate()


func has_validation_errors():
	## 是否有校验错误
	return _validation_errors.size() > 0


func validate_all_data():
	## 重新校验所有数据
	for data_type in DATA_PATHS.keys():
		if _data_cache.has(data_type) and VALIDATION_RULES.has(data_type):
			_validate_data(data_type, _data_cache[data_type])
	return not has_validation_errors()


func _print_validation_summary():
	## 输出校验总结
	var total_errors = 0
	var total_warnings = 0
	var validated_types = []
	for data_type in DATA_PATHS.keys():
		if VALIDATION_RULES.has(data_type):
			validated_types.append(data_type)
	print("[DataLoader] ===== 数据校验总结 =====")
	print("[DataLoader] 已校验数据类型: %s" % str(validated_types))
	print("[DataLoader] 物品数量: %d" % _data_cache.get("items", {}).size())
	print("[DataLoader] 配方数量: %d" % _data_cache.get("recipes", {}).size())
	print("[DataLoader] 建筑数量: %d" % _data_cache.get("buildings", {}).size())
	print("[DataLoader] 校验完成！")


func get_data(data_type):
	if not _data_cache.has(data_type):
		return _load_data(data_type)
	return _data_cache[data_type]


func get_item(item_id):
	var items = get_data("items")
	if items.has(item_id):
		return items[item_id]
	return {}


func get_recipe(recipe_id):
	var recipes = get_data("recipes")
	if recipes.has(recipe_id):
		return recipes[recipe_id]
	return {}


func get_building(building_id):
	var buildings = get_data("buildings")
	if buildings.has(building_id):
		return buildings[building_id]
	return {}


func get_zombie(zombie_type):
	var zombies = get_data("zombies")
	if zombies.has(zombie_type):
		return zombies[zombie_type]
	return {}


func get_profession(profession_id):
	var professions = get_data("professions")
	if professions.has(profession_id):
		return professions[profession_id]
	return {}


func get_tech_node(node_id):
	var tech_tree = get_data("tech_tree")
	if tech_tree.has("nodes") and tech_tree["nodes"].has(node_id):
		return tech_tree["nodes"][node_id]
	return {}


func get_world_config():
	return get_data("world")


func reload_data(data_type):
	print("[DataLoader] Hot reload: " + data_type)
	_load_data(data_type)
	emit_signal("data_updated", data_type)


func reload_all():
	print("[DataLoader] Hot reload all data")
	_load_all_data()
	emit_signal("all_data_updated")


func _setup_file_watchers():
	for data_type in DATA_PATHS.keys():
		var path = DATA_PATHS[data_type]
		var is_directory = DIRECTORY_TYPES.has(data_type)
		if is_directory:
			if DirAccess.dir_exists_absolute(path):
				_file_watchers[data_type] = {
					"path": path,
					"files_modified": _get_directory_files_modified(path)
				}
		else:
			if FileAccess.file_exists(path):
				_file_watchers[data_type] = {
					"path": path,
					"last_modified": _get_file_modified_time(path)
				}
	var timer = Timer.new()
	timer.wait_time = 2.0
	timer.timeout.connect(_check_file_changes)
	add_child(timer)
	timer.start()
	print("[DataLoader] File watchers started")


func _get_directory_files_modified(dir_path):
	var files_modified = {}
	if not DirAccess.dir_exists_absolute(dir_path):
		return files_modified
	var dir = DirAccess.open(dir_path)
	if not dir:
		return files_modified
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json") and not file_name.begins_with("_"):
			files_modified[file_name] = _get_file_modified_time(dir_path + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	return files_modified


func _get_file_modified_time(file_path):
	# 使用文件大小作为变化检测（更稳定，不依赖get_file_info API）
	if not FileAccess.file_exists(file_path):
		return 0
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return 0
	var size = file.get_length()
	file.close()
	return size


func _check_file_changes():
	if not hot_reload_enabled:
		return
	for data_type in _file_watchers.keys():
		var watcher = _file_watchers[data_type]
		var is_directory = DIRECTORY_TYPES.has(data_type)
		var changed = false
		if is_directory:
			var current_files = _get_directory_files_modified(watcher["path"])
			var last_files = watcher["files_modified"]
			if current_files.size() != last_files.size():
				changed = true
			else:
				for file_name in current_files.keys():
					if not last_files.has(file_name) or current_files[file_name] != last_files[file_name]:
						changed = true
						break
			if changed:
				watcher["files_modified"] = current_files
		else:
			var current_modified = _get_file_modified_time(watcher["path"])
			if current_modified != 0 and current_modified != watcher["last_modified"]:
				changed = true
				watcher["last_modified"] = current_modified
		if changed:
			print("[DataLoader] File changed, hot reload: " + data_type)
			reload_data(data_type)
