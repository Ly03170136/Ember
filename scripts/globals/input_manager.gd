extends Node
## Input Manager - EMBER
## Features:
## 1. Unified input management (keyboard, mouse, gamepad)
## 2. UI focus management (block game shortcuts when UI input focused)
## 3. Input action mapping
## 4. Input config save/load
## 5. Input state query
## 6. Input event bus (signals)
## 7. Resolve UI input and game shortcut conflicts
## 8. Gamepad support (joystick, trigger, buttons)
## 9. Customizable key bindings

# ==================== Signals (Input Event Bus) ====================
signal action_pressed(action: String)
signal action_released(action: String)
signal input_focus_changed(has_focus: bool)
signal key_binding_changed(action: String, keycode: int)
signal controller_connected(device: int)
signal controller_disconnected(device: int)

# ==================== Config ====================
const INPUT_CONFIG_FILE: String = "user://input_config.cfg"

# ==================== State Variables ====================
var _ui_focused: bool = false
var _pressed_actions: Dictionary = {}
var _action_bindings: Dictionary = {}
var _mouse_position: Vector2 = Vector2.ZERO
var _mouse_delta: Vector2 = Vector2.ZERO
var _joypad_axes: Dictionary = {}
var _rebinding_action: String = ""
var _rebinding_callback: Callable = Callable()

# ==================== Action Chinese Names ====================
const ACTION_NAMES: Dictionary = {
	"move_up": "向上移动",
	"move_down": "向下移动",
	"move_left": "向左移动",
	"move_right": "向右移动",
	"attack": "攻击",
	"interact": "互动/采集",
	"sprint": "冲刺",
	"crouch": "蹲下",
	"inventory": "背包 (TAB)",
	"craft": "制作菜单 (E)",
	"build": "建造菜单 (B)",
	"tech_tree": "科技树 (T)",
	"character": "人物属性 (I)",
	"map": "大地图 (M)",
	"chat": "聊天 (ENTER)",
	"pause": "暂停/设置 (ESC)",
	"performance": "性能监控 (F3)",
	"save": "手动存档 (F5)",
	"quickbar_1": "快捷栏 1",
	"quickbar_2": "快捷栏 2",
	"quickbar_3": "快捷栏 3",
	"quickbar_4": "快捷栏 4",
	"quickbar_5": "快捷栏 5",
	"quickbar_6": "快捷栏 6",
	"quickbar_7": "快捷栏 7",
	"quickbar_8": "快捷栏 8",
	"quickbar_9": "快捷栏 9",
}

const ACTION_CATEGORIES: Dictionary = {
	"移动": ["move_up", "move_down", "move_left", "move_right"],
	"动作": ["attack", "interact", "sprint", "crouch"],
	"UI菜单": ["inventory", "craft", "build", "tech_tree", "character", "map", "chat", "pause", "performance", "save"],
	"快捷栏": ["quickbar_1", "quickbar_2", "quickbar_3", "quickbar_4", "quickbar_5", "quickbar_6", "quickbar_7", "quickbar_8", "quickbar_9"],
}

# ==================== Default Action Bindings ====================
const DEFAULT_BINDINGS: Dictionary = {
	"move_up": [KEY_W],
	"move_down": [KEY_S],
	"move_left": [KEY_A],
	"move_right": [KEY_D],
	"attack": [MOUSE_BUTTON_LEFT],
	"interact": [KEY_F],
	"sprint": [KEY_SHIFT],
	"crouch": [KEY_CTRL],
	"inventory": [KEY_TAB],
	"craft": [KEY_E],
	"build": [KEY_B],
	"tech_tree": [KEY_T],
	"character": [KEY_I],
	"map": [KEY_M],
	"chat": [KEY_ENTER],
	"pause": [KEY_ESCAPE],
	"performance": [KEY_F3],
	"save": [KEY_F5],
	"quickbar_1": [KEY_1],
	"quickbar_2": [KEY_2],
	"quickbar_3": [KEY_3],
	"quickbar_4": [KEY_4],
	"quickbar_5": [KEY_5],
	"quickbar_6": [KEY_6],
	"quickbar_7": [KEY_7],
	"quickbar_8": [KEY_8],
	"quickbar_9": [KEY_9],
}

