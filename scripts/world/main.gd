extends Node2D
## 主游戏场景：游戏世界根节点
## 处理世界初始化、资源生成、昼夜循环等

@onready var world_layer: Node2D = $WorldLayer
@onready var hud: CanvasLayer = $HUD
@onready var inventory_ui: Control = $InventoryUI
@onready var quickbar: Control = $QuickBar
@onready var craft_ui: Control = $CraftUI
@onready var build_ui: Control = $BuildUI
@onready var map_ui: Control = $MapUI
@onready var loading_screen: Control = $LoadingScreen
@onready var settings_menu: Control = $SettingsMenu
@onready var tech_tree_ui: Control = $TechTreeUI
var character_ui: Control = null
var debug_console: CanvasLayer = null  # 调试控制台

var inventory_ui_connected: bool = false
var game_over: bool = false
var game_over_label: Label = null

# 建筑场景
const BUILDING_SCENE := preload("res://scenes/entities/building.tscn")

var day_length: float = 900.0  # 15分钟 = 900秒
var current_time: float = 0.35  # 0.0=黎明, 0.5=正午, 1.0=次日黎明（从上午开始，白天能看清地面）
var day_count: int = 1
var is_night: bool = false

# 资源节点场景
const TREE_SCENE := preload("res://scenes/entities/tree.tscn")
const ROCK_SCENE := preload("res://scenes/entities/rock.tscn")
const BERRY_SCENE := preload("res://scenes/entities/berry.tscn")
const ZOMBIE_SCENE := preload("res://scenes/entities/zombie.tscn")
const VEHICLE_SCENE := preload("res://scenes/entities/vehicle.tscn")
const NPC_SCENE := preload("res://scenes/entities/npc.tscn")

# 固定地图场景（玩家在编辑器中手动设计）
const FIXED_MAP_SCENE := preload("res://scenes/world/fixed_map.tscn")
var fixed_map: Node2D = null
const USE_FIXED_MAP := false  # 设置为true使用固定地图，false使用随机生成

const MAX_ZOMBIES := 100
const ZOMBIE_SPAWN_INTERVAL := 5.0
var zombie_spawn_timer: float = 0.0

# ==================== P1: 季节天气系统（长春气候，含月份） ====================
const SEASON_LENGTH := 12  # 每个季节12天（3个月×4天）
const SEASONS := ["spring", "summer", "autumn", "winter"]
const SEASON_NAMES := {"spring": "春季", "summer": "夏季", "autumn": "秋季", "winter": "冬季"}
# 长春气候：温带大陆性季风气候，冬季严寒漫长，夏季温暖
# 季节平均温度（保留兼容）
const SEASON_TEMPS := {"spring": 7.0, "summer": 23.0, "autumn": 6.0, "winter": -13.0}
var season: String = "spring"
var day_in_season: int = 1

# 月份系统（一年12个月，每月4天，共48天）
# 月份天数分配（每月4天）
const MONTH_DAYS := [4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4]  # 1-12月，每月4天
const MONTH_NAMES := ["1月", "2月", "3月", "4月", "5月", "6月", "7月", "8月", "9月", "10月", "11月", "12月"]
# 长春月平均气温（实际数据）
const MONTH_TEMPS := [-15.0, -11.0, -2.0, 8.0, 16.0, 22.0, 24.0, 22.0, 16.0, 7.0, -4.0, -12.0]
# 月份对应的季节
const MONTH_SEASONS := ["winter", "winter", "spring", "spring", "spring", "summer", "summer", "summer", "autumn", "autumn", "autumn", "winter"]
var current_month: int = 3  # 当前月份（0-11，对应1-12月，默认3月=春季开始）
var day_in_month: int = 1  # 当月第几天

var ambient_temperature: float = -2.0  # 默认3月温度
var _temp_random_mod: float = 0.0  # 温度随机波动（每分钟更新一次）
var _temp_random_timer: float = 0.0  # 温度随机波动计时器

# 天气系统
const WEATHER_TYPES := ["clear", "cloudy", "rain", "storm", "snow", "fog"]
const WEATHER_NAMES := {"clear": "晴朗", "cloudy": "多云", "rain": "小雨", "storm": "暴雨", "snow": "大雪", "fog": "大雾"}
# 天气效果配置
const WEATHER_EFFECTS := {
	"clear": {"visibility": 1.0, "move_speed": 1.0, "temp_mod": 0.0, "thirst_mod": 1.0, "zombie_speed": 1.0},
	"cloudy": {"visibility": 0.9, "move_speed": 1.0, "temp_mod": -2.0, "thirst_mod": 1.0, "zombie_speed": 1.0},
	"rain": {"visibility": 0.6, "move_speed": 0.8, "temp_mod": -5.0, "thirst_mod": 1.2, "zombie_speed": 0.9},
	"storm": {"visibility": 0.4, "move_speed": 0.6, "temp_mod": -8.0, "thirst_mod": 1.5, "zombie_speed": 0.8},
	"snow": {"visibility": 0.5, "move_speed": 0.7, "temp_mod": -10.0, "thirst_mod": 0.8, "zombie_speed": 0.6},
	"fog": {"visibility": 0.3, "move_speed": 0.9, "temp_mod": -1.0, "thirst_mod": 1.0, "zombie_speed": 1.1}
}
var weather: String = "clear"
var weather_timer: float = 0.0
var weather_duration: float = 120.0

# 特殊事件
const SPECIAL_EVENTS := {
	"heatwave": {"name": "热浪", "temp_mod": 8.0, "thirst_mod": 1.5, "food_rot_mod": 2.0},
	"coldwave": {"name": "寒潮", "temp_mod": -10.0, "hunger_mod": 1.3},
	"tornado": {"name": "龙卷风", "move_speed": 0.5},
	"blizzard": {"name": "暴风雪", "visibility": 0.3, "move_speed": 0.6, "temp_mod": -15.0, "zombie_speed": 0.5},
	"wildfire": {"name": "火灾", "visibility": 0.5}
}
var special_event: String = ""
var special_event_timer: float = 0.0

# 尸潮系统
var is_horde_active: bool = false
var horde_timer: float = 0.0
var horde_duration: float = 600.0  # 尸潮持续10分钟
var horde_spawn_timer: float = 0.0
var horde_zombies_spawned: int = 0
var horde_max_zombies: int = 600  # 尸潮最大丧尸数（大于500）
var next_horde_day: int = 40  # 第一次尸潮在第40天（1年）
const HORDE_INTERVAL_DAYS := 40  # 每40天（1年）一次尸潮

