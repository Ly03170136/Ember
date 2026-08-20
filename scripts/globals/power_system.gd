extends Node
## 电力系统：管理发电机和电力设备
## 自动加载为全局单例，通过 PowerSystem 访问

# 发电机配置
const GENERATORS := {
	"small_generator": {
		"name": "小型发电机",
		"desc": "功率500W，可带动5台设备",
		"power": 500,
		"fuel_consumption": 0.5,  # 每秒消耗燃料
		"fuel_type": "gasoline",
		"range": 300.0,  # 供电范围
		"max_devices": 5,
	},
	"medium_generator": {
		"name": "中型发电机",
		"desc": "功率1500W，可带动15台设备",
		"power": 1500,
		"fuel_consumption": 1.2,
		"fuel_type": "gasoline",
		"range": 500.0,
		"max_devices": 15,
	},
	"large_generator": {
		"name": "大型发电机",
		"desc": "功率3000W，可带动30台设备",
		"power": 3000,
		"fuel_consumption": 2.0,
		"fuel_type": "gasoline",
		"range": 800.0,
		"max_devices": 30,
	},
	"solar_panel": {
		"name": "太阳能板",
		"desc": "白天发电，功率200W",
		"power": 200,
		"fuel_consumption": 0.0,
		"fuel_type": "solar",
		"range": 200.0,
		"max_devices": 2,
	},
}

# 电力设备配置
const DEVICES := {
	"electric_light": {
		"name": "电灯",
		"desc": "照明设备，功率10W",
		"power_usage": 10,
		"light_radius": 200.0,
	},
	"auto_turret": {
		"name": "自动炮塔",
		"desc": "自动攻击附近丧尸，功率50W",
		"power_usage": 50,
		"damage": 15.0,
		"range": 200.0,
		"fire_rate": 1.0,
	},
	"electric_furnace": {
		"name": "电炉",
		"desc": "冶炼金属矿石，功率100W",
		"power_usage": 100,
		"smelt_speed": 2.0,
	},
	"refrigerator": {
		"name": "电冰箱",
		"desc": "保存食物，减缓腐烂，功率30W",
		"power_usage": 30,
		"rot_reduction": 0.8,
	},
	"electric_workbench": {
		"name": "电动工具台",
		"desc": "加速制作，功率40W",
		"power_usage": 40,
		"craft_speed": 2.0,
	},
	"electric_heater": {
		"name": "电暖气",
		"desc": "提供保暖，功率80W",
		"power_usage": 80,
		"warmth": 3.0,
		"range": 150.0,
	},
}

# 运行中的发电机列表
var active_generators: Array = []
# 运行中的设备列表
var active_devices: Array = []
# 全局电力状态
var total_power_generated: float = 0.0
var total_power_used: float = 0.0
var is_power_available: bool = false


func _process(delta: float) -> void:
	_update_power(delta)


func _update_power(delta: float) -> void:
	total_power_generated = 0.0
	total_power_used = 0.0
	# 计算发电机发电量
	for gen in active_generators:
		if is_instance_valid(gen) and gen.has_method("is_running") and gen.is_running():
			var gen_type: String = gen.generator_type if "generator_type" in gen else "small_generator"
			var config: Dictionary = GENERATORS[gen_type] if GENERATORS.has(gen_type) else GENERATORS["small_generator"]
			# 太阳能板只在白天发电
			if config.fuel_type == "solar":
				var main: Node = get_tree().current_scene
				if main and main.has_method("get_time_of_day"):
					var t: float = main.get_time_of_day()
					if t < 0.25 or t > 0.75:
						continue  # 夜晚不发电
			total_power_generated += config.power
	# 计算设备用电量
	for dev in active_devices:
		if is_instance_valid(dev) and dev.has_method("is_powered") and dev.is_powered():
			var dev_type: String = dev.device_type if "device_type" in dev else "electric_light"
			var config: Dictionary = DEVICES[dev_type] if DEVICES.has(dev_type) else DEVICES["electric_light"]
			total_power_used += config.power_usage
	# 判断电力是否充足
	is_power_available = total_power_generated >= total_power_used


func register_generator(gen: Node) -> void:
	if gen not in active_generators:
		active_generators.append(gen)


func unregister_generator(gen: Node) -> void:
	if gen in active_generators:
		active_generators.erase(gen)


func register_device(dev: Node) -> void:
	if dev not in active_devices:
		active_devices.append(dev)


func unregister_device(dev: Node) -> void:
	if dev in active_devices:
		active_devices.erase(dev)


func has_power_in_range(pos: Vector2, range: float = 0.0) -> bool:
	if not is_power_available:
		return false
	for gen in active_generators:
		if is_instance_valid(gen) and gen.has_method("is_running") and gen.is_running():
			var gen_type: String = gen.generator_type if "generator_type" in gen else "small_generator"
			var config: Dictionary = GENERATORS[gen_type] if GENERATORS.has(gen_type) else GENERATORS["small_generator"]
			var gen_range: float = config.range + range
			if pos.distance_to(gen.position) <= gen_range:
				return true
	return false


func get_generator_info(gen_type: String) -> Dictionary:
	if GENERATORS.has(gen_type):
		return GENERATORS[gen_type]
	return {}


func get_device_info(dev_type: String) -> Dictionary:
	if DEVICES.has(dev_type):
		return DEVICES[dev_type]
	return {}


func get_all_generators() -> Dictionary:
	return GENERATORS


func get_all_devices() -> Dictionary:
	return DEVICES
