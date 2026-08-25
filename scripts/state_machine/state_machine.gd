extends Node
class_name StateMachine

signal state_changed(old_state, new_state)
signal state_added(state_name)
signal state_removed(state_name)
signal transition_denied(from_state, to_state)

var fsm_owner = null
var states = {}
var current_state = null
var previous_state = null
var default_state_name = ""
var auto_start = true
var debug_mode = false


func _ready():
	if auto_start and default_state_name != "":
		change_state(default_state_name)


func _process(delta):
	if current_state:
		current_state.update(delta)


func _physics_process(delta):
	if current_state:
		current_state.physics_update(delta)


func _input(event):
	if current_state:
		current_state.handle_input(event)


func add_state(state):
	if state == null:
		print("[StateMachine] Error: state is null")
		return false
	if states.has(state.name):
		print("[StateMachine] Warning: state '%s' already exists, will be overwritten" % state.name)
	state.owner = fsm_owner
	state.fsm = self
	states[state.name] = state
	state_added.emit(state.name)
	if debug_mode:
		print("[StateMachine] Add state: %s" % state.name)
	return true


func remove_state(state_name):
	if not states.has(state_name):
		return false
	if current_state and current_state.name == state_name:
		if default_state_name != "" and default_state_name != state_name:
			change_state(default_state_name)
		else:
			current_state.exit()
			current_state = null
	var state = states[state_name]
	states.erase(state_name)
	state_removed.emit(state_name)
	if debug_mode:
		print("[StateMachine] Remove state: %s" % state_name)
	return true


func has_state(state_name):
	return states.has(state_name)


func get_state(state_name):
	if states.has(state_name):
		return states[state_name]
	return null


func get_all_state_names():
	return states.keys()


func change_state(state_name):
	if not states.has(state_name):
		print("[StateMachine] Error: state '%s' does not exist" % state_name)
		return false
	var new_state = states[state_name]
	var old_state_name = ""
	if current_state:
		if not current_state.can_transition_to(state_name):
			transition_denied.emit(current_state.name, state_name)
			if debug_mode:
				print("[StateMachine] Transition denied: %s -> %s" % [current_state.name, state_name])
			return false
		old_state_name = current_state.name
		current_state.exit()
		previous_state = current_state
	current_state = new_state
	current_state.enter()
	state_changed.emit(old_state_name, state_name)
	if debug_mode:
		print("[StateMachine] State change: %s -> %s" % [old_state_name, state_name])
	return true


func change_to_previous_state():
	if previous_state:
		return change_state(previous_state.name)
	return false


func reset_to_default():
	if default_state_name != "":
		return change_state(default_state_name)
	return false


func get_current_state_name():
	if current_state:
		return current_state.name
	return ""


func get_current_state():
	return current_state


func is_in_state(state_name):
	if current_state:
		return current_state.name == state_name
	return false


func was_in_state(state_name):
	if previous_state:
		return previous_state.name == state_name
	return false


func get_state_time():
	if current_state:
		return current_state.state_time
	return 0.0


func set_debug_mode(enabled):
	debug_mode = enabled


func print_states():
	print("[StateMachine] ===== State List =====")
	print("[StateMachine] Current: %s" % get_current_state_name())
	var prev_name = "None"
	if previous_state:
		prev_name = previous_state.name
	print("[StateMachine] Previous: %s" % prev_name)
	print("[StateMachine] Default: %s" % default_state_name)
	for state_name in states.keys():
		var state = states[state_name]
		print("[StateMachine]   - %s (active=%s, time=%.2f)" % [state_name, str(state.is_active), state.state_time])
	print("[StateMachine] =====================")


func to_string():
	return "StateMachine(owner=%s, current=%s, states=%d)" % [str(fsm_owner), get_current_state_name(), states.size()]
