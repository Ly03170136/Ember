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

# ?????????
var _validation_errors = []
var _validation_warnings = []

var _file_watchers = {}
var hot_reload_enabled = true  # ??????????????????????
var validation_enabled = true

signal data_updated(data_type)
signal all_data_updated()


func _ready():
	print("[DataLoader] Data loader started")
	_load_all_data()
	if hot_reload_enabled:
		_setup_file_watchers()


func _load_all_data():
	# ????????????????????????????D????????????
	var load_order = ["items", "recipes", "buildings", "zombies", "professions", "tech_tree", "world"]
	for data_type in load_order:
		if DATA_PATHS.has(data_type):
			_load_data(data_type)
	print("[DataLoader] All data loaded, total %d types" % DATA_PATHS.size())
	# ?????????????????????????
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
	# ???????????
	_validation_errors.clear()
	_validation_warnings.clear()
	
	if data_type == "items":
		_validate_items(data)
	elif data_type == "recipes":
		_validate_recipes(data)
	elif data_type == "buildings":
		_validate_buildings(data)
	
	# ?????????
	if _validation_errors.size() > 0:
		print("[DataLoader] ===== %s ?????? (%d?) =====" % [data_type, _validation_errors.size()])
		for err in _validation_errors:
			print("  [ERROR] %s" % err)
	if _validation_warnings.size() > 0:
		print("[DataLoader] ===== %s ?????? (%d?) =====" % [data_type, _validation_warnings.size()])
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


func _is_positive_integer(value):
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	if value <= 0:
		return false
	if typeof(value) == TYPE_FLOAT:
		if value != floor(value):
			return false
	return true


func _validate_items(data):
	# ?????????
	var rules = VALIDATION_RULES["items"]
	var required_fields = rules["required_fields"]
	var valid_types = rules["valid_types"]
	var numeric_fields = rules["numeric_fields"]
	var array_fields = rules["array_fields"]
	
	for item_id in data.keys():
		var item = data[item_id]
		if typeof(item) != TYPE_DICTIONARY:
			_add_validation_error("??? '%s' ?????????" % item_id)
			continue
		
		# ??????????
		for field in required_fields:
			if not item.has(field):
				_add_validation_error("??? '%s' ????????? '%s'" % [item_id, field])
		
		# ????????????
		if item.has("type") and not valid_types.is_empty():
			if not valid_types.has(item["type"]):
				_add_validation_error("??? '%s' ??? '%s' ?????????? %s" % [item_id, item["type"], str(valid_types)])
		
		# ??????????
		for field in numeric_fields.keys():
			if item.has(field):
				var value = item[field]
				if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
					_add_validation_error("??? '%s' ??? '%s' ????????????????%s" % [item_id, field, typeof(value)])
				elif value < numeric_fields[field]:
					_add_validation_error("??? '%s' ??? '%s' ??%s ?????????%s" % [item_id, field, str(value), str(numeric_fields[field])])
		
		# ??????????
		for field in array_fields.keys():
			if item.has(field):
				var value = item[field]
				if typeof(value) != TYPE_ARRAY:
					_add_validation_error("??? '%s' ??? '%s' ?????????" % [item_id, field])
				elif value.size() != array_fields[field]:
					_add_validation_warning("??? '%s' ??? '%s' ????????? %d?????? %d" % [item_id, field, array_fields[field], value.size()])


func _validate_recipes(data):
	# ?????????
	var rules = VALIDATION_RULES["recipes"]
	var required_fields = rules["required_fields"]
	var output_required_fields = rules["output_required_fields"]
	var ingredient_required_fields = rules["ingredient_required_fields"]
	var numeric_fields = rules["numeric_fields"]
	
	# ???????????????????????
	var items = _data_cache.get("items", {})
	
	for recipe_id in data.keys():
		var recipe = data[recipe_id]
		if typeof(recipe) != TYPE_DICTIONARY:
			_add_validation_error("??? '%s' ?????????" % recipe_id)
			continue
		
		# ??????????
		for field in required_fields:
			if not recipe.has(field):
				_add_validation_error("??? '%s' ????????? '%s'" % [recipe_id, field])
		
		# ????utput???
		if recipe.has("output"):
			var output = recipe["output"]
			if typeof(output) != TYPE_DICTIONARY:
				_add_validation_error("??? '%s' output ?????????" % recipe_id)
			else:
				for field in output_required_fields:
					if not output.has(field):
						_add_validation_error("??? '%s' output ?????? '%s'" % [recipe_id, field])
				# ????????????output.id???????????????
				if output.has("id") and not items.is_empty():
					if not items.has(output["id"]):
						_add_validation_error("??? '%s' output.id '%s' ??????????????" % [recipe_id, output["id"]])
				# ????ount????
				if output.has("count"):
					if not _is_positive_integer(output["count"]):
						_add_validation_error("??? '%s' output.count ????????" % recipe_id)
		
		# ????ngredients???
		if recipe.has("ingredients"):
			var ingredients = recipe["ingredients"]
			if typeof(ingredients) != TYPE_ARRAY:
				_add_validation_error("??? '%s' ingredients ?????????" % recipe_id)
			else:
				for i in range(ingredients.size()):
					var ing = ingredients[i]
					if typeof(ing) != TYPE_DICTIONARY:
						_add_validation_error("??? '%s' ingredients[%d] ?????????" % [recipe_id, i])
					else:
						for field in ingredient_required_fields:
							if not ing.has(field):
								_add_validation_error("??? '%s' ingredients[%d] ?????? '%s'" % [recipe_id, i, field])
						# ????????????ingredient.id???????????????
						if ing.has("id") and not items.is_empty():
							if not items.has(ing["id"]):
								_add_validation_error("??? '%s' ingredients[%d].id '%s' ??????????????" % [recipe_id, i, ing["id"]])
						# ????ount????
						if ing.has("count"):
							if not _is_positive_integer(ing["count"]):
								_add_validation_error("??? '%s' ingredients[%d].count ????????" % [recipe_id, i])
		
		# ??????????
		for field in numeric_fields.keys():
			if recipe.has(field):
				var value = recipe[field]
				if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
					_add_validation_error("??? '%s' ??? '%s' ??????????" % [recipe_id, field])
				elif value < numeric_fields[field]:
					_add_validation_error("??? '%s' ??? '%s' ??%s ?????????%s" % [recipe_id, field, str(value), str(numeric_fields[field])])


