extends ZombieState
class_name ZombieAttackState

var attack_duration = 1.0
var attack_cooldown = 1.5
var attack_damage = 10.0
var _attack_timer = 0.0
var _cooldown_timer = 0.0
var _has_attacked = false

func _init():
	name = "attack"


func _on_enter():
	zombie = owner
	if zombie and zombie.has_method("set_animation"):
		zombie.set_animation("attack")
	_attack_timer = 0.0
	_cooldown_timer = 0.0
	_has_attacked = false


func _on_update(delta):
	if is_down():
		request_transition("down")
		return
	if is_dead():
		request_transition("dead")
		return
	_attack_timer += delta
	if not _has_attacked and _attack_timer >= attack_duration * 0.5:
		_has_attacked = true
		if has_target() and zombie and zombie.has_method("attack_target"):
			zombie.attack_target(target, attack_damage)
	if _attack_timer >= attack_duration:
		_cooldown_timer += delta
		if not can_attack_target():
			if can_see_target():
				request_transition("chase")
			else:
				request_transition("wander")
			return
		if _cooldown_timer >= attack_cooldown:
			_attack_timer = 0.0
			_cooldown_timer = 0.0
			_has_attacked = false
			if zombie and zombie.has_method("set_animation"):
				zombie.set_animation("attack")


func can_transition_to(target_state_name):
	var valid_states = ["idle", "wander", "chase", "down", "dead"]
	return valid_states.has(target_state_name)
