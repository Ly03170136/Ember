extends RefCounted
class_name State
## State - 状态基类
## 所有状态都继承自这个类

# ==================== 属性 ====================
var name = "base_state"
var owner = null
var fsm = null
var is_active = false
var state_time = 0.0

# ==================== 信号 ====================
signal state_entered()
signal state_exited()
signal transition_requested(target_state)

# ==================== 生命周期 ====================

func _init(state_name = "base_state"):
	name = state_name


func enter():
	is_active = true
	state_time = 0.0
	state_entered.emit()
	_on_enter()


func exit():
	is_active = false
	_on_exit()
	state_exited.emit()


func update(delta):
	if not is_active:
		return
	state_time += delta
	_on_update(delta)


func handle_input(event):
	if not is_active:
		return
	_on_handle_input(event)


func physics_update(delta):
	if not is_active:
		return
	_on_physics_update(delta)


# ==================== 可重写方法 ====================

func _on_enter():
	pass


func _on_exit():
	pass


func _on_update(delta):
	pass


func _on_handle_input(event):
	pass


func _on_physics_update(delta):
	pass


# ==================== 工具方法 ====================

func can_transition_to(target_state_name):
	return true


func request_transition(target_state_name):
	if fsm:
		fsm.change_state(target_state_name)


func is_state(state_name):
	return name == state_name


func to_string():
	return "State(%s, active=%s, time=%.2f)" % [name, str(is_active), state_time]
