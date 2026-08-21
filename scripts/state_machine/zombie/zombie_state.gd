extends State
class_name ZombieState

enum ZombieStateType {
	IDLE,
	WANDER,
	CHASE,
	ATTACK,
	DOWN,
	DEAD
}

var zombie = null
var target = null

func _init(state_name = "zombie_base"):
	name = state_name


func _on_enter():
	zombie = owner
	if zombie == null:
		print("[ZombieState] Warning: zombie reference is null")


func has_target():
	return target != null and is_instance_valid(target)


func get_target_position():
	if has_target():
		return target.global_position
	return Vector2.ZERO


func get_distance_to_target():
	if zombie == null or not has_target():
		return INF
	return zombie.global_position.distance_to(target.global_position)


func can_see_target():
	if zombie == null or not has_target():
		return false
	if zombie.has_method("can_see_target"):
		return zombie.can_see_target(target)
	var detect_range = 300.0
	if zombie.has_method("get_detect_range"):
		detect_range = zombie.get_detect_range()
	return get_distance_to_target() <= detect_range


func can_attack_target():
	if zombie == null or not has_target():
		return false
	if zombie.has_method("can_attack_target"):
		return zombie.can_attack_target(target)
	var attack_range = 50.0
	if zombie.has_method("get_attack_range"):
		attack_range = zombie.get_attack_range()
	return get_distance_to_target() <= attack_range


func is_down():
	if zombie == null:
		return false
	if zombie.has_method("is_down"):
		return zombie.is_down()
	return false


func is_dead():
	if zombie == null:
		return false
	if zombie.has_method("is_dead"):
		return zombie.is_dead()
	return false