func _validate_buildings(data):
	# ?????????
	var rules = VALIDATION_RULES["buildings"]
	var required_fields = rules["required_fields"]
	var valid_categories = rules["valid_categories"]
	var array_fields = rules["array_fields"]
	var material_required_fields = rules["material_required_fields"]
	var numeric_fields = rules["numeric_fields"]
	
	# ???????????????????????
	var items = _data_cache.get("items", {})
	
	for building_id in data.keys():
		var building = data[building_id]
		if typeof(building) != TYPE_DICTIONARY:
			_add_validation_error("??? '%s' ?????????" % building_id)
			continue
		
		# ??????????
		for field in required_fields:
			if not building.has(field):
				_add_validation_error("??? '%s' ????????? '%s'" % [building_id, field])
		
		# ????????????
		if building.has("category") and not valid_categories.is_empty():
			if not valid_categories.has(building["category"]):
				_add_validation_warning("??? '%s' ??? '%s' ??????????????" % [building_id, building["category"]])
		
		# ?????????????ize??
		for field in array_fields.keys():
			if building.has(field):
				var value = building[field]
				if typeof(value) != TYPE_ARRAY:
					_add_validation_error("??? '%s' ??? '%s' ?????????" % [building_id, field])
				elif value.size() != array_fields[field]:
					_add_validation_error("??? '%s' ??? '%s' ????????? %d?????? %d" % [building_id, field, array_fields[field], value.size()])
		
		# ????uild_materials???
		if building.has("build_materials"):
			var materials = building["build_materials"]
			if typeof(materials) != TYPE_ARRAY:
				_add_validation_error("??? '%s' build_materials ?????????" % building_id)
			else:
				for i in range(materials.size()):
					var mat = materials[i]
					if typeof(mat) != TYPE_DICTIONARY:
						_add_validation_error("??? '%s' build_materials[%d] ?????????" % [building_id, i])
					else:
						for field in material_required_fields:
							if not mat.has(field):
								_add_validation_error("??? '%s' build_materials[%d] ?????? '%s'" % [building_id, i, field])
						# ????????????material.id???????????????
						if mat.has("id") and not items.is_empty():
							if not items.has(mat["id"]):
								_add_validation_error("??? '%s' build_materials[%d].id '%s' ??????????????" % [building_id, i, mat["id"]])
						# ????ount????
						if mat.has("count"):
							if not _is_positive_integer(mat["count"]):
								_add_validation_error("??? '%s' build_materials[%d].count ????????" % [building_id, i])
		
		# ??????????
		for field in numeric_fields.keys():
			if building.has(field):
				var value = building[field]
				if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
					_add_validation_error("??? '%s' ??? '%s' ??????????" % [building_id, field])
				elif value < numeric_fields[field]:
					_add_validation_error("??? '%s' ??? '%s' ??%s ?????????%s" % [building_id, field, str(value), str(numeric_fields[field])])


func get_validation_errors():
	# ????????????
	return _validation_errors.duplicate()


func get_validation_warnings():
	# ????????????
	return _validation_warnings.duplicate()


func has_validation_errors():
	# ???????????
	return _validation_errors.size() > 0


func validate_all_data():
	# ?????????????
	for data_type in DATA_PATHS.keys():
		if _data_cache.has(data_type) and VALIDATION_RULES.has(data_type):
			_validate_data(data_type, _data_cache[data_type])
	return not has_validation_errors()


func _print_validation_summary():
	# ?????????
	var total_errors = 0
	var total_warnings = 0
	var validated_types = []
	for data_type in DATA_PATHS.keys():
		if VALIDATION_RULES.has(data_type):
			validated_types.append(data_type)
	print("[DataLoader] ===== ????????? =====")
	print("[DataLoader] ??????????? %s" % str(validated_types))
	print("[DataLoader] ??????: %d" % _data_cache.get("items", {}).size())
	print("[DataLoader] ??????: %d" % _data_cache.get("recipes", {}).size())
	print("[DataLoader] ??????: %d" % _data_cache.get("buildings", {}).size())
	print("[DataLoader] ????????")


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
	# ???????????????????????????????et_file_info API??
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
