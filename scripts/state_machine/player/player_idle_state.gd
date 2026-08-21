extends PlayerState
class_name PlayerIdleState

func _init():
	name = "idle"


func _on_enter():
	player = owner
	if player and player.has_method("set_animation"):
		player.set_animation("idle")


func _on_update(delta):
	if is_moving() or get_input_direction() != Vector2.ZERO:
		request_transition("walk")
		return
	if is_attacking():
		request_transition("attack")
		return
	if is_down():
		request_transition("down")


func can_transition_to(target_state_name):
	return true