# 病毒传播系统
var lab_position: Vector2 = Vector2.ZERO  # 实验室位置
var infection_level: float = 0.0  # 感染程度 0.0-1.0（1.0=全图感染）
var infection_radius: float = 0.0  # 病毒扩散半径（从实验室向外扩散）
var _full_infection_notified: bool = false  # 全图感染提示是否已发送
var infection_spread_rate: float = 0.025  # 每天感染扩散速度（保留兼容）
var is_lab_destroyed: bool = false  # 实验室是否被摧毁
var lab_spawn_timer: float = 0.0  # 实验室僵尸刷新计时器（保留兼容）
var map_w: float = 6400.0  # 地图宽度（100瓦片*64像素）
var map_h: float = 6400.0  # 地图高度（100瓦片*64像素）

# ==================== 分块加载系统（参考僵尸毁灭工程） ====================
const CHUNK_SIZE := 1024.0  # 每个chunk大小（像素），16x16瓦片
const CHUNK_ACTIVATION_RANGE := 2  # 玩家周围激活的chunk范围（2=5x5=25个chunk）
var chunk_entities: Dictionary = {}  # 存储每个chunk的实体列表 {Vector2i: [Node, ...]}
var chunk_update_timer: float = 0.0  # chunk更新计时器
const CHUNK_UPDATE_INTERVAL := 0.5  # 每0.5秒更新一次chunk激活状态
var last_player_chunk: Vector2i = Vector2i(-999, -999)  # 上次玩家所在的chunk（用于检测是否需要更新）
var total_frozen_entities: int = 0  # 统计冻结的实体数量（调试用）
var total_active_entities: int = 0  # 统计激活的实体数量（调试用）

# 季节生存效果
const SEASON_EFFECTS := {
	"spring": {"hunger_mod": 1.0, "thirst_mod": 1.0, "stamina_regen": 1.0, "zombie_speed": 1.0},
	"summer": {"hunger_mod": 0.9, "thirst_mod": 1.5, "stamina_regen": 0.8, "zombie_speed": 1.1},
	"autumn": {"hunger_mod": 1.0, "thirst_mod": 0.9, "stamina_regen": 1.0, "zombie_speed": 1.0},
	"winter": {"hunger_mod": 1.2, "thirst_mod": 1.1, "stamina_regen": 0.7, "zombie_speed": 0.6}
}

# ==================== P1: 食物腐烂系统 ====================
var food_rot_timer: float = 0.0
const FOOD_ROT_INTERVAL := 30.0  # 每30秒检查一次食物腐烂


func _ready() -> void:
	# 设置斜45度视角的Y轴排序（Godot原生支持，稳定可靠）
	# 所有放在world_layer下的实体会自动按Y坐标排序，Y值大的在前面
	world_layer.y_sort_enabled = true
	print("[Main] 斜45度视角Y轴排序已启用（world_layer.y_sort_enabled = true）")
	# 初始化丧尸对象池（预加载100个普通丧尸，支持自动扩容）
	ObjectPool.init_pool("res://scenes/entities/zombie.tscn", 100, "zombie", true)
	print("[Main] 丧尸对象池已初始化（100个预加载，支持自动扩容）")
	# 立即显示加载界面
	if loading_screen:
		loading_screen.visible = true
	# 只隐藏有全屏半透明背景的UI（settings_menu/tech_tree_ui）
	# inventory_ui/craft_ui/build_ui/map_ui 只有Panel，没有全屏背景，保持可见以响应输入
	settings_menu.visible = false
	tech_tree_ui.visible = false
	print("[Main] UI初始化完成")
	# 注册游戏世界到GameManager
	GameManager.set_game_world(world_layer)
	# 把所有UI移到HUD的CanvasLayer里，固定在屏幕上不跟随相机
	inventory_ui.reparent(hud)
	quickbar.reparent(hud)
	# 确保快捷栏可见并在屏幕底部中央（1920x1080分辨率）
	quickbar.visible = true
	quickbar.anchor_left = 0.5
	quickbar.anchor_top = 1.0
	quickbar.anchor_right = 0.5
	quickbar.anchor_bottom = 1.0
	quickbar.offset_left = -300.0
	quickbar.offset_top = -75.0
	quickbar.offset_right = 300.0
	quickbar.offset_bottom = -5.0
	print("[Main] 快捷栏已reparent到HUD，visible=", quickbar.visible, " size=", quickbar.size, " pos=", quickbar.position)
	craft_ui.reparent(hud)
	build_ui.reparent(hud)
	map_ui.reparent(hud)
	settings_menu.reparent(hud)
	tech_tree_ui.reparent(hud)
	# 加载界面也reparent到HUD，并确保在最上层
	if loading_screen:
		loading_screen.reparent(hud)
		loading_screen.z_index = 100
		loading_screen.visible = true
		print("[Main] 加载界面已reparent到HUD，z_index=100")
	# 动态创建人物属性UI
	var char_scene: PackedScene = load("res://scenes/ui/character_ui.tscn")
	if char_scene:
		character_ui = char_scene.instantiate()
		character_ui.name = "CharacterUI"
		hud.add_child(character_ui)
		print("[Main] 人物属性UI已创建")
	# 动态创建调试控制台
	var console_script: Script = load("res://scripts/ui/debug_console.gd")
	if console_script:
		debug_console = CanvasLayer.new()
		debug_console.name = "DebugConsole"
		debug_console.set_script(console_script)
		hud.add_child(debug_console)
		print("[Main] 调试控制台已创建，按Enter聊天，输入 /help 查看命令")
	# 主机或单人游戏生成初始资源（改为异步加载，显示真实进度）
	if GameManager.is_server or multiplayer.multiplayer_peer == null:
		if not GameManager.is_server:
			GameManager.is_server = true
			print("[Main] 单人游戏模式，强制设置is_server=true")
		# 异步分阶段加载，显示真实进度
		call_deferred("_async_loading")
	# 连接聊天信号
	GameManager.chat_received.connect(_on_chat_received)
	# 连接InputManager的action_pressed信号，处理ESC键（更可靠，不受其他UI拦截影响）
	if InputManager and InputManager.has_signal("action_pressed"):
		InputManager.action_pressed.connect(_on_input_action_pressed)
		print("[Main] 已连接InputManager的action_pressed信号")


