extends PlayerState
class_name PlayerDownState

var recover_time = 5.0
var can_recover = true

func _init():
	name = "down"


func _on_enter():
	player = owner
	if player and player.has_method("set_animation"):
		player.set_animation("down")
	if player and player.has_method("on_down"):
		player.on_down()


func _on_update(delta):
	if can_recover and state_time >= recover_time:
		if player and player.has_method("recover"):
			player.recover()
		request_transition("idle")
		return
	if player and player.has_method("is_dead"):
		if player.is_dead():
			request_transition("dead")


func can_transition_to(target_state_name):
	var valid_states = ["idle", "dead"]
	return valid_states.has(target_state_name)
