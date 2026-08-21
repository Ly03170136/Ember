extends ZombieState
class_name ZombieWanderState

var wander_duration = 5.0
var wander_speed = 30.0
var change_direction_interval = 2.0
var _wander_direction = Vector2.ZERO
var _direction_timer = 0.0

func _init():
	name = "wander"


func _on_enter():
	zombie = owner
	if zombie and zombie.has_method("set_animation"):
		zombie.set_animation("walk")
	_wander_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	_direction_timer = 0.0


func _on_update(delta):
	if is_down():
		request_transition("down")
		return
	if is_dead():
		request_transition("dead")
		return
	if can_see_target():
		request_transition("chase")
		return
	_direction_timer += delta
	if _direction_timer >= change_direction_interval:
		_direction_timer = 0.0
		_wander_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	if zombie and zombie.has_method("move"):
		zombie.move(_wander_direction * wander_speed * delta)
	if state_time >= wander_duration:
		request_transition("idle")


func can_transition_to(target_state_name):
	var valid_states = ["idle", "chase", "down", "dead"]
	return valid_states.has(target_state_name)