# ==================== Lifecycle ====================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[InputManager] Input Manager started")
	if GameLogger:
		GameLogger.info("Input Manager started", "InputManager")
	_action_bindings = DEFAULT_BINDINGS.duplicate(true)
	_load_input_config()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


func _input(event: InputEvent) -> void:
	if _rebinding_action != "":
		_capture_rebinding_key(event)
		return
	if event is InputEventMouseMotion:
		_mouse_position = event.position
		_mouse_delta = event.relative
	_check_ui_focus()
	if _ui_focused:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE:
				_release_ui_focus()
		return
	if event is InputEventKey:
		_handle_key_event(event)
	elif event is InputEventMouseButton:
		_handle_mouse_button_event(event)
	elif event is InputEventJoypadButton:
		_handle_joypad_button_event(event)
	elif event is InputEventJoypadMotion:
		_handle_joypad_motion_event(event)


func _physics_process(_delta: float) -> void:
	_check_ui_focus()
	_update_joypad_axis_actions()


# ==================== Public API ====================

func is_action_pressed(action: String) -> bool:
	if _ui_focused:
		return false
	return _pressed_actions.has(action) and _pressed_actions[action]


func is_ui_focused() -> bool:
	return _ui_focused


func get_mouse_position() -> Vector2:
	return _mouse_position


func get_mouse_delta() -> Vector2:
	return _mouse_delta


func get_action_bindings() -> Dictionary:
	return _action_bindings.duplicate(true)


func get_action_binding(action: String) -> Array:
	if _action_bindings.has(action):
		return _action_bindings[action].duplicate()
	return []


func set_action_binding(action: String, keycodes: Array) -> void:
	_action_bindings[action] = keycodes.duplicate()
	_save_input_config()
	key_binding_changed.emit(action, keycodes[0] if keycodes.size() > 0 else 0)


func reset_to_default() -> void:
	_action_bindings = DEFAULT_BINDINGS.duplicate(true)
	_save_input_config()
	print("[InputManager] Reset to default input config")


func get_action_name(action: String) -> String:
	if ACTION_NAMES.has(action):
		return ACTION_NAMES[action]
	return action


func get_action_categories() -> Dictionary:
	return ACTION_CATEGORIES.duplicate(true)


func get_key_name(keycode: int) -> String:
	if keycode == 0:
		return "未绑定"
	# Check mouse buttons first
	if keycode >= MOUSE_BUTTON_LEFT and keycode <= MOUSE_BUTTON_MIDDLE:
		match keycode:
			MOUSE_BUTTON_LEFT:
				return "Mouse Left"
			MOUSE_BUTTON_RIGHT:
				return "Mouse Right"
			MOUSE_BUTTON_MIDDLE:
				return "Mouse Middle"
	# Try keyboard key name first
	var key_name: String = OS.get_keycode_string(keycode)
	if key_name != "" and key_name != "Unknown":
		return key_name
	# If not a valid keyboard key, check if it's a joypad button
	if keycode >= JOY_BUTTON_A and keycode <= JOY_BUTTON_MAX:
		return "Joypad " + str(keycode - JOY_BUTTON_A + 1)
	return str(keycode)


func start_rebinding(action: String, callback: Callable = Callable()) -> void:
	_rebinding_action = action
	_rebinding_callback = callback
	print("[InputManager] Start rebinding action: ", action)


func cancel_rebinding() -> void:
	_rebinding_action = ""
	_rebinding_callback = Callable()


func is_rebinding() -> bool:
	return _rebinding_action != ""


func get_connected_joypads() -> Array:
	return Input.get_connected_joypads()


func get_joypad_name(device: int) -> String:
	## Get joypad name (safe version)
	## In Godot 4.7, Input.get_joypad_name may not exist as static method
	## Use default name to avoid parse error
	return "Joypad " + str(device + 1)


# ==================== Keyboard/Joypad Binding Helpers ====================

func is_keyboard_key(keycode: int) -> bool:
	## Check if keycode is a keyboard key
	if keycode == 0:
		return false
	if is_mouse_button(keycode):
		return false
	# Try to get keyboard key name
	var key_name: String = OS.get_keycode_string(keycode)
	return key_name != "" and key_name != "Unknown"


func is_mouse_button(keycode: int) -> bool:
	## Check if keycode is a mouse button
	return keycode >= MOUSE_BUTTON_LEFT and keycode <= MOUSE_BUTTON_MIDDLE


