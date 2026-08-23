extends Node
## 物理层管理系统：统一管理碰撞层、碰撞矩阵和射线检测

# 物理层常量
const LAYER_NONE = 0
const LAYER_WORLD = 1
const LAYER_PLAYER = 2
const LAYER_RESOURCE = 4
const LAYER_ENEMY = 8
const LAYER_ITEM = 16
const LAYER_BUILDING = 32
const LAYER_NPC = 64
const LAYER_INTERACTABLE = 128
const LAYER_PROJECTILE = 256
const LAYER_TRIGGER = 512
const LAYER_VEHICLE = 1024
const LAYER_DECORATION = 2048
const LAYER_ALL = LAYER_WORLD | LAYER_PLAYER | LAYER_RESOURCE | LAYER_ENEMY | LAYER_ITEM | LAYER_BUILDING | LAYER_NPC | LAYER_INTERACTABLE | LAYER_PROJECTILE | LAYER_TRIGGER | LAYER_VEHICLE | LAYER_DECORATION

# 层名称映射
const LAYER_NAMES = {
	LAYER_WORLD: "world",
	LAYER_PLAYER: "player",
	LAYER_RESOURCE: "resource",
	LAYER_ENEMY: "enemy",
	LAYER_ITEM: "item",
	LAYER_BUILDING: "building",
	LAYER_NPC: "npc",
	LAYER_INTERACTABLE: "interactable",
	LAYER_PROJECTILE: "projectile",
	LAYER_TRIGGER: "trigger",
	LAYER_VEHICLE: "vehicle",
	LAYER_DECORATION: "decoration"
}

# 碰撞矩阵定义
const COLLISION_MATRIX = {
	"player": {"layer": LAYER_PLAYER, "mask": LAYER_WORLD | LAYER_ENEMY | LAYER_NPC | LAYER_BUILDING | LAYER_VEHICLE | LAYER_INTERACTABLE | LAYER_RESOURCE},
	"enemy": {"layer": LAYER_ENEMY, "mask": LAYER_WORLD | LAYER_PLAYER | LAYER_NPC | LAYER_BUILDING | LAYER_VEHICLE | LAYER_ENEMY | LAYER_RESOURCE},
	"npc": {"layer": LAYER_NPC, "mask": LAYER_WORLD | LAYER_PLAYER | LAYER_ENEMY | LAYER_BUILDING | LAYER_VEHICLE | LAYER_NPC | LAYER_RESOURCE},
	"resource": {"layer": LAYER_RESOURCE, "mask": LAYER_WORLD | LAYER_PLAYER | LAYER_NPC | LAYER_ENEMY},
	"item": {"layer": LAYER_ITEM, "mask": LAYER_WORLD},
	"building": {"layer": LAYER_BUILDING, "mask": LAYER_WORLD | LAYER_PLAYER | LAYER_ENEMY | LAYER_NPC | LAYER_VEHICLE | LAYER_PROJECTILE},
	"projectile": {"layer": LAYER_PROJECTILE, "mask": LAYER_WORLD | LAYER_PLAYER | LAYER_ENEMY | LAYER_NPC | LAYER_BUILDING | LAYER_VEHICLE},
	"vehicle": {"layer": LAYER_VEHICLE, "mask": LAYER_WORLD | LAYER_PLAYER | LAYER_ENEMY | LAYER_NPC | LAYER_BUILDING},
	"interactable": {"layer": LAYER_INTERACTABLE, "mask": LAYER_PLAYER},
	"trigger": {"layer": LAYER_TRIGGER, "mask": LAYER_PLAYER | LAYER_ENEMY | LAYER_NPC | LAYER_VEHICLE},
	"decoration": {"layer": LAYER_DECORATION, "mask": LAYER_NONE}
}


func _ready():
	print("[PhysicsLayers] 物理层管理系统已启动")
	print("[PhysicsLayers] 已定义 ", LAYER_NAMES.size(), " 个物理层")


func get_layer_name(layer):
	return LAYER_NAMES.get(layer, "unknown")


func get_layer_by_name(name):
	for l in LAYER_NAMES.keys():
		if LAYER_NAMES[l] == name:
			return l
	return LAYER_NONE


func set_collision(body, entity_type):
	if COLLISION_MATRIX.has(entity_type):
		var config = COLLISION_MATRIX[entity_type]
		body.collision_layer = config.layer
		body.collision_mask = config.mask
	else:
		push_warning("[PhysicsLayers] 未知实体类型: " + str(entity_type))


func set_layer(body, layer):
	body.collision_layer = layer


func add_layer(body, layer):
	body.collision_layer |= layer


func remove_layer(body, layer):
	body.collision_layer &= ~layer


func has_layer(body, layer):
	return (body.collision_layer & layer) != 0


func set_mask(body, mask):
	body.collision_mask = mask


func add_mask(body, mask):
	body.collision_mask |= mask


func remove_mask(body, mask):
	body.collision_mask &= ~mask


func has_mask(body, mask):
	return (body.collision_mask & mask) != 0


func ray_cast(from, to, collision_mask = LAYER_ALL, exclude = []):
	var space_state = get_tree().root.get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(from, to, collision_mask)
	query.exclude = exclude
	return space_state.intersect_ray(query)


func ray_cast_first(from, direction, distance, collision_mask = LAYER_ALL, exclude = []):
	var to = from + direction.normalized() * distance
	return ray_cast(from, to, collision_mask, exclude)


func ray_cast_to_target(from, target, collision_mask = LAYER_ALL, exclude = []):
	var result = ray_cast(from, target, collision_mask, exclude)
	return result.is_empty()


func get_colliders_in_radius(center, radius, collision_mask = LAYER_ALL, max_results = 32):
	var space_state = get_tree().root.get_world_2d().direct_space_state
	var circle = CircleShape2D.new()
	circle.radius = radius
	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0, center)
	query.collision_mask = collision_mask
	var results = space_state.intersect_shape(query, max_results)
	var colliders = []
	for result in results:
		if result.has("collider"):
			colliders.append(result.collider)
	return colliders


func get_closest_collider(center, radius, collision_mask = LAYER_ALL):
	var colliders = get_colliders_in_radius(center, radius, collision_mask)
	var closest = null
	var closest_dist = radius
	for collider in colliders:
		if collider is Node2D:
			var dist = center.distance_to(collider.global_position)
			if dist < closest_dist:
				closest_dist = dist
				closest = collider
	return closest


func print_collision_info(body):
	print("[PhysicsLayers] 碰撞体: ", body.name)
	print("  collision_layer: ", body.collision_layer, " (", layer_to_string(body.collision_layer), ")")
	print("  collision_mask: ", body.collision_mask, " (", layer_to_string(body.collision_mask), ")")


func layer_to_string(layer):
	var names = []
	for l in LAYER_NAMES.keys():
		if (layer & l) != 0:
			names.append(LAYER_NAMES[l])
	if names.is_empty():
		return "none"
	return "|".join(names)
