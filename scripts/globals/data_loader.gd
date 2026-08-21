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
		"valid_types": ["resource", "tool", "weapon", "food", "medicine", "ammo", "misc"]
	}
}

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
	for data_type in DATA_PATHS.keys():
		_load_data(data_type)
	print("[DataLoader] All data loaded, total %d types" % DATA_PATHS.size())


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
	var rules = VALIDATION_RULES[data_type]
	var required_fields = []
	if rules.has("required_fields"):
		required_fields = rules["required_fields"]
	var valid_types = []
	if rules.has("valid_types"):
		valid_types = rules["valid_types"]
	var error_count = 0
	for item_id in data.keys():
		var item = data[item_id]
		for field in required_fields:
			if not item.has(field):
				print("[DataLoader] Validation: %s '%s' missing field '%s'" % [data_type, item_id, field])
				error_count += 1
		if not valid_types.is_empty() and item.has("type"):
			if not valid_types.has(item["type"]):
				print("[DataLoader] Validation: %s '%s' invalid type '%s'" % [data_type, item_id, item["type"]])
				error_count += 1
	if error_count > 0:
		print("[DataLoader] %s validation: %d issues found" % [data_type, error_count])
	else:
		print("[DataLoader] %s validation passed" % data_type)


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
