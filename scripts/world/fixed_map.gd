extends Node2D
## 固定地图场景：玩家在Godot编辑器中手动设计地图布局
## 包含分组：Buildings(建筑)、Resources(资源)、NPCs(NPC)、Vehicles(载具)、Laboratory(实验室)

func _ready() -> void:
	print("[FixedMap] 固定地图已加载")
	# 统计实体数量
	var building_count: int = $Buildings.get_child_count()
	var resource_count: int = $Resources.get_child_count()
	var npc_count: int = $NPCs.get_child_count()
	var vehicle_count: int = $Vehicles.get_child_count()
	var lab_count: int = $Laboratory.get_child_count()
	print("[FixedMap] 实体统计：建筑%d，资源%d，NPC%d，载具%d，实验室%d" % [building_count, resource_count, npc_count, vehicle_count, lab_count])


func get_laboratory_position() -> Vector2:
	## 获取实验室位置（如果有多个，返回第一个）
	if $Laboratory.get_child_count() > 0:
		return $Laboratory.get_child(0).position
	return Vector2.ZERO


func get_all_entities() -> Array:
	## 获取所有实体（用于注册到分块加载系统）
	var entities: Array = []
	for group in [$Buildings, $Resources, $NPCs, $Vehicles, $Laboratory]:
		for child in group.get_children():
			entities.append(child)
	return entities
