extends PlayerState
class_name PlayerAttackState
## PlayerAttackState - 玩家攻击状态

var attack_duration = 0.5

func _init():
	name = "attack"


func _on_enter():
	player = owner
	if player and player.has_method("set_animation"):
		player.set_animation("attack")
	if player and player.has_method("start_attack"):
		player.start_attack()


func _on_update(delta):
	if state_time >= attack_duration:
		if is_moving():
			request_transition("walk")
		else:
			request_transition("idle")
		return
	if is_down():
		request_transition("down")


func can_transition_to(target_state_name):
	var valid_states = ["idle", "walk", "down", "dead"]
	return valid_states.has(target_state_name)
