extends ZombieState
class_name ZombieChaseState

var chase_speed = 80.0
var lose_target_time = 3.0
var _lost_target_timer = 0.0

func _init():
	name = "chase"


func _on_enter():
	zombie = owner
	if zombie and zombie.has_method("set_animation"):
		zombie.set_animation("run")
	_lost_target_timer = 0.0


func _on_update(delta):
	if is_down():
		request_transition("down")
		return
	if is_dead():
		request_transition("dead")
		return
	if can_attack_target():
		request_transition("attack")
		return
	if can_see_target():
		_lost_target_timer = 0.0
	else:
		_lost_target_timer += delta
		if _lost_target_timer >= lose_target_time:
			request_transition("wander")
			return
	if has_target() and zombie and zombie.has_method("move_toward"):
		zombie.move_toward(get_target_position(), chase_speed * delta)
	elif has_target() and zombie and zombie.has_method("move"):
		var direction = (get_target_position() - zombie.global_position).normalized()
		zombie.move(direction * chase_speed * delta)


func can_transition_to(target_state_name):
	var valid_states = ["idle", "wander", "attack", "down", "dead"]
	return valid_states.has(target_state_name)
