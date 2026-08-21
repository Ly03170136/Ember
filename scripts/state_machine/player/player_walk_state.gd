extends PlayerState
class_name PlayerWalkState

func _init():
	name = "walk"


func _on_enter():
	player = owner
	if player and player.has_method("set_animation"):
		player.set_animation("walk")


func _on_update(delta):
	if not is_moving() and get_input_direction() == Vector2.ZERO:
		request_transition("idle")
		return
	if is_attacking():
		request_transition("attack")
		return
	if is_down():
		request_transition("down")


func can_transition_to(target_state_name):
	return true
