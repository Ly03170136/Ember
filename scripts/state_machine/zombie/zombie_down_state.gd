extends ZombieState
class_name ZombieDownState

var down_duration = 3.0
var can_revive = false

func _init():
	name = "down"


func _on_enter():
	zombie = owner
	if zombie and zombie.has_method("set_animation"):
		zombie.set_animation("down")
	if zombie and zombie.has_method("on_down"):
		zombie.on_down()


func _on_update(delta):
	if is_dead():
		request_transition("dead")
		return
	if state_time >= down_duration:
		if can_revive:
			if zombie and zombie.has_method("revive"):
				zombie.revive()
			request_transition("idle")


func can_transition_to(target_state_name):
	var valid_states = ["idle", "dead"]
	return valid_states.has(target_state_name)
