extends State
class_name PlayerState

enum PlayerStateType {
	IDLE,
	WALK,
	ATTACK,
	DOWN,
	DEAD
}

var player = null

func _init(state_name = "player_base"):
	name = state_name


func _on_enter():
	player = owner
	if player == null:
		print("[PlayerState] Warning: player reference is null")


func is_moving():
	if player == null:
		return false
	if player.has_method("is_moving"):
		return player.is_moving()
	return false


func is_attacking():
	if player == null:
		return false
	if player.has_method("is_attacking"):
		return player.is_attacking()
	return false


func is_down():
	if player == null:
		return false
	if player.has_method("is_down"):
		return player.is_down()
	return false


func get_input_direction():
	if player == null:
		return Vector2.ZERO
	if player.has_method("get_input_direction"):
		return player.get_input_direction()
	return Vector2.ZERO
