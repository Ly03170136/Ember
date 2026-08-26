extends Node
## MOD加载器：扫描mods目录，加载JSON格式的MOD内容
## 自动加载为全局单例，通过 ModLoader 访问

# MOD根目录
const MODS_DIR := "res://mods/"

# 已加载的MOD列表
var loaded_mods := {}

# 加载统计
var stats := {
	"items": 0,
	"buildings": 0,
	"recipes": 0,
	"public_techs": 0,
	"class_techs": 0,
	"books": 0,
}


func _ready() -> void:
	print("[ModLoader] MOD加载器已启动")
	load_all_mods()


## 加载所有MOD
func load_all_mods() -> void:
	var dir := DirAccess.open(MODS_DIR)
	if dir == null:
		print("[ModLoader] mods目录不存在，跳过MOD加载")
		return
	
	var dirs := dir.get_directories()
	if dirs.is_empty():
		print("[ModLoader] mods目录为空，跳过MOD加载")
		return
	
	for mod_name in dirs:
		var mod_path := MODS_DIR + mod_name + "/"
		var mod_json_path := mod_path + "mod.json"
		if FileAccess.file_exists(mod_json_path):
			load_mod(mod_name, mod_path)
		else:
			print("[ModLoader] 跳过目录 %s（缺少mod.json）" % mod_name)
	
	print("[ModLoader] MOD加载完成：共加载 %d 个MOD" % loaded_mods.size())
	print("[ModLoader] 加载统计：物品 %d, 建筑 %d, 配方 %d, 科技 %d" % [
		stats.items, stats.buildings, stats.recipes,
		stats.public_techs + stats.class_techs
	])


## 加载单个MOD
func load_mod(mod_id: String, mod_path: String) -> bool:
	var mod_json_path := mod_path + "mod.json"
	var mod_info := _load_json_file(mod_json_path)
	if mod_info.is_empty():
		push_error("[ModLoader] 无法加载MOD: %s（mod.json为空或格式错误）" % mod_id)
		return false
	
	if mod_info.get("enabled", true) == false:
		print("[ModLoader] MOD已禁用: %s" % mod_id)
		return false
	
	mod_info["_path"] = mod_path
	mod_info["_id"] = mod_id
	loaded_mods[mod_id] = mod_info
	
	var mod_name = mod_info.get("name", mod_id)
	var mod_version = mod_info.get("version", "1.0.0")
	var mod_author = mod_info.get("author", "未知")
	print("[ModLoader] 正在加载MOD: %s v%s (作者: %s)" % [mod_name, mod_version, mod_author])
	
	var items_path := mod_path + "items.json"
	if FileAccess.file_exists(items_path):
		_load_mod_items(items_path)
	
	var buildings_path := mod_path + "buildings.json"
	if FileAccess.file_exists(buildings_path):
		_load_mod_buildings(buildings_path)
	
	var recipes_path := mod_path + "recipes.json"
	if FileAccess.file_exists(recipes_path):
		_load_mod_recipes(recipes_path)
	
	var tech_path := mod_path + "tech_tree.json"
	if FileAccess.file_exists(tech_path):
		_load_mod_tech_tree(tech_path)
	
	print("[ModLoader] MOD加载完成: %s" % mod_name)
	return true


## 加载MOD物品
func _load_mod_items(file_path: String) -> void:
	var data := _load_json_file(file_path)
	if data.is_empty():
		return
	
	var count := 0
	for item_id in data.keys():
		if item_id.begins_with("_"):
			continue
		var item_data = data[item_id]
		if item_data is Dictionary:
			ItemDB.register_item(item_id, item_data)
			count += 1
	
	stats.items += count
	print("[ModLoader]   加载物品: %d 个" % count)


## 加载MOD建筑
func _load_mod_buildings(file_path: String) -> void:
	var data := _load_json_file(file_path)
	if data.is_empty():
		return
	
	var count := 0
	for building_id in data.keys():
		if building_id.begins_with("_"):
			continue
		var building_data = data[building_id]
		if building_data is Dictionary:
			BuildingDB.register_building(building_id, building_data)
			count += 1
	
	stats.buildings += count
	print("[ModLoader]   加载建筑: %d 个" % count)


## 加载MOD配方
func _load_mod_recipes(file_path: String) -> void:
	var data := _load_json_file(file_path)
	if data.is_empty():
		return
	
	var count := 0
	for recipe_id in data.keys():
		if recipe_id.begins_with("_"):
			continue
		var recipe_data = data[recipe_id]
		if recipe_data is Dictionary:
			RecipeDB.register_recipe(recipe_id, recipe_data)
			count += 1
	
	stats.recipes += count
	print("[ModLoader]   加载配方: %d 个" % count)


## 加载MOD科技树
func _load_mod_tech_tree(file_path: String) -> void:
	var data := _load_json_file(file_path)
	if data.is_empty():
		return
	
	if data.has("public_techs"):
		var public_techs = data["public_techs"]
		if public_techs is Dictionary:
			var count := 0
			for tech_id in public_techs.keys():
				TechTree.register_public_tech(tech_id, public_techs[tech_id])
				count += 1
			stats.public_techs += count
			print("[ModLoader]   加载公共科技: %d 个" % count)
	
	if data.has("class_techs"):
		var class_techs = data["class_techs"]
		if class_techs is Dictionary:
			var count := 0
			for class_id in class_techs.keys():
				var techs = class_techs[class_id]
				if techs is Dictionary:
					for tech_id in techs.keys():
						TechTree.register_class_tech(class_id, tech_id, techs[tech_id])
						count += 1
			stats.class_techs += count
			print("[ModLoader]   加载职业科技: %d 个" % count)
	
	if data.has("books"):
		var books = data["books"]
		if books is Dictionary:
			var count := 0
			for book_id in books.keys():
				TechTree.register_book(book_id, books[book_id])
				count += 1
			stats.books += count
			print("[ModLoader]   加载书籍: %d 个" % count)


## 加载JSON文件
func _load_json_file(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {}
	
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("[ModLoader] 无法打开文件: " + file_path)
		return {}
	
	var content := file.get_as_text()
	file.close()
	
	var data = JSON.parse_string(content)
	if data is Dictionary:
		return data
	return {}


## 获取已加载的MOD列表
func get_loaded_mods() -> Dictionary:
	return loaded_mods.duplicate()


## 检查MOD是否已加载
func is_mod_loaded(mod_id: String) -> bool:
	return loaded_mods.has(mod_id)


## 获取MOD信息
func get_mod_info(mod_id: String) -> Dictionary:
	return loaded_mods.get(mod_id, {})


## 获取加载统计
func get_stats() -> Dictionary:
	return stats.duplicate()


## 重新加载所有MOD
func reload_all_mods() -> void:
	print("[ModLoader] 重新加载所有MOD...")
	loaded_mods.clear()
	stats = {"items": 0, "buildings": 0, "recipes": 0, "public_techs": 0, "class_techs": 0, "books": 0}
	load_all_mods()
