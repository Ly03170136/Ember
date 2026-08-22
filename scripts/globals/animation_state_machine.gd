extends Node

var _state_machines = {}
var _animation_templates = {}
var _default_transition_time = 0.15
var _auto_update = true

func _ready():
	print("[AnimationStateMachine] Animation state machine manager started")
	_register_default_templates()

func _process(delta):
	if _auto_update:
		for machine_id in _state_machines.keys():
			var machine = _state_machines[machine_id]
			if machine != null and machine.has_method("update"):
				machine.update(delta)

func _register_default_templates():
	var player_states = {
		"idle": {"loop": true, "speed": 1.0},
		"walk": {"loop": true, "speed": 1.0},
		"run": {"loop": true, "speed": 1.2},
		"attack": {"loop": false, "speed": 1.0, "next_state": "idle"},
		"hurt": {"loop": false, "speed": 1.0, "next_state": "idle"},
		"down": {"loop": true, "speed": 0.5},
		"dead": {"loop": false, "speed": 1.0},
		"interact": {"loop": false, "speed": 1.0, "next_state": "idle"},
		"craft": {"loop": false, "speed": 1.0, "next_state": "idle"},
		"build": {"loop": false, "speed": 1.0, "next_state": "idle"}
	}
	_animation_templates["player"] = player_states

	var zombie_states = {
		"idle": {"loop": true, "speed": 0.8},
		"walk": {"loop": true, "speed": 0.6},
		"run": {"loop": true, "speed": 1.0},
		"chase": {"loop": true, "speed": 1.0},
		"attack": {"loop": false, "speed": 0.8, "next_state": "chase"},
		"hurt": {"loop": false, "speed": 1.0, "next_state": "chase"},
		"down": {"loop": true, "speed": 0.3},
		"dead": {"loop": false, "speed": 1.0},
		"eat": {"loop": true, "speed": 0.8}
	}
	_animation_templates["zombie"] = zombie_states

	var npc_states = {
		"idle": {"loop": true, "speed": 1.0},
		"walk": {"loop": true, "speed": 1.0},
		"run": {"loop": true, "speed": 1.2},
		"talk": {"loop": true, "speed": 1.0},
		"attack": {"loop": false, "speed": 1.0, "next_state": "idle"},
		"hurt": {"loop": false, "speed": 1.0, "next_state": "idle"},
		"down": {"loop": true, "speed": 0.5},
		"dead": {"loop": false, "speed": 1.0},
		"work": {"loop": true, "speed": 1.0},
		"flee": {"loop": true, "speed": 1.5}
	}
	_animation_templates["npc"] = npc_states

	print("[AnimationStateMachine] Registered 3 default templates: player, zombie, npc")

func create_state_machine(machine_id, template_type, animation_player):
	if _state_machines.has(machine_id):
		print("[AnimationStateMachine] WARNING: State machine already exists: ", machine_id)
		return _state_machines[machine_id]
	if not _animation_templates.has(template_type):
		print("[AnimationStateMachine] WARNING: Template not found: ", template_type)
		return null
	var machine = StateMachineInstance.new()
	machine.initialize(machine_id, template_type, animation_player, _animation_templates[template_type])
	_state_machines[machine_id] = machine
	print("[AnimationStateMachine] Created state machine: ", machine_id, " (", template_type, ")")
	return machine

func destroy_state_machine(machine_id):
	if _state_machines.has(machine_id):
		var machine = _state_machines[machine_id]
		if machine != null:
			machine.cleanup()
		_state_machines.erase(machine_id)
		print("[AnimationStateMachine] Destroyed state machine: ", machine_id)

func get_state_machine(machine_id):
	if _state_machines.has(machine_id):
		return _state_machines[machine_id]
	return null

func play_animation(machine_id, state_name):
	var machine = get_state_machine(machine_id)
	if machine == null:
		print("[AnimationStateMachine] WARNING: State machine not found: ", machine_id)
		return false
	return machine.change_state(state_name)

func get_current_state(machine_id):
	var machine = get_state_machine(machine_id)
	if machine == null:
		return ""
	return machine.get_current_state()