func _async_loading() -> void:
	## 分阶段加载，显示真实进度（同步版本，避免get_tree()为null的问题）
	print("[Loading] ===== 开始加载 =====")
	# 显示加载界面
	if loading_screen:
		loading_screen.visible = true
		loading_screen.z_index = 100
		if loading_screen.has_method("set_progress"):
			loading_screen.set_progress(0, "初始化游戏引擎...")
	
	# 阶段1：初始化（5%）
	_update_loading_progress(5, "初始化游戏引擎...")
	
	# 阶段2：等待地图生成（25%）
	_update_loading_progress(15, "生成世界地图...")
	# 检查等距地图是否已生成
	var map_node: Node = get_node_or_null("IsometricMap")
	if map_node and map_node.has_method("is_ready"):
		var wait_count: int = 0
		while not map_node.is_ready() and wait_count < 100:
			wait_count += 1
			_update_loading_progress(15 + min(wait_count, 10), "生成世界地图...")
	_update_loading_progress(25, "世界地图生成完成")
	
	# 阶段3：生成实验室（40%）
	_update_loading_progress(30, "放置实验室和病毒源头...")
	_generate_lab_only()
	_update_loading_progress(40, "实验室放置完成")
	
	# 阶段4：生成资源（55%）
	_update_loading_progress(45, "生成资源节点（树木/石头/浆果）...")
	_generate_resources_only()
	_update_loading_progress(55, "资源节点生成完成")
	
	# 阶段5：生成载具（70%）
	_update_loading_progress(60, "生成废弃载具残骸...")
	_generate_vehicles_only()
	_update_loading_progress(70, "载具生成完成")
	
	# 阶段6：生成NPC（85%）
	_update_loading_progress(75, "生成人类NPC...")
	_generate_npcs_only()
	_update_loading_progress(85, "NPC生成完成")
	
	# 阶段7：初始化玩家（95%）
	_update_loading_progress(90, "初始化玩家和职业系统...")
	_update_loading_progress(95, "玩家初始化完成")
	
	# 阶段8：完成（100%）
	_update_loading_progress(100, "准备就绪，幸存者加油！")
	
	# 隐藏加载界面
	if loading_screen:
		loading_screen.visible = false
	print("[Loading] ===== 加载完成 =====")


func _update_loading_progress(progress: float, stage_text: String) -> void:
	## 更新加载进度
	if loading_screen and loading_screen.has_method("set_progress"):
		loading_screen.set_progress(progress, stage_text)
	print("[Loading] ", int(progress), "% - ", stage_text)


func _generate_lab_only() -> void:
	## 只生成实验室
	if USE_FIXED_MAP:
		return
	# 顶视角地图中心和范围（400x300瓦片，64x64像素）
	map_w = 400.0 * 64.0
	map_h = 300.0 * 64.0
	var center_x: float = map_w / 2.0
	var center_y: float = map_h / 2.0
	# 检查是否已经有实验室存在
	var existing_labs: Array = []
	if get_tree():
		existing_labs = get_tree().get_nodes_in_group("laboratory")
	if existing_labs.size() > 0:
		print("[Virus] 已存在实验室，跳过生成")
		return
	var edge_margin: float = 400.0
	var edge_side: int = randi() % 4
	match edge_side:
		0:
			var t: float = randf()
			lab_position = Vector2(lerp(-6368 + edge_margin, 6368 - edge_margin, t), lerp(3184 - edge_margin, edge_margin, abs(t - 0.5) * 2))
		1:
			var t2: float = randf()
			lab_position = Vector2(lerp(-6368 + edge_margin, 6368 - edge_margin, t2), lerp(3184 + edge_margin, 6368 - edge_margin, abs(t2 - 0.5) * 2))
		2:
			lab_position = Vector2(-6368 + edge_margin, randf_range(edge_margin, 6368 - edge_margin))
		3:
			lab_position = Vector2(6368 - edge_margin, randf_range(edge_margin, 6368 - edge_margin))
	print("[Virus] 实验室位置：", lab_position, " 边：", edge_side)
	# 暂时使用building.tscn生成实验室（确保加载不卡住）
	var lab_building: Node2D = BUILDING_SCENE.instantiate()
	lab_building.building_id = "laboratory"
	lab_building.position = lab_position
	lab_building.name = "Laboratory"
	lab_building.add_to_group("laboratory")
	world_layer.add_child(lab_building)
	lab_building.call_deferred("set_building_complete")
	print("[Virus] 实验室建筑已创建（使用building.tscn），全地图唯一")


func _generate_resources_only() -> void:
	## 只生成资源（树木/石头/浆果）
	var center_x: float = 0.0
	var center_y: float = (100.0 + 100.0) * 32.0 / 2.0
	var range_x: float = 5600.0
	var range_y: float = 2800.0
	# 生成随机树木
	for i in range(200):
		var tree: Node2D = TREE_SCENE.instantiate()
		tree.position = Vector2(center_x + randf_range(-range_x, range_x), center_y + randf_range(-range_y, range_y))
		world_layer.add_child(tree)
		_register_chunk_entity(tree)
	# 生成随机石头
	for i in range(100):
		var rock: Node2D = ROCK_SCENE.instantiate()
		rock.position = Vector2(center_x + randf_range(-range_x, range_x), center_y + randf_range(-range_y, range_y))
		world_layer.add_child(rock)
		_register_chunk_entity(rock)
	# 生成浆果丛
	for i in range(60):
		var berry: Node2D = BERRY_SCENE.instantiate()
		berry.position = Vector2(center_x + randf_range(-range_x, range_x), center_y + randf_range(-range_y, range_y))
		world_layer.add_child(berry)
		_register_chunk_entity(berry)
	# 出生点附近额外资源
	for i in range(30):
		var tree2: Node2D = TREE_SCENE.instantiate()
		tree2.position = Vector2(center_x + randf_range(-400, 400), center_y + randf_range(-400, 400))
		world_layer.add_child(tree2)
		_register_chunk_entity(tree2)
	for i in range(15):
		var rock2: Node2D = ROCK_SCENE.instantiate()
		rock2.position = Vector2(center_x + randf_range(-400, 400), center_y + randf_range(-400, 400))
		world_layer.add_child(rock2)
		_register_chunk_entity(rock2)
	for i in range(10):
		var berry2: Node2D = BERRY_SCENE.instantiate()
		berry2.position = Vector2(center_x + randf_range(-400, 400), center_y + randf_range(-400, 400))
		world_layer.add_child(berry2)
		_register_chunk_entity(berry2)
	print("[World] 生成了230树木, 115石头, 70浆果")


func _generate_vehicles_only() -> void:
	## 只生成载具
	var center_x: float = 0.0
	var center_y: float = (100.0 + 100.0) * 32.0 / 2.0
	var range_x: float = 5600.0
	var range_y: float = 2800.0
	var vehicle_types: Array = ["bicycle", "motorcycle", "car", "truck", "armored"]
	for i in range(15):
		var vehicle: Node2D = VEHICLE_SCENE.instantiate()
		vehicle.vehicle_type = vehicle_types[randi() % vehicle_types.size()]
		vehicle.is_wreck = true
		vehicle.position = Vector2(center_x + randf_range(-range_x, range_x), center_y + randf_range(-range_y, range_y))
		world_layer.add_child(vehicle)
		_register_chunk_entity(vehicle)
	print("[World] 生成了15辆废弃载具残骸")