func is_joypad_button(keycode: int) -> bool:
	## Check if keycode is a joypad button
	if keycode == 0:
		return false
	if is_mouse_button(keycode):
		return false
	if is_keyboard_key(keycode):
		return false
	return keycode >= JOY_BUTTON_A and keycode <= JOY_BUTTON_MAX


func get_keyboard_binding(action: String) -> int:
	## Get keyboard binding for an action (first non-joypad, non-mouse binding)
	var bindings: Array = get_action_binding(action)
	for keycode in bindings:
		if is_keyboard_key(keycode):
			return keycode
	return 0


func get_joypad_binding(action: String) -> int:
	## Get joypad binding for an action (first joypad binding)
	var bindings: Array = get_action_binding(action)
	for keycode in bindings:
		if is_joypad_button(keycode):
			return keycode
	return 0


func set_keyboard_binding(action: String, keycode: int) -> void:
	## Set keyboard binding for an action (replace existing keyboard binding)
	## Also remove the same key from other actions to avoid conflicts
	# First, remove this key from all other actions
	for other_action in _action_bindings.keys():
		if other_action != action:
			var other_bindings: Array = _action_bindings[other_action]
			if other_bindings.has(keycode):
				var new_other_bindings: Array = []
				for k in other_bindings:
					if k != keycode:
						new_other_bindings.append(k)
				_action_bindings[other_action] = new_other_bindings
	# Then, set the binding for the current action
	var bindings: Array = get_action_binding(action)
	# Remove existing keyboard bindings
	var new_bindings: Array = []
	for k in bindings:
		if not is_keyboard_key(k):
			new_bindings.append(k)
	# Add new keyboard binding
	if keycode != 0:
		new_bindings.insert(0, keycode)
	set_action_binding(action, new_bindings)


func set_joypad_binding(action: String, keycode: int) -> void:
	## Set joypad binding for an action (replace existing joypad binding)
	## Also remove the same button from other actions to avoid conflicts
	# First, remove this button from all other actions
	for other_action in _action_bindings.keys():
		if other_action != action:
			var other_bindings: Array = _action_bindings[other_action]
			if other_bindings.has(keycode):
				var new_other_bindings: Array = []
				for k in other_bindings:
					if k != keycode:
						new_other_bindings.append(k)
				_action_bindings[other_action] = new_other_bindings
	# Then, set the binding for the current action
	var bindings: Array = get_action_binding(action)
	# Remove existing joypad bindings
	var new_bindings: Array = []
	for k in bindings:
		if not is_joypad_button(k):
			new_bindings.append(k)
	# Add new joypad binding
	if keycode != 0:
		new_bindings.append(keycode)
	set_action_binding(action, new_bindings)


# ==================== Input Handling ====================

func _handle_key_event(event: InputEventKey) -> void:
	# 使用keycode来检测按键，与get_key_name保持一致
	var keycode: int = event.keycode
	for action in _action_bindings.keys():
		var bindings: Array = _action_bindings[action]
		if bindings.has(keycode):
			if event.pressed and not event.echo:
				_pressed_actions[action] = true
				action_pressed.emit(action)
			elif not event.pressed:
				_pressed_actions.erase(action)
				action_released.emit(action)


func _handle_mouse_button_event(event: InputEventMouseButton) -> void:
	var button_index: int = event.button_index
	print("[InputManager] 鼠标按钮事件: button=", button_index, " pressed=", event.pressed, " ui_focused=", _ui_focused)
	for action in _action_bindings.keys():
		var bindings: Array = _action_bindings[action]
		if bindings.has(button_index):
			print("[InputManager] 匹配到 action: ", action)
			if event.pressed:
				_pressed_actions[action] = true
				action_pressed.emit(action)
			elif not event.pressed:
				_pressed_actions.erase(action)
				action_released.emit(action)


func _handle_joypad_button_event(event: InputEventJoypadButton) -> void:
	var button_index: int = event.button_index
	for action in _action_bindings.keys():
		var bindings: Array = _action_bindings[action]
		if bindings.has(button_index):
			if event.pressed:
				_pressed_actions[action] = true
				action_pressed.emit(action)
			elif not event.pressed:
				_pressed_actions.erase(action)
				action_released.emit(action)