func is_animation_finished(machine_id):
	var machine = get_state_machine(machine_id)
	if machine == null:
		return true
	return machine.is_finished()

func set_animation_speed(machine_id, speed):
	var machine = get_state_machine(machine_id)
	if machine == null:
		return
	machine.set_speed(speed)

func register_template(template_name, states):
	_animation_templates[template_name] = states
	print("[AnimationStateMachine] Registered template: ", template_name, " (", states.size(), " states)")

func get_registered_templates():
	return _animation_templates.keys()

func get_active_machine_count():
	return _state_machines.size()

func print_stats():
	print("[AnimationStateMachine] === Stats ===")
	print("[AnimationStateMachine] Active machines: ", _state_machines.size())
	print("[AnimationStateMachine] Registered templates: ", _animation_templates.keys())
	for machine_id in _state_machines.keys():
		var machine = _state_machines[machine_id]
		if machine != null:
			print("[AnimationStateMachine]   ", machine_id, ": ", machine.get_current_state(), " (", machine.get_template_type(), ")")
	print("[AnimationStateMachine] ===============")

class StateMachineInstance:
	var _machine_id = ""
	var _template_type = ""
	var _animation_player = null
	var _states = {}
	var _current_state = ""
	var _previous_state = ""
	var _state_time = 0.0
	var _is_finished = false
	var _speed = 1.0
	var _transition_time = 0.0
	var _is_transitioning = false
	var _callbacks = {}

	func initialize(machine_id, template_type, animation_player, states):
		_machine_id = machine_id
		_template_type = template_type
		_animation_player = animation_player
		_states = states
		_current_state = "idle"
		_previous_state = ""
		_state_time = 0.0
		_is_finished = false
		_speed = 1.0
		if _animation_player != null and _states.has("idle"):
			_play_animation("idle")

	func update(delta):
		if _animation_player == null:
			return
		_state_time += delta * _speed
		if _is_transitioning:
			_transition_time -= delta
			if _transition_time <= 0:
				_is_transitioning = false
		var current_state_config = _states.get(_current_state, {})
		if not current_state_config.get("loop", true):
			if _animation_player.has_animation(_current_state):
				var anim_length = _animation_player.get_animation(_current_state).length
				if _state_time >= anim_length:
					_is_finished = true
					var next_state = current_state_config.get("next_state", "")
					if next_state != "" and _states.has(next_state):
						change_state(next_state)
					_trigger_callback("animation_finished", _current_state)

	func change_state(state_name):
		if not _states.has(state_name):
			print("[AnimationStateMachine] WARNING: State not found: ", state_name, " in machine ", _machine_id)
			return false
		if _current_state == state_name and not _is_finished:
			return true
		_previous_state = _current_state
		_current_state = state_name
		_state_time = 0.0
		_is_finished = false
		_is_transitioning = true
		_transition_time = 0.15
		_play_animation(state_name)
		_trigger_callback("state_changed", state_name)
		return true

	func _play_animation(state_name):
		if _animation_player == null:
			return
		if _animation_player.has_animation(state_name):
			_animation_player.play(state_name, 0.15)
			_animation_player.speed_scale = _speed
		else:
			print("[AnimationStateMachine] WARNING: Animation not found: ", state_name, " in machine ", _machine_id)

	func get_current_state():
		return _current_state

	func get_previous_state():
		return _previous_state

	func get_template_type():
		return _template_type

	func is_finished():
		return _is_finished

	func set_speed(speed):
		_speed = speed
		if _animation_player != null:
			_animation_player.speed_scale = speed

	func get_speed():
		return _speed

	func get_state_time():
		return _state_time

	func connect_callback(event_name, callback):
		if not _callbacks.has(event_name):
			_callbacks[event_name] = []
		_callbacks[event_name].append(callback)

	func disconnect_callback(event_name, callback):
		if _callbacks.has(event_name):
			_callbacks[event_name].erase(callback)

	func _trigger_callback(event_name, data):
		if _callbacks.has(event_name):
			for callback in _callbacks[event_name]:
				if callback.is_valid():
					callback.call(data)

	func cleanup():
		_callbacks.clear()
		_animation_player = null