func _generate_npcs_only() -> void:
	## 只生成NPC
	var center_x: float = 0.0
	var center_y: float = (100.0 + 100.0) * 32.0 / 2.0
	var range_x: float = 5600.0
	var range_y: float = 2800.0
	for i in range(500):
		var npc: Node2D = NPC_SCENE.instantiate()
		npc.npc_type = "civilian"
		npc.position = Vector2(center_x + randf_range(-range_x, range_x), center_y + randf_range(-range_y, range_y))
		world_layer.add_child(npc)
		_register_chunk_entity(npc)
	for i in range(80):
		var police: Node2D = NPC_SCENE.instantiate()
		police.npc_type = "police"
		police.position = Vector2(center_x + randf_range(-range_x, range_x), center_y + randf_range(-range_y, range_y))
		world_layer.add_child(police)
		_register_chunk_entity(police)
	print("[World] 生成了500市民, 80警察")


func _process(delta: float) -> void:
	if game_over:
		return
	# 分块加载系统更新（每隔0.5秒）
	chunk_update_timer += delta
	if chunk_update_timer >= CHUNK_UPDATE_INTERVAL:
		chunk_update_timer = 0.0
		_update_chunks()
	if GameManager.is_server:
		_update_day_night(delta)
		_update_zombie_spawn(delta)
		_update_season_weather(delta)
		_update_food_rot(delta)
		_update_horde(delta)
		_update_infection(delta)
		_check_game_over()
	# 更新玩家体温
	_update_player_temperature(delta)
	# 连接本地玩家背包到UI
	if not inventory_ui_connected:
		_connect_inventory_ui()


func _update_season_weather(delta: float) -> void:
	# 天气计时
	weather_timer -= delta
	if weather_timer <= 0:
		weather_timer = weather_duration
		_change_weather()
	# 特殊事件计时
	if special_event_timer > 0:
		special_event_timer -= delta
		if special_event_timer <= 0:
			special_event = ""
			print("[Weather] 特殊事件结束")
	# 应用天气和季节效果到玩家
	_apply_weather_effects(delta)


func _apply_weather_effects(delta: float) -> void:
	# 获取当前天气效果
	var weather_eff: Dictionary = WEATHER_EFFECTS.get(weather, WEATHER_EFFECTS["clear"])
	var season_eff: Dictionary = SEASON_EFFECTS.get(season, SEASON_EFFECTS["spring"])
	var player: Node = GameManager.get_local_player()
	if not player or not is_instance_valid(player):
		return
	# 应用移动速度修正
	var move_mod: float = weather_eff.get("move_speed", 1.0)
	if special_event != "":
		var event_eff: Dictionary = SPECIAL_EVENTS.get(special_event, {})
		move_mod *= event_eff.get("move_speed", 1.0)
	if player.has_method("set_move_speed_modifier"):
		player.set_move_speed_modifier(move_mod)
	# 应用口渴和饥饿修正（在玩家属性更新中处理）
	if player.has_method("set_survival_modifiers"):
		var thirst_mod: float = weather_eff.get("thirst_mod", 1.0) * season_eff.get("thirst_mod", 1.0)
		var hunger_mod: float = season_eff.get("hunger_mod", 1.0)
		var stamina_mod: float = season_eff.get("stamina_regen", 1.0)
		if special_event != "":
			var event_eff2: Dictionary = SPECIAL_EVENTS.get(special_event, {})
			thirst_mod *= event_eff2.get("thirst_mod", 1.0)
			hunger_mod *= event_eff2.get("hunger_mod", 1.0)
		player.set_survival_modifiers(hunger_mod, thirst_mod, stamina_mod)


func _change_weather() -> void:
	# 根据季节选择天气
	var possible_weather: Array = ["clear", "clear", "cloudy"]
	match season:
		"spring":
			possible_weather += ["rain", "rain", "fog"]
		"summer":
			possible_weather += ["rain", "storm", "storm"]
		"autumn":
			possible_weather += ["rain", "fog", "fog"]
		"winter":
			possible_weather += ["snow", "snow", "fog"]
	weather = possible_weather[randi() % possible_weather.size()]
	weather_duration = randf_range(60.0, 180.0)
	print("[Weather] 天气变为: %s，持续%.0f秒" % [WEATHER_NAMES[weather], weather_duration])
	# 小概率触发特殊事件
	if randf() < 0.08:
		_trigger_special_event()


func _trigger_special_event() -> void:
	# 根据季节选择特殊事件
	var events: Array = []
	match season:
		"spring":
			events = ["tornado", "coldwave"]
		"summer":
			events = ["heatwave", "wildfire", "tornado"]
		"autumn":
			events = ["tornado", "coldwave"]
		"winter":
			events = ["blizzard", "coldwave"]
	if events.size() == 0:
		return
	special_event = events[randi() % events.size()]
	special_event_timer = randf_range(30.0, 90.0)
	var event_data: Dictionary = SPECIAL_EVENTS.get(special_event, {})
	var event_name: String = event_data.get("name", special_event)
	print("[Weather] 特殊事件: %s！" % event_name)
	GameManager.send_chat.rpc("警告：%s来袭！" % event_name)
	# 播放特殊事件音效
	if AudioManager:
		AudioManager.play_sfx(AudioManager.SFX.ERROR)


func _on_day_changed() -> void:
	# 新的一天，更新月份和季节
	day_in_month += 1
	day_in_season += 1
	# 检查是否进入下一个月
	if day_in_month > MONTH_DAYS[current_month]:
		day_in_month = 1
		current_month = (current_month + 1) % 12
		# 更新季节
		var new_season: String = MONTH_SEASONS[current_month]
		if new_season != season:
			season = new_season
			day_in_season = 1
			print("[Season] 季节变为: %s" % SEASON_NAMES[season])
			GameManager.send_chat.rpc("%s来了！" % SEASON_NAMES[season])
			if AudioManager:
				AudioManager.play_sfx(AudioManager.SFX.SUCCESS)
		print("[Month] 月份变为: %s, 平均温度: %.0f°C" % [MONTH_NAMES[current_month], MONTH_TEMPS[current_month]])
		GameManager.send_chat.rpc("进入%s，平均温度%.0f°C" % [MONTH_NAMES[current_month], MONTH_TEMPS[current_month]])
	# 季节天数检查（兼容旧逻辑）
	if day_in_season > SEASON_LENGTH:
		day_in_season = 1
	# 自动存档（每天结束时）
	if SaveManager:
		SaveManager.save_game(SaveManager.current_slot, self)
		print("[Save] 第%d天结束，自动存档完成" % day_count)
	# 更新环境温度（基础温度+昼夜修正）
	_update_ambient_temperature()