func _handle_joypad_motion_event(event: InputEventJoypadMotion) -> void:
	var device: int = event.device
	var axis: int = event.axis
	var axis_value: float = event.axis_value
	if not _joypad_axes.has(device):
		_joypad_axes[device] = {}
	_joypad_axes[device][axis] = axis_value


func _update_joypad_axis_actions() -> void:
	for device in Input.get_connected_joypads():
		if not _joypad_axes.has(device):
			continue
		var axes: Dictionary = _joypad_axes[device]
		if axes.has(JOY_AXIS_LEFT_X):
			var x_val: float = axes[JOY_AXIS_LEFT_X]
			if x_val > 0.5:
				_pressed_actions["move_right"] = true
			else:
				_pressed_actions.erase("move_right")
			if x_val < -0.5:
				_pressed_actions["move_left"] = true
			else:
				_pressed_actions.erase("move_left")
		if axes.has(JOY_AXIS_LEFT_Y):
			var y_val: float = axes[JOY_AXIS_LEFT_Y]
			if y_val > 0.5:
				_pressed_actions["move_down"] = true
			else:
				_pressed_actions.erase("move_down")
			if y_val < -0.5:
				_pressed_actions["move_up"] = true
			else:
				_pressed_actions.erase("move_up")


func _capture_rebinding_key(event: InputEvent) -> void:
	var keycode: int = 0
	if event is InputEventKey and event.pressed and not event.echo:
		keycode = event.keycode
	elif event is InputEventMouseButton and event.pressed:
		keycode = event.button_index
	elif event is InputEventJoypadButton and event.pressed:
		keycode = event.button_index
	else:
		return
	_action_bindings[_rebinding_action] = [keycode]
	_save_input_config()
	print("[InputManager] Action %s rebound to %s" % [_rebinding_action, get_key_name(keycode)])
	key_binding_changed.emit(_rebinding_action, keycode)
	if _rebinding_callback.is_valid():
		_rebinding_callback.call(_rebinding_action, keycode)
	_rebinding_action = ""
	_rebinding_callback = Callable()


# ==================== UI Focus Management ====================

func _check_ui_focus() -> void:
	var focused: Node = get_viewport().gui_get_focus_owner()
	var has_focus: bool = false
	if focused and (focused is LineEdit or focused is TextEdit):
		has_focus = true
	if has_focus != _ui_focused:
		_ui_focused = has_focus
		input_focus_changed.emit(_ui_focused)
		if _ui_focused:
			_pressed_actions.clear()
			print("[InputManager] UI input focused, game input paused")
		else:
			print("[InputManager] UI input unfocused, game input resumed")


func _release_ui_focus() -> void:
	var focused: Node = get_viewport().gui_get_focus_owner()
	if focused and (focused is LineEdit or focused is TextEdit):
		focused.release_focus()
	_ui_focused = false
	_pressed_actions.clear()
	input_focus_changed.emit(false)


# ==================== Joypad Events ====================

func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		print("[InputManager] Joypad connected: ", device, " - ", get_joypad_name(device))
		controller_connected.emit(device)
	else:
		print("[InputManager] Joypad disconnected: ", device)
		controller_disconnected.emit(device)
		if _joypad_axes.has(device):
			_joypad_axes.erase(device)


# ==================== Config Save/Load ====================

func _save_input_config() -> void:
	var config: ConfigFile = ConfigFile.new()
	for action in _action_bindings.keys():
		var bindings: Array = _action_bindings[action]
		var key_str: String = ""
		for i in range(bindings.size()):
			if i > 0:
				key_str += ","
			key_str += str(bindings[i])
		config.set_value("bindings", action, key_str)
	var error: Error = config.save(INPUT_CONFIG_FILE)
	if error == OK:
		print("[InputManager] Input config saved")
	else:
		print("[InputManager] Input config save failed: ", error)


func _load_input_config() -> void:
	var config: ConfigFile = ConfigFile.new()
	var error: Error = config.load(INPUT_CONFIG_FILE)
	if error != OK:
		print("[InputManager] No input config file found, using default")
		return
	if config.has_section("bindings"):
		for action in config.get_section_keys("bindings"):
			var key_str: String = config.get_value("bindings", action, "")
			if key_str != "":
				var bindings: Array = []
				var key_strs: Array = key_str.split(",")
				for ks in key_strs:
					bindings.append(int(ks))
				if bindings.size() > 0:
					_action_bindings[action] = bindings
		print("[InputManager] Input config loaded")
