## 存档管理器：处理游戏存档和读档
## 使用 JSON 文件存储，支持3个存档位

extends Node

const SAVE_DIR := "user://saves"
const MAX_SAVE_SLOTS := 3

# 存档数据结构
var current_slot: int = 0


func _ready() -> void:
	# 确保存档目录存在
	var dir := DirAccess.open(SAVE_DIR)
	if dir:
		if not dir.dir_exists("."):
			dir.make_dir_recursive(".")
			print("[Save] 创建存档目录")
	else:
		print("[Save] 无法打开存档目录")


func save_game(slot: int, world: Node) -> bool:
	## 保存游戏到指定存档位
	if slot < 0 or slot >= MAX_SAVE_SLOTS:
		return false
	current_slot = slot
	var save_data: Dictionary = {
		"version": 1,
		"timestamp": Time.get_datetime_string_from_system(),
		"world": _get_world_data(world),
		"players": _get_players_data(),
		"buildings": _get_buildings_data(world),
		"resources": _get_resources_data(world)
	}
	# 写入文件
	var file_path: String = "%s/save_%d.json" % [SAVE_DIR, slot]
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		print("[Save] 无法打开存档文件：", file_path)
		return false
	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()
	print("[Save] 游戏已保存到存档位 %d" % slot)
	return true


func load_game(slot: int) -> Dictionary:
	## 从指定存档位读取游戏数据
	if slot < 0 or slot >= MAX_SAVE_SLOTS:
		return {}
	var file_path: String = "%s/save_%d.json" % [SAVE_DIR, slot]
	if not FileAccess.file_exists(file_path):
		print("[Save] 存档文件不存在：", file_path)
		return {}
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("[Save] 无法打开存档文件：", file_path)
		return {}
	var json_text: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	var parse_result: int = json.parse(json_text)
	if parse_result != OK:
		print("[Save] 存档文件解析失败：", json.get_error_message())
		return {}
	current_slot = slot
	print("[Save] 从存档位 %d 读取游戏数据" % slot)
	return json.data


func get_save_info(slot: int) -> Dictionary:
	## 获取存档信息（不加载完整数据）
	if slot < 0 or slot >= MAX_SAVE_SLOTS:
		return {}
	var file_path: String = "%s/save_%d.json" % [SAVE_DIR, slot]
	if not FileAccess.file_exists(file_path):
		return {"exists": false}
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return {"exists": false}
	var json_text: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(json_text) != OK:
		return {"exists": false}
	var data: Dictionary = json.data
	return {
		"exists": true,
		"timestamp": data.get("timestamp", "未知"),
		"day": data.get("world", {}).get("day_count", 0),
		"season": data.get("world", {}).get("season", "spring")
	}


func delete_save(slot: int) -> bool:
	## 删除指定存档
	if slot < 0 or slot >= MAX_SAVE_SLOTS:
		return false
	var file_path: String = "%s/save_%d.json" % [SAVE_DIR, slot]
	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(file_path)
		print("[Save] 已删除存档位 %d" % slot)
		return true
	return false


# ==================== 数据收集函数 ====================
func _get_world_data(world: Node) -> Dictionary:
	var data: Dictionary = {}
	if world and world.has_method("get_save_data"):
		data = world.get_save_data()
	else:
		# 手动收集
		data = {
			"day_count": world.day_count if "day_count" in world else 1,
			"current_time": world.current_time if "current_time" in world else 0.35,
			"season": world.season if "season" in world else "spring",
			"weather": world.weather if "weather" in world else "clear"
		}
	return data


func _get_players_data() -> Array:
	var data: Array = []
	for pid: int in GameManager.players.keys():
		var p: Node = GameManager.players[pid]
		if is_instance_valid(p):
			var player_data: Dictionary = {
				"id": pid,
				"name": p.player_name if "player_name" in p else "Player",
				"class": p.player_class if "player_class" in p else "survivor",
				"position": {"x": p.position.x, "y": p.position.y},
				"health": p.health if "health" in p else 100,
				"hunger": p.hunger if "hunger" in p else 100,
				"thirst": p.thirst if "thirst" in p else 100,
				"stamina": p.stamina if "stamina" in p else 100,
				"level": p.level if "level" in p else 1,
				"experience": p.experience if "experience" in p else 0,
				"inventory": p.inventory.get_inventory_data() if p.inventory else []
			}
			data.append(player_data)
	return data


func _get_buildings_data(world: Node) -> Array:
	var data: Array = []
	if not world or not world.has_node("WorldLayer"):
		return data
	var world_layer: Node = world.get_node("WorldLayer")
	for child in world_layer.get_children():
		if child.is_in_group("building") or child.name.begins_with("Building"):
			var building_data: Dictionary = {
				"id": child.building_id if "building_id" in child else "",
				"position": {"x": child.position.x, "y": child.position.y},
				"level": child.level if "level" in child else 1,
				"health": child.health if "health" in child else 100,
				"is_built": child.is_built if "is_built" in child else true
			}
			data.append(building_data)
	return data


func _get_resources_data(world: Node) -> Array:
	var data: Array = []
	if not world or not world.has_node("WorldLayer"):
		return data
	var world_layer: Node = world.get_node("WorldLayer")
	for child in world_layer.get_children():
		if child.is_in_group("resource") or child.name.begins_with("Tree") or child.name.begins_with("Rock") or child.name.begins_with("Berry"):
			var resource_data: Dictionary = {
				"type": child.name,
				"position": {"x": child.position.x, "y": child.position.y},
				"health": child.health if "health" in child else 100
			}
			data.append(resource_data)
	return data