func manual_save(slot: int = -1) -> bool:
	## 手动存档
	if not SaveManager:
		return false
	if slot < 0:
		slot = SaveManager.current_slot
	var result: bool = SaveManager.save_game(slot, self)
	if result:
		GameManager.send_chat.rpc("游戏已保存到存档位 %d" % (slot + 1))
		if AudioManager:
			AudioManager.play_sfx(AudioManager.SFX.SUCCESS)
	return result


func _update_ambient_temperature() -> void:
	# 基础温度由月份决定（长春实际月平均气温）
	var base_temp: float = MONTH_TEMPS[current_month]
	# 昼夜修正：正弦波平滑过渡（长春昼夜温差约10°C）
	# current_time: 0.0=黎明, 0.5=正午, 1.0=次日黎明
	# 正午最高，午夜最低
	var day_night_mod: float = 0.0
	if season == "winter":
		# 长春冬天：白天+5，夜晚-5，温差10°C
		day_night_mod = 0.0 + 5.0 * sin(PI * current_time)
	elif season == "summer":
		# 长春夏天：白天+6，夜晚-4，温差10°C
		day_night_mod = 1.0 + 5.0 * sin(PI * current_time)
	else:
		# 长春春秋：白天+5，夜晚-5，温差10°C
		day_night_mod = 0.0 + 5.0 * sin(PI * current_time)
	# 天气修正
	var weather_eff: Dictionary = WEATHER_EFFECTS.get(weather, {})
	var weather_mod: float = weather_eff.get("temp_mod", 0.0)
	# 特殊事件修正
	var event_mod: float = 0.0
	if special_event != "":
		var event_eff: Dictionary = SPECIAL_EVENTS.get(special_event, {})
		event_mod = event_eff.get("temp_mod", 0.0)
	# 随机波动（每分钟更新一次，幅度±2°C，符合长春天气波动）
	_temp_random_timer -= get_process_delta_time()
	if _temp_random_timer <= 0:
		_temp_random_timer = 60.0  # 每分钟更新一次
		_temp_random_mod = randf_range(-2.0, 2.0)
	# 计算目标温度
	var target_temp: float = base_temp + day_night_mod + weather_mod + event_mod + _temp_random_mod
	# 平滑过渡：每秒最多变化0.3°C（防止温度突变）
	var temp_diff: float = target_temp - ambient_temperature
	var max_change: float = 0.3 * get_process_delta_time()
	if abs(temp_diff) < max_change:
		ambient_temperature = target_temp
	else:
		ambient_temperature += sign(temp_diff) * max_change


func _update_player_temperature(delta: float) -> void:
	# 每帧更新环境温度（昼夜变化）
	_update_ambient_temperature()
	var player: Node = GameManager.get_local_player()
	if player and is_instance_valid(player) and player.has_method("update_temperature"):
		player.update_temperature(delta, ambient_temperature)


func _update_food_rot(delta: float) -> void:
	food_rot_timer -= delta
	if food_rot_timer > 0:
		return
	food_rot_timer = FOOD_ROT_INTERVAL
	# 检查所有玩家背包里的食物
	for pid: int in GameManager.players.keys():
		var p: Node = GameManager.players[pid]
		if is_instance_valid(p) and p.inventory:
			if p.inventory.has_method("update_food_rot"):
				p.inventory.update_food_rot(season, weather)


func _update_zombie_spawn(delta: float) -> void:
	# 病毒全图感染前，不随机刷新丧尸（只有感染NPC转变的丧尸）
	if infection_level < 1.0:
		return
	# 实验室已被摧毁，停止刷新
	if is_lab_destroyed:
		return
	zombie_spawn_timer -= delta
	if zombie_spawn_timer > 0:
		return
	# 统计当前丧尸数量
	var zombie_count := 0
	for child in world_layer.get_children():
		if child.is_in_group("zombie") or child.name.begins_with("Zombie"):
			zombie_count += 1
	if zombie_count >= MAX_ZOMBIES:
		zombie_spawn_timer = ZOMBIE_SPAWN_INTERVAL
		return
	# 夜晚生成更快
	var is_night := current_time < 0.2 or current_time > 0.8
	zombie_spawn_timer = 3.0 if is_night else ZOMBIE_SPAWN_INTERVAL
	_spawn_zombie_from_lab()


func _spawn_zombie_from_lab() -> void:
	# 从实验室附近生成丧尸，向周围扩散
	var angle: float = randf() * TAU
	var distance: float = randf_range(50, 150)
	var spawn_pos: Vector2 = lab_position + Vector2(cos(angle), sin(angle)) * distance
	# 从对象池获取丧尸
	var zombie = ObjectPool.acquire("zombie")
	if zombie == null:
		print("[Main] 警告：无法从对象池获取丧尸")
		return
	zombie.position = spawn_pos
	zombie.name = "LabZombie_%d" % randi()
	# 实验室丧尸更强大，随机类型
	if zombie.has_method("set_zombie_type"):
		var types: Array = ["normal", "fast", "fat", "spitter"]
		zombie.set_zombie_type(types[randi() % types.size()])
	world_layer.add_child(zombie)
	zombie.add_to_group("zombie")
	# 注册到分块加载系统
	_register_chunk_entity(zombie)


# ==================== 尸潮系统 ====================
func _update_horde(delta: float) -> void:
	# 检查是否到了尸潮时间
	if not is_horde_active and day_count >= next_horde_day:
		_start_horde()
		return
	# 尸潮进行中
	if is_horde_active:
		horde_timer -= delta
		# 生成丧尸
		horde_spawn_timer -= delta
		if horde_spawn_timer <= 0 and horde_zombies_spawned < horde_max_zombies:
			horde_spawn_timer = 0.8  # 每0.8秒生成一只
			_spawn_horde_zombie()
		# 尸潮结束
		if horde_timer <= 0:
			_end_horde()


func _start_horde() -> void:
	is_horde_active = true
	horde_timer = horde_duration
	horde_spawn_timer = 0.0
	horde_zombies_spawned = 0
	# 尸潮规模随天数增加（基础500，每10天增加50）
	horde_max_zombies = 500 + int(day_count / 10) * 50
	print("[Horde] 尸潮来袭！持续%.0f秒，最多%d只丧尸" % [horde_duration, horde_max_zombies])
	GameManager.send_chat.rpc("警告：尸潮来袭！准备防御！")
	if AudioManager:
		AudioManager.play_sfx(AudioManager.SFX.ERROR)


func _end_horde() -> void:
	is_horde_active = false
	next_horde_day = day_count + HORDE_INTERVAL_DAYS
	print("[Horde] 尸潮结束，下一次在第%d天" % next_horde_day)
	GameManager.send_chat.rpc("尸潮已结束，幸存者们胜利了！")
	if AudioManager:
		AudioManager.play_sfx(AudioManager.SFX.SUCCESS)


