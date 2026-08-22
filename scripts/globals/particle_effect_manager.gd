extends Node

var _effect_pools = {}
var _active_effects = []
var _effect_templates = {}
var _default_pool_size = 10
var _max_pool_size = 50
var _auto_cleanup_interval = 5.0
var _cleanup_timer = 0.0

func _ready():
	print("[ParticleEffectManager] Particle effect manager started")
	_register_default_templates()
	_preload_default_pools()

func _process(delta):
	_cleanup_timer += delta
	if _cleanup_timer >= _auto_cleanup_interval:
		_cleanup_timer = 0.0
		_cleanup_finished_effects()

func _register_default_templates():
	_register_effect_template("blood", "res://scenes/effects/blood_effect.tscn")
	_register_effect_template("explosion", "res://scenes/effects/explosion_effect.tscn")
	_register_effect_template("fire", "res://scenes/effects/fire_effect.tscn")
	_register_effect_template("smoke", "res://scenes/effects/smoke_effect.tscn")
	_register_effect_template("spark", "res://scenes/effects/spark_effect.tscn")
	_register_effect_template("hit", "res://scenes/effects/hit_effect.tscn")
	_register_effect_template("heal", "res://scenes/effects/heal_effect.tscn")
	_register_effect_template("level_up", "res://scenes/effects/level_up_effect.tscn")
	print("[ParticleEffectManager] Registered 8 default effect templates")

func _preload_default_pools():
	for effect_name in _effect_templates.keys():
		_preload_pool(effect_name, _default_pool_size)

func _register_effect_template(effect_name, scene_path):
	_effect_templates[effect_name] = scene_path

func _preload_pool(effect_name, count):
	if not _effect_templates.has(effect_name):
		print("[ParticleEffectManager] WARNING: Effect template not found: ", effect_name)
		return
	if not _effect_pools.has(effect_name):
		_effect_pools[effect_name] = []
	var scene_path = _effect_templates[effect_name]
	var packed_scene = load(scene_path)
	if packed_scene == null:
		print("[ParticleEffectManager] WARNING: Failed to load effect scene: ", scene_path)
		return
	for i in range(count):
		var effect = packed_scene.instantiate()
		effect.visible = false
		effect.set_meta("pool_name", effect_name)
		effect.set_meta("is_active", false)
		_effect_pools[effect_name].append(effect)
	print("[ParticleEffectManager] Preloaded pool '", effect_name, "' with ", count, " effects")

func play_effect(effect_name, position, rotation, scale):
	if rotation == null:
		rotation = 0.0
	if scale == null:
		scale = Vector2(1, 1)
	if not _effect_templates.has(effect_name):
		print("[ParticleEffectManager] WARNING: Effect template not found: ", effect_name)
		return null
	var effect = _get_from_pool(effect_name)
	if effect == null:
		print("[ParticleEffectManager] WARNING: Failed to get effect from pool: ", effect_name)
		return null
	effect.position = position
	effect.rotation = rotation
	effect.scale = scale
	effect.visible = true
	effect.set_meta("is_active", true)
	effect.set_meta("start_time", Time.get_ticks_msec())
	_active_effects.append(effect)
	if effect.has_method("play"):
		effect.play()
	if effect is CPUParticles2D:
		effect.emitting = true
	elif effect is GPUParticles2D:
		effect.emitting = true
	return effect

func _get_from_pool(effect_name):
	if not _effect_pools.has(effect_name):
		_effect_pools[effect_name] = []
	var pool = _effect_pools[effect_name]
	if pool.size() > 0:
		var effect = pool.pop_back()
		return effect
	var scene_path = _effect_templates[effect_name]
	var packed_scene = load(scene_path)
	if packed_scene == null:
		return null
	var effect = packed_scene.instantiate()
	effect.visible = false
	effect.set_meta("pool_name", effect_name)
	effect.set_meta("is_active", false)
	print("[ParticleEffectManager] Pool '", effect_name, "' exhausted, creating new effect (total active: ", _active_effects.size(), ")")
	return effect

func _return_to_pool(effect):
	var effect_name = effect.get_meta("pool_name", "")
	if effect_name == "":
		effect.queue_free()
		return
	effect.visible = false
	effect.set_meta("is_active", false)
	if effect is CPUParticles2D:
		effect.emitting = false
	elif effect is GPUParticles2D:
		effect.emitting = false
	if _effect_pools.has(effect_name):
		var pool = _effect_pools[effect_name]
		if pool.size() < _max_pool_size:
			pool.append(effect)
		else:
			effect.queue_free()
	else:
		effect.queue_free()

func _cleanup_finished_effects():
	var to_remove = []
	for effect in _active_effects:
		if effect == null or not is_instance_valid(effect):
			to_remove.append(effect)
			continue
		var is_active = effect.get_meta("is_active", false)
		if not is_active:
			to_remove.append(effect)
			continue
		var start_time = effect.get_meta("start_time", 0)
		var elapsed = Time.get_ticks_msec() - start_time
		var is_finished = false
		if effect is CPUParticles2D:
			if not effect.emitting and effect.get_particle_count() == 0:
				is_finished = true
		elif effect is GPUParticles2D:
			if not effect.emitting:
				is_finished = true
		elif effect.has_method("is_finished"):
			if effect.is_finished():
				is_finished = true
		elif elapsed > 10000:
			is_finished = true
		if is_finished:
			to_remove.append(effect)
	for effect in to_remove:
		if _active_effects.has(effect):
			_active_effects.erase(effect)
		if effect != null and is_instance_valid(effect):
			_return_to_pool(effect)
	if to_remove.size() > 0:
		print("[ParticleEffectManager] Cleaned up ", to_remove.size(), " finished effects, active: ", _active_effects.size())

func stop_effect(effect):
	if effect == null or not is_instance_valid(effect):
		return
	if effect is CPUParticles2D:
		effect.emitting = false
	elif effect is GPUParticles2D:
		effect.emitting = false
	effect.set_meta("is_active", false)

func stop_all_effects():
	for effect in _active_effects:
		if effect != null and is_instance_valid(effect):
			stop_effect(effect)
	print("[ParticleEffectManager] Stopped all effects")

func clear_pool(effect_name):
	if _effect_pools.has(effect_name):
		var pool = _effect_pools[effect_name]
		for effect in pool:
			if effect != null and is_instance_valid(effect):
				effect.queue_free()
		pool.clear()
		print("[ParticleEffectManager] Cleared pool '", effect_name, "'")

func clear_all_pools():
	for effect_name in _effect_pools.keys():
		clear_pool(effect_name)
	print("[ParticleEffectManager] Cleared all pools")

func get_active_effect_count():
	return _active_effects.size()

func get_pool_size(effect_name):
	if _effect_pools.has(effect_name):
		return _effect_pools[effect_name].size()
	return 0

func get_total_pool_size():
	var total = 0
	for effect_name in _effect_pools.keys():
		total += _effect_pools[effect_name].size()
	return total

func get_registered_effects():
	return _effect_templates.keys()

func print_stats():
	print("[ParticleEffectManager] === Stats ===")
	print("[ParticleEffectManager] Active effects: ", _active_effects.size())
	print("[ParticleEffectManager] Total pool size: ", get_total_pool_size())
	for effect_name in _effect_templates.keys():
		print("[ParticleEffectManager]   ", effect_name, ": pool=", get_pool_size(effect_name))
	print("[ParticleEffectManager] ===============")
