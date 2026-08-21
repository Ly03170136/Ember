extends ZombieState
class_name ZombieIdleState

var idle_duration = 2.0
var next_state = "wander"

func _init():
	name = "idle"


func _on_enter():
	zombie = owner
	if zombie and zombie.has_method("set_animation"):
		zombie.set_animation("idle")


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
	if state_time >= idle_duration:
		request_transition(next_state)


func can_transition_to(target_state_name):
	var valid_states = ["wander", "chase", "down", "dead"]
	return valid_states.has(target_state_name)