func _spawn_horde_zombie() -> void:
	# 从地图边缘生成尸潮丧尸，向玩家基地进攻
	var players: Array = []
	for pid: int in GameManager.players.keys():
		var p: Node2D = GameManager.players[pid]
		if is_instance_valid(p):
			players.append(p)
	if players.is_empty():
		return
	var target_player: Node2D = players[randi() % players.size()]
	# 从更远的地方生成（500-800像素）
	var angle: float = randf() * TAU
	var distance: float = randf_range(500, 800)
	var spawn_pos: Vector2 = target_player.position + Vector2(cos(angle), sin(angle)) * distance
	# 从对象池获取丧尸
	var zombie = ObjectPool.acquire("zombie")
	if zombie == null:
		print("[Main] 警告：无法从对象池获取尸潮丧尸")
		return
	zombie.position = spawn_pos
	zombie.name = "HordeZombie_%d" % randi()
	# 尸潮丧尸更强大
	if zombie.has_method("set_zombie_type"):
		# 随机选择丧尸类型，快速丧尸更多
		var types: Array = ["normal", "normal", "fast", "fast", "fat"]
		zombie.set_zombie_type(types[randi() % types.size()])
	world_layer.add_child(zombie)
	zombie.add_to_group("zombie")
	horde_zombies_spawned += 1


# ==================== 病毒传播系统 ====================
func _update_infection(delta: float) -> void:
	# 如果实验室已被摧毁，停止感染扩散
	if is_lab_destroyed:
		return
	# 病毒从实验室向外扩散，扩散半径随时间增加（游戏内30天扩散到全图）
	# 地图最大距离约为 sqrt(map_w^2 + map_h^2) / 2
	var max_radius: float = sqrt(map_w * map_w + map_h * map_h) / 2.0
	infection_radius = min(max_radius, infection_radius + (max_radius / 30.0) * delta / day_length)
	infection_level = infection_radius / max_radius  # 感染程度用于UI显示
	# 感染扩散半径内的NPC
	if infection_radius > 100:
		_infect_npcs(delta)
	# 感染达到50%时提示玩家
	if infection_level >= 0.5 and infection_level < 0.51:
		GameManager.send_chat.rpc("空气中弥漫着不祥的气息...病毒正在从实验室蔓延")
	# 全图感染后提示
	if infection_level >= 1.0 and not _full_infection_notified:
		_full_infection_notified = true
		GameManager.send_chat.rpc("病毒已扩散至全图！所有未撤离的人类都将被感染")


func _infect_npcs(delta: float) -> void:
	## 感染实验室扩散半径内的NPC
	if not world_layer:
		return
	# 基础感染概率（距离实验室越近，概率越高）
	var base_infect_chance: float = 0.0005 * delta
	for child in world_layer.get_children():
		if child.is_in_group("npc") and not child.is_infected:
			# 只感染在扩散半径内的NPC
			var dist_to_lab: float = child.position.distance_to(lab_position)
			if dist_to_lab > infection_radius:
				continue
			# 距离实验室越近，感染概率越高（半径边缘概率为0，中心概率最高）
			var dist_factor: float = 1.0 - (dist_to_lab / infection_radius)
			dist_factor = clamp(dist_factor, 0.1, 1.0)
			if randf() < base_infect_chance * dist_factor:
				child.infect()


func destroy_lab() -> void:
	## 摧毁实验室，通关游戏
	is_lab_destroyed = true
	print("[Virus] 实验室已被摧毁，病毒停止传播")
	GameManager.send_chat.rpc("实验室已被摧毁！病毒停止传播，你们拯救了世界！")
	if AudioManager:
		AudioManager.play_sfx(AudioManager.SFX.SUCCESS)


func enter_lab_dungeon(lab_building: Node2D) -> void:
	## 玩家进入实验室副本
	print("[Main] 玩家进入实验室副本")
	# 保存当前世界状态（用于返回）
	# 切换到副本场景
	get_tree().change_scene_to_file("res://scenes/world/lab_dungeon.tscn")


# ==================== 分块加载系统（参考僵尸毁灭工程） ====================
func _get_chunk_coord(position: Vector2) -> Vector2i:
	## 获取世界坐标对应的chunk坐标
	return Vector2i(int(position.x / CHUNK_SIZE), int(position.y / CHUNK_SIZE))


func _register_chunk_entity(entity: Node) -> void:
	## 注册实体到分块加载系统（NPC、僵尸、资源节点、载具等）
	if not entity or not is_instance_valid(entity):
		return
	var chunk_coord: Vector2i = _get_chunk_coord(entity.position)
	if not chunk_entities.has(chunk_coord):
		chunk_entities[chunk_coord] = []
	chunk_entities[chunk_coord].append(entity)
	# 延迟一帧设置初始状态，确保实体_ready先执行（纹理生成）
	call_deferred("_set_entity_chunk_state", entity, chunk_coord)


func _set_entity_chunk_state(entity: Node, chunk_coord: Vector2i) -> void:
	## 延迟设置实体的初始分块状态（确保_ready先执行）
	if not entity or not is_instance_valid(entity):
		return
	var player: Node = GameManager.get_local_player()
	if player:
		var player_chunk: Vector2i = _get_chunk_coord(player.position)
		if _is_chunk_active(chunk_coord.x, chunk_coord.y, player_chunk):
			entity.process_mode = Node.PROCESS_MODE_INHERIT
		else:
			entity.process_mode = Node.PROCESS_MODE_DISABLED
	else:
		entity.process_mode = Node.PROCESS_MODE_INHERIT


func _unregister_chunk_entity(entity: Node) -> void:
	## 从分块加载系统移除实体（实体被销毁时调用）
	if not entity:
		return
	for key in chunk_entities.keys():
		var entities: Array = chunk_entities[key]
		if entities.has(entity):
			entities.erase(entity)
			if entities.is_empty():
				chunk_entities.erase(key)
			break


func _is_chunk_active(chunk_x: int, chunk_y: int, player_chunk: Vector2i) -> bool:
	## 检查chunk是否在玩家激活范围内
	return abs(chunk_x - player_chunk.x) <= CHUNK_ACTIVATION_RANGE and abs(chunk_y - player_chunk.y) <= CHUNK_ACTIVATION_RANGE


