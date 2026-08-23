extends Node
## 通用智能资源生成器
## 支持树木、石头、浆果、NPC 等多种资源类型
## 每种资源可独立配置区域、密度、最小间距、禁止区域

# ==================== 资源类型配置 ====================
# 每种资源类型包含：
#   scene: 场景路径
#   zones: 生成区域列表（每个区域有 name/center/size/density/min_spacing）
#   exclude_zones: 禁止生成区域列表（每个区域有 center/size）
#   extra_data: 可选，额外数据（如 NPC 类型）

const RESOURCE_CONFIG := {
	# ========== 树木 ==========
	"tree": {
		"scene_path": "res://scenes/entities/tree.tscn",
		"zones": [
			{"name": "北部森林", "center": Vector2(-2500, -1500), "size": Vector2(5000, 3000), "density": 0.000015, "min_spacing": 150.0},
			{"name": "东部森林", "center": Vector2(3500, 500), "size": Vector2(3000, 4000), "density": 0.000012, "min_spacing": 160.0},
			{"name": "南部森林", "center": Vector2(0, 3500), "size": Vector2(6000, 2500), "density": 0.000018, "min_spacing": 140.0},
			{"name": "西部森林", "center": Vector2(-4000, 1000), "size": Vector2(2500, 3500), "density": 0.000014, "min_spacing": 155.0},
		],
		"exclude_zones": [
			{"center": Vector2(0, 0), "size": Vector2(600, 600)},
			{"center": Vector2(1500, 800), "size": Vector2(800, 600)},
			{"center": Vector2(-2000, 2000), "size": Vector2(500, 500)},
		],
	},

	# ========== 石头 ==========
	"rock": {
		"scene_path": "res://scenes/entities/rock.tscn",
		"zones": [
			{"name": "北部山区", "center": Vector2(-3000, -2000), "size": Vector2(4000, 2000), "density": 0.00003, "min_spacing": 150.0},
			{"name": "东部矿区", "center": Vector2(4000, 1000), "size": Vector2(2000, 3000), "density": 0.00004, "min_spacing": 140.0},
			{"name": "南部丘陵", "center": Vector2(0, 4000), "size": Vector2(5000, 1500), "density": 0.000025, "min_spacing": 160.0},
			{"name": "全图散布", "center": Vector2(0, 1000), "size": Vector2(12000, 7000), "density": 0.000005, "min_spacing": 300.0},
		],
		"exclude_zones": [
			{"center": Vector2(0, 0), "size": Vector2(400, 400)},
		],
	},

	# ========== 浆果丛 ==========
	"berry": {
		"scene_path": "res://scenes/entities/berry.tscn",
		"zones": [
			{"name": "森林边缘", "center": Vector2(-1500, -500), "size": Vector2(3000, 2000), "density": 0.00002, "min_spacing": 180.0},
			{"name": "南部草地", "center": Vector2(1000, 3000), "size": Vector2(4000, 2000), "density": 0.000015, "min_spacing": 200.0},
			{"name": "全图散布", "center": Vector2(0, 1000), "size": Vector2(10000, 6000), "density": 0.000003, "min_spacing": 400.0},
		],
		"exclude_zones": [
			{"center": Vector2(0, 0), "size": Vector2(300, 300)},
		],
	},

	# ========== NPC（市民） ==========
	"npc_civilian": {
		"scene_path": "res://scenes/entities/npc.tscn",
		"zones": [
			{"name": "城镇1", "center": Vector2(1500, 800), "size": Vector2(600, 400), "density": 0.003, "min_spacing": 50.0},
			{"name": "城镇2", "center": Vector2(-2000, 2000), "size": Vector2(400, 400), "density": 0.0025, "min_spacing": 55.0},
			{"name": "道路沿线", "center": Vector2(0, 1000), "size": Vector2(8000, 200), "density": 0.0001, "min_spacing": 150.0},
		],
		"exclude_zones": [],
		"extra_data": {"npc_type": "civilian"},
	},

	# ========== NPC（警察） ==========
	"npc_police": {
		"scene_path": "res://scenes/entities/npc.tscn",
		"zones": [
			{"name": "城镇1警局", "center": Vector2(1500, 800), "size": Vector2(400, 300), "density": 0.0008, "min_spacing": 60.0},
			{"name": "城镇2警局", "center": Vector2(-2000, 2000), "size": Vector2(300, 300), "density": 0.0006, "min_spacing": 65.0},
		],
		"exclude_zones": [],
		"extra_data": {"npc_type": "police"},
	},
}

# ==================== 生成函数 ====================

## 生成所有配置的资源
## parent: 父节点（通常是 world_layer）
## 返回每种资源的生成数量字典
func generate_all_resources(parent: Node) -> Dictionary:
	return generate_selected_types(RESOURCE_CONFIG.keys(), parent)