func _update_chunks() -> void:
	## 更新所有chunk的激活状态（冻结远处实体，激活附近实体）
	var player: Node = GameManager.get_local_player()
	if not player or not is_instance_valid(player):
		return
	var player_chunk: Vector2i = _get_chunk_coord(player.position)
	last_player_chunk = player_chunk
	total_active_entities = 0
	total_frozen_entities = 0
	# 遍历所有chunk，更新实体状态
	for chunk_coord in chunk_entities.keys():
		var entities: Array = chunk_entities[chunk_coord]
		var is_active: bool = _is_chunk_active(chunk_coord.x, chunk_coord.y, player_chunk)
		for entity in entities:
			if not entity or not is_instance_valid(entity):
				continue
			if is_active:
				if entity.process_mode != Node.PROCESS_MODE_INHERIT:
					entity.process_mode = Node.PROCESS_MODE_INHERIT
				total_active_entities += 1
			else:
				if entity.process_mode != Node.PROCESS_MODE_DISABLED:
					entity.process_mode = Node.PROCESS_MODE_DISABLED
				total_frozen_entities += 1
	print("[Chunk] 玩家在chunk(%d,%d)，激活%d个实体，冻结%d个实体" % [player_chunk.x, player_chunk.y, total_active_entities, total_frozen_entities])


func _update_day_night(delta: float) -> void:
	current_time += delta / day_length
	if current_time >= 1.0:
		current_time = 0.0
		day_count += 1
		_on_day_changed()  # 新的一天，更新季节
	# 判断白天/夜晚 (0.25-0.75为白天)
	var was_night := is_night
	is_night = current_time < 0.2 or current_time > 0.8
	if was_night != is_night:
		if is_night:
			GameManager.send_chat.rpc("夜幕降临了，小心丧尸！")
		else:
			GameManager.send_chat.rpc("天亮了，第%d天开始" % day_count)


func _load_fixed_map() -> void:
	## 加载固定地图场景（玩家在编辑器中手动设计）
	print("[FixedMap] 正在加载固定地图...")
	map_w = 50.0 * 64.0
	map_h = 50.0 * 64.0
	# 加载固定地图场景
	fixed_map = FIXED_MAP_SCENE.instantiate()
	fixed_map.name = "FixedMap"
	world_layer.add_child(fixed_map)
	# 注册所有实体到分块加载系统
	var entities: Array = fixed_map.get_all_entities()
	for entity in entities:
		_register_chunk_entity(entity)
	print("[FixedMap] 已注册%d个实体到分块加载系统" % entities.size())
	# 获取实验室位置
	lab_position = fixed_map.get_laboratory_position()
	if lab_position == Vector2.ZERO:
		print("[FixedMap] 警告：固定地图中没有放置实验室！病毒传播系统将无法正常工作。")
	else:
		print("[FixedMap] 实验室位置：", lab_position)
	print("[FixedMap] 固定地图加载完成！")


func _generate_initial_resources() -> void:
	# 如果使用固定地图，加载固定地图场景并注册实体
	if USE_FIXED_MAP:
		_load_fixed_map()
		return
	# 顶视角地图中心和范围（400x300瓦片，瓦片64x64）
	map_w = 400.0 * 64.0
	map_h = 300.0 * 64.0
	var center_x: float = map_w / 2.0  # 顶视角地图x中心
	var center_y: float = map_h / 2.0  # 顶视角地图y中心
	var range_x: float = map_w / 2.0  # 顶视角地图x范围
	var range_y: float = map_h / 2.0  # 顶视角地图y范围
	# 生成实验室位置（全图唯一，随机出现在地图四条边的附近）
	# 先检查是否已经有实验室存在，防止重复生成
	var existing_labs: Array = get_tree().get_nodes_in_group("laboratory")
	if existing_labs.size() > 0:
		print("[Virus] 已存在实验室，跳过生成")
		return
	var edge_margin: float = 400.0  # 距离边缘的距离
	var edge_side: int = randi() % 4  # 0=上边(顶部), 1=下边(底部), 2=左边, 3=右边
	# 等距地图是菱形，四个顶点：顶(0,0)、右(6368,3184)、底(0,6368)、左(-6368,3184)
	match edge_side:
		0:  # 上边（顶部顶点附近，沿着上边分布）
			var t: float = randf()
			lab_position = Vector2(lerp(-6368 + edge_margin, 6368 - edge_margin, t), lerp(3184 - edge_margin, edge_margin, abs(t - 0.5) * 2))
		1:  # 下边（底部顶点附近，沿着下边分布）
			var t2: float = randf()
			lab_position = Vector2(lerp(-6368 + edge_margin, 6368 - edge_margin, t2), lerp(3184 + edge_margin, 6368 - edge_margin, abs(t2 - 0.5) * 2))
		2:  # 左边（左部顶点附近）
			lab_position = Vector2(-6368 + edge_margin, randf_range(edge_margin, 6368 - edge_margin))
		3:  # 右边（右部顶点附近）
			lab_position = Vector2(6368 - edge_margin, randf_range(edge_margin, 6368 - edge_margin))
	print("[Virus] 实验室位置（边缘附近）：", lab_position, " 边：", edge_side)
	# 暂时使用building.tscn生成实验室（确保加载不卡住）
	var lab_building: Node2D = BUILDING_SCENE.instantiate()
	lab_building.building_id = "laboratory"
	lab_building.position = lab_position
	lab_building.name = "Laboratory"
	lab_building.add_to_group("laboratory")
	world_layer.add_child(lab_building)
	lab_building.call_deferred("set_building_complete")
	print("[Virus] 实验室建筑已创建（使用building.tscn），全地图唯一")
	# 生成随机树木（增加数量）
	for i in range(200):
		var tree: Node2D = TREE_SCENE.instantiate()
		tree.position = Vector2(center_x + randf_range(-range_x, range_x), center_y + randf_range(-range_y, range_y))
		world_layer.add_child(tree)
		_register_chunk_entity(tree)
	# 生成随机石头（增加数量）
	for i in range(100):
		var rock: Node2D = ROCK_SCENE.instantiate()
		rock.position = Vector2(center_x + randf_range(-range_x, range_x), center_y + randf_range(-range_y, range_y))
		world_layer.add_child(rock)
		_register_chunk_entity(rock)
	# 生成浆果丛（增加数量）
	for i in range(60):
		var berry: Node2D = BERRY_SCENE.instantiate()
		berry.position = Vector2(center_x + randf_range(-range_x, range_x), center_y + randf_range(-range_y, range_y))
		world_layer.add_child(berry)
		_register_chunk_entity(berry)
	# 生成废弃载具残骸（15辆，分布在地图各处）
	var vehicle_types: Array = ["bicycle", "motorcycle", "car", "truck", "armored"]
	for i in range(15):
		var vehicle: Node2D = VEHICLE_SCENE.instantiate()
		vehicle.vehicle_type = vehicle_types[randi() % vehicle_types.size()]
		vehicle.is_wreck = true
		vehicle.position = Vector2(center_x + randf_range(-range_x, range_x), center_y + randf_range(-range_y, range_y))
		world_layer.add_child(vehicle)
		_register_chunk_entity(vehicle)
	print("[World] 生成了15辆废弃载具残骸")
	# 生成人类NPC（大量增加：500个市民，80个警察，分布在地图各处）
	for i in range(500):
		var npc: Node2D = NPC_SCENE.instantiate()
		npc.npc_type = "civilian"
		npc.position = Vector2(center_x + randf_range(-range_x, range_x), center_y + randf_range(-range_y, range_y))
		world_layer.add_child(npc)
		_register_chunk_entity(npc)
	for i in range(80):
		var police: Node2D = NPC_SCENE.instantiate()
		police.npc_type = "police"
		police.position = Vector2(center_x + randf_range(-range_x, range_x), center_y + randf_range(-range_y, range_y))
		world_layer.add_child(police)
		_register_chunk_entity(police)
	print("[World] 生成了500个市民和80个警察")
	# 在玩家出生点附近额外生成一些资源，确保玩家一开始就能看到
	for i in range(30):
		var tree: Node2D = TREE_SCENE.instantiate()
		tree.position = Vector2(center_x + randf_range(-400, 400), center_y + randf_range(-400, 400))
		world_layer.add_child(tree)
		_register_chunk_entity(tree)
	for i in range(15):
		var rock: Node2D = ROCK_SCENE.instantiate()
		rock.position = Vector2(center_x + randf_range(-400, 400), center_y + randf_range(-400, 400))
		world_layer.add_child(rock)
		_register_chunk_entity(rock)
	for i in range(10):
		var berry: Node2D = BERRY_SCENE.instantiate()
		berry.position = Vector2(center_x + randf_range(-400, 400), center_y + randf_range(-400, 400))
		world_layer.add_child(berry)
		_register_chunk_entity(berry)
	print("[World] Generated initial resources: 230树木, 115石头, 70浆果")


func _on_chat_received(peer_id: int, message: String) -> void:
	pass  # HUD会处理显示


func _check_game_over() -> void:
	# 检查所有玩家是否都倒地
	var players: Array = []
	for pid: int in GameManager.players.keys():
		var p: CharacterBody2D = GameManager.players[pid]
		if is_instance_valid(p):
			players.append(p)
	if players.is_empty():
		return
	var all_down: bool = true
	for p: CharacterBody2D in players:
		if not p.is_down:
			all_down = false
			break
	if all_down and not game_over:
		_trigger_game_over()


func _trigger_game_over() -> void:
	game_over = true
	print("[Game] 游戏结束！所有玩家都倒地了")
	# 创建游戏结束UI
	game_over_label = Label.new()
	game_over_label.text = "游戏结束\n所有幸存者都已倒下\n\n按 R 重新开始"
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game_over_label.add_theme_font_size_override("font_size", 32)
	game_over_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	game_over_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	game_over_label.add_theme_constant_override("outline_size", 6)
	game_over_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.add_child(game_over_label)
	# 通知所有玩家
	GameManager.send_chat.rpc("游戏结束！所有幸存者都已倒下")


func _unhandled_input(event: InputEvent) -> void:
	# ESC键处理已移到 _on_input_action_pressed 函数中，使用InputManager统一管理
	# R键重新开始游戏（仅在游戏结束时）
	if game_over and event is InputEventKey and event.pressed and event.physical_keycode == KEY_R:
		# 重新开始游戏
		get_tree().reload_current_scene()


func _on_input_action_pressed(action: String) -> void:
	## 处理InputManager的action_pressed信号
	## 当"pause"动作被按下时，打开/关闭设置菜单
	if action == "pause":
		if settings_menu and settings_menu.has_method("toggle"):
			# 如果设置菜单已经可见，让settings_menu自己处理ESC键（先关闭子菜单，再关闭整个菜单）
			if settings_menu.visible:
				return
			# 检查是否有其他UI菜单打开（如科技树、背包等），如果有则不打开设置菜单
			var other_ui_open: bool = false
			# 检查科技树UI
			var tech_tree: Node = get_node_or_null("TechTreeUI")
			if tech_tree and tech_tree.has_method("is_open") and tech_tree.is_open():
				other_ui_open = true
			# 检查背包UI
			var inventory: Node = get_node_or_null("InventoryUI")
			if inventory and inventory.has_method("is_open") and inventory.is_open():
				other_ui_open = true
			# 如果没有其他UI菜单打开，打开设置菜单
			if not other_ui_open:
				settings_menu.toggle()


func get_time_of_day() -> float:
	return current_time


func is_night_time() -> bool:
	## 是否是夜晚（current_time < 0.2 或 > 0.8）
	return current_time < 0.2 or current_time > 0.8


func get_day_count() -> int:
	return day_count


func get_season() -> String:
	return season


func get_weather() -> String:
	return weather


func get_special_event() -> String:
	return special_event


func get_ambient_temperature() -> float:
	return ambient_temperature


func get_current_month() -> int:
	## 获取当前月份（0-11，对应1-12月）
	return current_month


func get_month_name() -> String:
	## 获取当前月份名称
	return MONTH_NAMES[current_month]


func get_day_in_month() -> int:
	## 获取当月第几天
	return day_in_month


func _connect_inventory_ui() -> void:
	var player: Node = GameManager.get_local_player()
	if player and is_instance_valid(player):
		var inv: Node = player.get_node_or_null("Inventory")
		if inv:
			inventory_ui.set_inventory(inv)
			quickbar.set_inventory(inv)
			craft_ui.set_inventory(inv)
			build_ui.set_inventory(inv)
			build_ui.building_placed.connect(_on_building_placed)
			# 连接人物属性UI
			if character_ui and character_ui.has_method("set_player"):
				character_ui.set_player(player)
			inventory_ui_connected = true
			print("[Main] 所有UI已连接")


func _on_building_placed(building_id: String, position: Vector2) -> void:
	# 只有主机才能创建建筑（权威服务器）
	if not GameManager.is_server:
		# 客户端通过RPC通知主机创建
		_rpc_place_building.rpc_id(1, building_id, position)
		return
	_create_building(building_id, position)


func _create_building(building_id: String, position: Vector2) -> void:
	var building: Node2D = BUILDING_SCENE.instantiate()
	building.building_id = building_id
	building.position = position
	building.name = "Building_%s_%d" % [building_id, randi()]
	world_layer.add_child(building)
	print("[World] 创建建筑: %s at %s" % [BuildingDB.get_building_name(building_id), str(position)])


@rpc("any_peer", "call_local")
func _rpc_place_building(building_id: String, position: Vector2) -> void:
	if GameManager.is_server:
		_create_building(building_id, position)