## 只生成指定类型的资源
## types: 要生成的资源类型列表，如 ["tree", "rock", "berry"]
## parent: 父节点
## 返回每种资源的生成数量字典
func generate_selected_types(types: Array, parent: Node) -> Dictionary:
	var results: Dictionary = {}
	for resource_type in types:
		if RESOURCE_CONFIG.has(resource_type):
			var config: Dictionary = RESOURCE_CONFIG[resource_type]
			var count: int = _generate_resource_type(resource_type, config, parent)
			results[resource_type] = count
			print("[ResourceGenerator] %s: 生成了 %d 个" % [resource_type, count])
	var total: int = 0
	for c in results.values():
		total += c
	print("[ResourceGenerator] 本次总计生成了 %d 个实体" % total)
	return results

## 生成单种资源类型
func _generate_resource_type(resource_type: String, config: Dictionary, parent: Node) -> int:
	# 运行时加载场景（避免preload失败导致整个脚本无法加载）
	var scene_path: String = config.get("scene_path", "")
	if scene_path == "":
		print("[ResourceGenerator] 错误: 资源类型 '%s' 没有配置scene_path" % resource_type)
		return 0
	var scene: PackedScene = load(scene_path)
	if scene == null:
		print("[ResourceGenerator] 错误: 无法加载场景 '%s'" % scene_path)
		return 0
	var zones: Array = config.zones
	var exclude_zones: Array = config.get("exclude_zones", [])
	var extra_data: Dictionary = config.get("extra_data", {})

	var total_count := 0
	for zone in zones:
		var count: int = _generate_zone(scene, zone, exclude_zones, extra_data, parent)
		total_count += count
		if zone.has("name"):
			print("[ResourceGenerator]   %s - %s: %d 个" % [resource_type, zone.name, count])
	return total_count

## 生成单个区域
func _generate_zone(scene: PackedScene, zone: Dictionary, exclude_zones: Array, extra_data: Dictionary, parent: Node) -> int:
	var center: Vector2 = zone.center
	var size: Vector2 = zone.size
	var density: float = zone.density
	var min_spacing: float = zone.min_spacing

	# 计算预期数量
	var area: float = size.x * size.y
	var target_count: int = int(area * density)

	# 网格优化
	var cell_size: float = min_spacing / sqrt(2.0)
	var cols: int = int(size.x / cell_size) + 1
	var rows: int = int(size.y / cell_size) + 1

	var grid: Array = []
	for i in range(rows):
		var row: Array = []
		row.resize(cols)
		row.fill(false)
		grid.append(row)

	var placed_positions: Array = []
	var count := 0
	var attempts := 0
	var max_attempts := target_count * 15

	while count < target_count and attempts < max_attempts:
		attempts += 1

		# 随机位置
		var pos: Vector2 = Vector2(
			center.x + randf_range(-size.x / 2.0, size.x / 2.0),
			center.y + randf_range(-size.y / 2.0, size.y / 2.0)
		)

		# 检查禁止区域
		if _is_in_exclude_zones(pos, exclude_zones):
			continue

		# 网格坐标
		var gx: int = int((pos.x - (center.x - size.x / 2.0)) / cell_size)
		var gy: int = int((pos.y - (center.y - size.y / 2.0)) / cell_size)
		if gx < 0 or gx >= cols or gy < 0 or gy >= rows:
			continue

		# 快速网格检查
		if grid[gy][gx]:
			continue

		# 详细间距检查
		var too_close := false
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var nx: int = gx + dx
				var ny: int = gy + dy
				if nx >= 0 and nx < cols and ny >= 0 and ny < rows and grid[ny][nx]:
					for p in placed_positions:
						if p.distance_to(pos) < min_spacing:
							too_close = true
							break
				if too_close:
					break
			if too_close:
				break

		if too_close:
			continue

		# 放置实体
		var entity: Node2D = scene.instantiate()
		entity.position = pos

		# 应用额外数据（如 NPC 类型）
		for key in extra_data.keys():
			entity.set(key, extra_data[key])

		parent.add_child(entity)

		# 注册到 chunk 系统（通过实体查找main节点）
		if entity.get_tree():
			var main_node: Node = entity.get_tree().current_scene
			if main_node and main_node.has_method("_register_chunk_entity"):
				main_node._register_chunk_entity(entity)

		# 标记
		grid[gy][gx] = true
		placed_positions.append(pos)
		count += 1

	return count

## 检查是否在禁止区域内
func _is_in_exclude_zones(pos: Vector2, exclude_zones: Array) -> bool:
	for zone in exclude_zones:
		var center: Vector2 = zone.center
		var size: Vector2 = zone.size
		if (abs(pos.x - center.x) < size.x / 2.0 and
				abs(pos.y - center.y) < size.y / 2.0):
			return true
	return false
