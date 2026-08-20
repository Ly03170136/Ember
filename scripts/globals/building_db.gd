extends Node
## 建筑数据库：定义所有建筑的属性
## 自动加载为全局单例，通过 BuildingDB 访问

# 建筑定义：id -> 属性
const BUILDINGS := {
	# ===== 基础建筑 =====
	"campfire": {
		"name": "篝火",
		"desc": "提供照明和热量，可用于烹饪食物",
		"cost": {"wood": 5, "stone": 3},
		"build_time": 30.0,  # 建造时间（秒）
		"max_health": 50.0,
		"size": Vector2(48, 48),
		"color": Color(0.9, 0.4, 0.1),
		"category": "basic",
		"light_radius": 150.0,
	},
	"farm_plot": {
		"name": "农田",
		"desc": "可种植作物的农田（农民专用），作物成熟后可收获",
		"cost": {"wood": 3, "stone": 2},
		"build_time": 20.0,
		"max_health": 30.0,
		"size": Vector2(64, 64),
		"color": Color(0.45, 0.3, 0.15),
		"category": "production",
	},
	"wall_wood": {
		"name": "木墙",
		"desc": "木制围墙，阻挡丧尸进入",
		"cost": {"wood": 4},
		"build_time": 20.0,
		"max_health": 100.0,
		"size": Vector2(48, 48),
		"color": Color(0.55, 0.35, 0.15),
		"category": "defense",
	},
	"door_wood": {
		"name": "木门",
		"desc": "可开关的木门",
		"cost": {"wood": 6, "fiber": 2},
		"build_time": 25.0,
		"max_health": 80.0,
		"size": Vector2(48, 48),
		"color": Color(0.5, 0.3, 0.1),
		"category": "defense",
	},
	"workbench": {
		"name": "工作台",
		"desc": "用于制作高级工具和武器",
		"cost": {"wood": 8, "stone": 4},
		"build_time": 40.0,
		"max_health": 80.0,
		"size": Vector2(64, 48),
		"color": Color(0.6, 0.45, 0.25),
		"category": "crafting",
		"station": "workbench",
	},
	"storage": {
		"name": "仓库",
		"desc": "存放物品的木箱",
		"cost": {"wood": 10},
		"build_time": 35.0,
		"max_health": 60.0,
		"size": Vector2(56, 48),
		"color": Color(0.65, 0.45, 0.2),
		"category": "storage",
		"slots": 20,
	},
	"bed": {
		"name": "床",
		"desc": "睡觉恢复生命值，可跳过夜晚",
		"cost": {"wood": 6, "fiber": 4, "cloth": 2},
		"build_time": 30.0,
		"max_health": 40.0,
		"size": Vector2(64, 48),
		"color": Color(0.7, 0.6, 0.5),
		"category": "basic",
	},
	"trap": {
		"name": "陷阱",
		"desc": "尖刺陷阱，丧尸踩上会受伤",
		"cost": {"wood": 3, "stone": 4, "fiber": 2},
		"build_time": 20.0,
		"max_health": 30.0,
		"size": Vector2(40, 40),
		"color": Color(0.5, 0.5, 0.5),
		"category": "defense",
		"damage": 20.0,
	},
	"torch": {
		"name": "火把",
		"desc": "固定的照明设施",
		"cost": {"wood": 2, "fiber": 1},
		"build_time": 10.0,
		"max_health": 20.0,
		"size": Vector2(24, 48),
		"color": Color(0.9, 0.6, 0.2),
		"category": "basic",
		"light_radius": 100.0,
	},
	# ===== 电力建筑 =====
	"small_generator": {
		"name": "小型发电机",
		"desc": "功率500W，需要汽油，可带动5台设备",
		"cost": {"metal": 10, "wire": 5, "engine_part": 1},
		"build_time": 60.0,
		"max_health": 80.0,
		"size": Vector2(48, 48),
		"color": Color(0.6, 0.6, 0.65),
		"category": "power",
	},
	"electric_light": {
		"name": "电灯",
		"desc": "电力照明设备，需要在发电机供电范围内",
		"cost": {"metal": 2, "wire": 2, "glass": 1},
		"build_time": 15.0,
		"max_health": 20.0,
		"size": Vector2(24, 24),
		"color": Color(1.0, 0.95, 0.7),
		"category": "power",
		"light_radius": 200.0,
	},
	"auto_turret": {
		"name": "自动炮塔",
		"desc": "自动攻击附近丧尸，需要电力",
		"cost": {"metal": 15, "wire": 8, "weapon_part": 2},
		"build_time": 90.0,
		"max_health": 100.0,
		"size": Vector2(40, 40),
		"color": Color(0.4, 0.4, 0.5),
		"category": "defense",
	},
	"electric_furnace": {
		"name": "电炉",
		"desc": "电力冶炼设备，可冶炼金属矿石，需要电力",
		"cost": {"metal": 8, "wire": 4, "stone": 5},
		"build_time": 60.0,
		"max_health": 80.0,
		"size": Vector2(48, 48),
		"color": Color(0.6, 0.3, 0.2),
		"category": "production",
		"power_type": "furnace",
		"power_consumption": 100,
	},
	"refrigerator": {
		"name": "冰箱",
		"desc": "电力冷藏设备，减缓食物腐烂，需要电力",
		"cost": {"metal": 12, "wire": 6, "glass": 2},
		"build_time": 75.0,
		"max_health": 80.0,
		"size": Vector2(40, 56),
		"color": Color(0.7, 0.8, 0.9),
		"category": "storage",
		"power_type": "fridge",
		"power_consumption": 50,
	},
	"electric_workbench": {
		"name": "电动工具台",
		"desc": "电力工具台，加速制作速度50%，需要电力",
		"cost": {"metal": 10, "wire": 5, "wood": 8},
		"build_time": 70.0,
		"max_health": 80.0,
		"size": Vector2(56, 40),
		"color": Color(0.5, 0.5, 0.6),
		"category": "production",
		"power_type": "workbench",
		"power_consumption": 80,
	},
	"electric_heater": {
		"name": "电暖气",
		"desc": "电力取暖设备，增加附近玩家保暖度，需要电力",
		"cost": {"metal": 6, "wire": 4},
		"build_time": 45.0,
		"max_health": 60.0,
		"size": Vector2(32, 48),
		"color": Color(0.8, 0.4, 0.2),
		"category": "comfort",
		"power_type": "heater",
		"power_consumption": 60,
	},
	"laboratory": {
		"name": "病毒实验室",
		"desc": "病毒爆发的源头，摧毁后可通关游戏。全地图只生成一个。",
		"cost": {},
		"build_time": 0.0,
		"max_health": 1000.0,
		"size": Vector2(96, 96),
		"color": Color(0.3, 0.35, 0.4),
		"category": "special",
		"is_lab": true,
	},
	# ===== 新增：基础生存建筑 =====
	"wooden_box": {
		"name": "木箱",
		"desc": "存储物品（20格）",
		"cost": {"wood": 8},
		"build_time": 25.0,
		"max_health": 40.0,
		"size": Vector2(40, 40),
		"color": Color(0.6, 0.4, 0.2),
		"category": "storage",
		"slots": 20,
	},
	"warehouse": {
		"name": "仓库",
		"desc": "大型存储（可升级，50格）",
		"cost": {"wood": 20, "stone": 10},
		"build_time": 60.0,
		"max_health": 120.0,
		"size": Vector2(80, 64),
		"color": Color(0.55, 0.4, 0.25),
		"category": "storage",
		"slots": 50,
	},
	"well": {
		"name": "水井",
		"desc": "获取清洁水源",
		"cost": {"stone": 15, "wood": 5},
		"build_time": 50.0,
		"max_health": 80.0,
		"size": Vector2(48, 48),
		"color": Color(0.4, 0.5, 0.6),
		"category": "basic",
		"water_source": true,
	},
	"rain_collector": {
		"name": "雨水收集器",
		"desc": "收集雨水（需净化后饮用）",
		"cost": {"wood": 6, "metal": 2, "cloth": 3},
		"build_time": 30.0,
		"max_health": 40.0,
		"size": Vector2(48, 56),
		"color": Color(0.5, 0.6, 0.7),
		"category": "basic",
		"water_source": true,
		"needs_purification": true,
	},
	# ===== 新增：生产制作建筑 =====
	"kitchen": {
		"name": "厨房",
		"desc": "高级烹饪（厨师专用），可制作高级食物",
		"cost": {"wood": 12, "stone": 8, "metal": 4},
		"build_time": 50.0,
		"max_health": 80.0,
		"size": Vector2(64, 48),
		"color": Color(0.65, 0.45, 0.3),
		"category": "production",
		"station": "kitchen",
	},
	"furnace": {
		"name": "熔炉",
		"desc": "冶炼金属锭，需要燃料",
		"cost": {"stone": 20, "wood": 5},
		"build_time": 45.0,
		"max_health": 100.0,
		"size": Vector2(48, 56),
		"color": Color(0.5, 0.35, 0.25),
		"category": "production",
		"station": "furnace",
		"needs_fuel": true,
	},
	"research_table": {
		"name": "研究台",
		"desc": "学习书籍、解锁科技",
		"cost": {"wood": 10, "metal": 3, "cloth": 2},
		"build_time": 40.0,
		"max_health": 60.0,
		"size": Vector2(56, 40),
		"color": Color(0.5, 0.45, 0.35),
		"category": "production",
		"station": "research",
	},
	"sawmill": {
		"name": "锯木厂",
		"desc": "批量加工木材，提高木材产出",
		"cost": {"wood": 15, "metal": 8, "stone": 5},
		"build_time": 70.0,
		"max_health": 100.0,
		"size": Vector2(80, 64),
		"color": Color(0.55, 0.4, 0.25),
		"category": "production",
		"station": "sawmill",
	},
	"blacksmith": {
		"name": "铁匠铺",
		"desc": "制作高级金属工具和武器",
		"cost": {"stone": 15, "metal": 10, "wood": 8},
		"build_time": 80.0,
		"max_health": 120.0,
		"size": Vector2(64, 56),
		"color": Color(0.45, 0.4, 0.35),
		"category": "production",
		"station": "blacksmith",
	},
	# ===== 新增：农业建筑 =====
	"greenhouse": {
		"name": "大棚",
		"desc": "反季节种植，不受季节影响",
		"cost": {"wood": 15, "cloth": 10, "metal": 5},
		"build_time": 60.0,
		"max_health": 60.0,
		"size": Vector2(80, 64),
		"color": Color(0.5, 0.7, 0.5),
		"category": "farming",
		"station": "greenhouse",
	},
	"composter": {
		"name": "堆肥箱",
		"desc": "制作肥料，加速作物生长",
		"cost": {"wood": 8, "stone": 4},
		"build_time": 25.0,
		"max_health": 40.0,
		"size": Vector2(40, 40),
		"color": Color(0.45, 0.35, 0.2),
		"category": "farming",
		"station": "composter",
	},
	"animal_pen": {
		"name": "动物围栏",
		"desc": "饲养动物（鸡、猪等），获取肉和蛋",
		"cost": {"wood": 20, "fiber": 10},
		"build_time": 50.0,
		"max_health": 80.0,
		"size": Vector2(96, 80),
		"color": Color(0.55, 0.45, 0.3),
		"category": "farming",
		"station": "animal_pen",
	},
	# ===== 新增：防御建筑 =====
	"stone_wall": {
		"name": "石墙",
		"desc": "石制围墙，比木墙更坚固",
		"cost": {"stone": 10, "wood": 2},
		"build_time": 40.0,
		"max_health": 250.0,
		"size": Vector2(48, 48),
		"color": Color(0.6, 0.55, 0.5),
		"category": "defense",
	},
	"metal_wall": {
		"name": "金属墙",
		"desc": "金属围墙，最高级防御",
		"cost": {"metal": 10, "stone": 5},
		"build_time": 60.0,
		"max_health": 500.0,
		"size": Vector2(48, 48),
		"color": Color(0.7, 0.7, 0.75),
		"category": "defense",
	},
	"tripwire_trap": {
		"name": "绊索陷阱",
		"desc": "减速触发的敌人",
		"cost": {"fiber": 5, "wood": 2, "metal": 1},
		"build_time": 15.0,
		"max_health": 20.0,
		"size": Vector2(40, 40),
		"color": Color(0.5, 0.5, 0.4),
		"category": "defense",
		"slow_effect": 0.5,
	},
	"barbed_wire": {
		"name": "铁丝网",
		"desc": "减速并伤害靠近的敌人",
		"cost": {"metal": 6, "wood": 2},
		"build_time": 20.0,
		"max_health": 40.0,
		"size": Vector2(48, 48),
		"color": Color(0.55, 0.55, 0.6),
		"category": "defense",
		"damage": 5.0,
		"slow_effect": 0.6,
	},
	# ===== 新增：电力建筑 =====
	"solar_panel": {
		"name": "太阳能板",
		"desc": "白天发电，需配合电池使用",
		"cost": {"metal": 8, "wire": 6, "glass": 4},
		"build_time": 50.0,
		"max_health": 60.0,
		"size": Vector2(56, 48),
		"color": Color(0.3, 0.4, 0.6),
		"category": "power",
		"power_type": "solar",
		"day_only": true,
	},
	"wind_turbine": {
		"name": "风力发电机",
		"desc": "持续发电（依赖天气）",
		"cost": {"metal": 12, "wire": 8, "wood": 6},
		"build_time": 70.0,
		"max_health": 80.0,
		"size": Vector2(48, 80),
		"color": Color(0.6, 0.65, 0.7),
		"category": "power",
		"power_type": "wind",
		"weather_dependent": true,
	},
	"electric_fence": {
		"name": "电网",
		"desc": "电击靠近的丧尸（需电力）",
		"cost": {"metal": 8, "wire": 10},
		"build_time": 35.0,
		"max_health": 60.0,
		"size": Vector2(48, 48),
		"color": Color(0.5, 0.6, 0.7),
		"category": "defense",
		"power_type": "fence",
		"power_consumption": 30,
		"damage": 15.0,
	},
	# ===== 新增：载具相关建筑 =====
	"garage": {
		"name": "车库",
		"desc": "修理、改装载具（汽修工专用）",
		"cost": {"metal": 20, "wood": 15, "stone": 10},
		"build_time": 90.0,
		"max_health": 150.0,
		"size": Vector2(96, 80),
		"color": Color(0.5, 0.45, 0.4),
		"category": "vehicle",
		"station": "garage",
	},
	"fuel_station": {
		"name": "加油站",
		"desc": "储存燃料，为载具加油",
		"cost": {"metal": 15, "wire": 5, "stone": 8},
		"build_time": 60.0,
		"max_health": 100.0,
		"size": Vector2(64, 64),
		"color": Color(0.7, 0.5, 0.2),
		"category": "vehicle",
		"station": "fuel_station",
		"fuel_storage": 200,
	},
	# ===== 新增：医疗建筑 =====
	"med_station": {
		"name": "医疗站",
		"desc": "治疗、制药（医生专用）",
		"cost": {"metal": 10, "wood": 8, "cloth": 5},
		"build_time": 50.0,
		"max_health": 80.0,
		"size": Vector2(64, 48),
		"color": Color(0.7, 0.8, 0.9),
		"category": "medical",
		"station": "medical",
	},
	"quarantine_room": {
		"name": "隔离室",
		"desc": "隔离感染NPC/玩家，防止病毒传播",
		"cost": {"metal": 12, "wood": 10, "stone": 8},
		"build_time": 60.0,
		"max_health": 120.0,
		"size": Vector2(80, 64),
		"color": Color(0.6, 0.7, 0.75),
		"category": "medical",
		"station": "quarantine",
	},
	# ===== 新增：存储与装饰 =====
	"shelf": {
		"name": "架子",
		"desc": "展示/存储物品（15格）",
		"cost": {"wood": 6},
		"build_time": 20.0,
		"max_health": 30.0,
		"size": Vector2(48, 56),
		"color": Color(0.6, 0.45, 0.25),
		"category": "decoration",
		"slots": 15,
	},
	"table": {
		"name": "桌子",
		"desc": "装饰/放置物品",
		"cost": {"wood": 8},
		"build_time": 20.0,
		"max_health": 30.0,
		"size": Vector2(56, 32),
		"color": Color(0.55, 0.4, 0.25),
		"category": "decoration",
	},
	"chair": {
		"name": "椅子",
		"desc": "装饰/休息",
		"cost": {"wood": 4, "fiber": 1},
		"build_time": 15.0,
		"max_health": 20.0,
		"size": Vector2(32, 40),
		"color": Color(0.5, 0.35, 0.2),
		"category": "decoration",
	},
	"rug": {
		"name": "地毯",
		"desc": "装饰，增加舒适度",
		"cost": {"cloth": 8, "fiber": 4},
		"build_time": 25.0,
		"max_health": 20.0,
		"size": Vector2(64, 48),
		"color": Color(0.6, 0.3, 0.3),
		"category": "decoration",
	},
	"bookshelf": {
		"name": "书架",
		"desc": "存放书籍（10格）",
		"cost": {"wood": 10},
		"build_time": 30.0,
		"max_health": 40.0,
		"size": Vector2(48, 64),
		"color": Color(0.5, 0.35, 0.2),
		"category": "decoration",
		"slots": 10,
	},
}


# 获取建筑信息
func get_building(building_id: String) -> Dictionary:
	if BUILDINGS.has(building_id):
		return BUILDINGS[building_id]
	return {}


func get_building_name(building_id: String) -> String:
	if BUILDINGS.has(building_id):
		return BUILDINGS[building_id].name
	return "未知建筑"


func get_building_cost(building_id: String) -> Dictionary:
	if BUILDINGS.has(building_id):
		return BUILDINGS[building_id].cost
	return {}


func get_build_time(building_id: String) -> float:
	if BUILDINGS.has(building_id):
		return BUILDINGS[building_id].build_time
	return 0.0


func get_max_health(building_id: String) -> float:
	if BUILDINGS.has(building_id):
		return BUILDINGS[building_id].max_health
	return 0.0


func get_building_size(building_id: String) -> Vector2:
	if BUILDINGS.has(building_id):
		return BUILDINGS[building_id].size
	return Vector2(48, 48)


func get_building_color(building_id: String) -> Color:
	if BUILDINGS.has(building_id):
		return BUILDINGS[building_id].color
	return Color.GRAY


func get_category(building_id: String) -> String:
	if BUILDINGS.has(building_id):
		return BUILDINGS[building_id].category
	return "misc"


func get_all_buildings() -> Dictionary:
	return BUILDINGS


func building_exists(building_id: String) -> bool:
	return BUILDINGS.has(building_id)


# 检查是否有足够材料建造
func can_build(building_id: String, inventory: Node) -> bool:
	var building: Dictionary = get_building(building_id)
	if building.is_empty():
		return false
	for mat_id in building.cost.keys():
		var needed: int = building.cost[mat_id]
		if not inventory.has_item(mat_id, needed):
			return false
	return true


# 消耗建造材料
func consume_build_materials(building_id: String, inventory: Node) -> bool:
	var building: Dictionary = get_building(building_id)
	if building.is_empty():
		return false
	if not can_build(building_id, inventory):
		return false
	for mat_id in building.cost.keys():
		var needed: int = building.cost[mat_id]
		inventory.remove_item(mat_id, needed)
	return true


# ==================== P1: 建筑升级系统 ====================
# 升级配置：建筑id -> 等级 -> 升级属性
const UPGRADES := {
	"wall_wood": {
		1: {"name": "木墙", "max_health": 100.0, "color": Color(0.55, 0.35, 0.15), "cost": {}, "upgrade_time": 0.0},
		2: {"name": "砖墙", "max_health": 250.0, "color": Color(0.6, 0.55, 0.5), "cost": {"stone": 8, "wood": 2}, "upgrade_time": 60.0},
		3: {"name": "金属墙", "max_health": 500.0, "color": Color(0.7, 0.7, 0.75), "cost": {"metal": 10, "stone": 5}, "upgrade_time": 120.0},
	},
	"door_wood": {
		1: {"name": "木门", "max_health": 80.0, "color": Color(0.5, 0.3, 0.1), "cost": {}, "upgrade_time": 0.0},
		2: {"name": "砖门", "max_health": 200.0, "color": Color(0.55, 0.5, 0.45), "cost": {"stone": 6, "wood": 2}, "upgrade_time": 50.0},
		3: {"name": "金属门", "max_health": 400.0, "color": Color(0.65, 0.65, 0.7), "cost": {"metal": 8, "stone": 4}, "upgrade_time": 100.0},
	},
	"storage": {
		1: {"name": "木仓库", "max_health": 60.0, "color": Color(0.65, 0.45, 0.2), "cost": {}, "upgrade_time": 0.0, "slots": 20},
		2: {"name": "砖仓库", "max_health": 120.0, "color": Color(0.6, 0.55, 0.5), "cost": {"stone": 10, "wood": 5}, "upgrade_time": 80.0, "slots": 40},
		3: {"name": "金属仓库", "max_health": 200.0, "color": Color(0.7, 0.7, 0.75), "cost": {"metal": 12, "stone": 6}, "upgrade_time": 150.0, "slots": 80},
	},
	"campfire": {
		1: {"name": "篝火", "max_health": 50.0, "color": Color(0.9, 0.4, 0.1), "cost": {}, "upgrade_time": 0.0, "light_radius": 150.0},
		2: {"name": "石炉", "max_health": 100.0, "color": Color(0.6, 0.55, 0.5), "cost": {"stone": 10, "wood": 3}, "upgrade_time": 60.0, "light_radius": 200.0},
		3: {"name": "金属炉", "max_health": 150.0, "color": Color(0.7, 0.7, 0.75), "cost": {"metal": 8, "stone": 5}, "upgrade_time": 120.0, "light_radius": 280.0},
	},
	"workbench": {
		1: {"name": "木工作台", "max_health": 80.0, "color": Color(0.6, 0.45, 0.25), "cost": {}, "upgrade_time": 0.0, "craft_speed": 1.0},
		2: {"name": "石工作台", "max_health": 150.0, "color": Color(0.55, 0.5, 0.45), "cost": {"stone": 8, "wood": 4}, "upgrade_time": 70.0, "craft_speed": 1.5},
		3: {"name": "金属工作台", "max_health": 250.0, "color": Color(0.65, 0.65, 0.7), "cost": {"metal": 10, "stone": 5}, "upgrade_time": 140.0, "craft_speed": 2.5},
	},
	"bed": {
		1: {"name": "木床", "max_health": 40.0, "color": Color(0.7, 0.6, 0.5), "cost": {}, "upgrade_time": 0.0, "heal_rate": 1.0},
		2: {"name": "舒适床", "max_health": 80.0, "color": Color(0.6, 0.5, 0.6), "cost": {"cloth": 8, "wood": 4}, "upgrade_time": 50.0, "heal_rate": 2.0},
		3: {"name": "豪华床", "max_health": 120.0, "color": Color(0.7, 0.6, 0.7), "cost": {"cloth": 15, "metal": 5}, "upgrade_time": 100.0, "heal_rate": 4.0},
	},
	"trap": {
		1: {"name": "木陷阱", "max_health": 30.0, "color": Color(0.5, 0.5, 0.5), "cost": {}, "upgrade_time": 0.0, "damage": 20.0},
		2: {"name": "铁陷阱", "max_health": 60.0, "color": Color(0.6, 0.6, 0.65), "cost": {"metal": 5, "wood": 2}, "upgrade_time": 40.0, "damage": 40.0},
		3: {"name": "钢陷阱", "max_health": 100.0, "color": Color(0.7, 0.7, 0.75), "cost": {"metal": 10, "stone": 3}, "upgrade_time": 80.0, "damage": 80.0},
	},
	"torch": {
		1: {"name": "木火把", "max_health": 20.0, "color": Color(0.9, 0.6, 0.2), "cost": {}, "upgrade_time": 0.0, "light_radius": 100.0},
		2: {"name": "铁火把", "max_health": 40.0, "color": Color(0.7, 0.5, 0.3), "cost": {"metal": 3, "wood": 1}, "upgrade_time": 30.0, "light_radius": 150.0},
		3: {"name": "电灯", "max_health": 60.0, "color": Color(0.8, 0.8, 1.0), "cost": {"metal": 5, "scrap": 3}, "upgrade_time": 60.0, "light_radius": 220.0},
	},
}

const MAX_BUILDING_LEVEL := 3

func can_upgrade(building_id: String, current_level: int) -> bool:
	if not UPGRADES.has(building_id):
		return false
	return current_level < MAX_BUILDING_LEVEL and UPGRADES[building_id].has(current_level + 1)

func get_upgrade_info(building_id: String, target_level: int) -> Dictionary:
	if UPGRADES.has(building_id) and UPGRADES[building_id].has(target_level):
		return UPGRADES[building_id][target_level]
	return {}

func get_upgrade_cost(building_id: String, target_level: int) -> Dictionary:
	var info: Dictionary = get_upgrade_info(building_id, target_level)
	if info.has("cost"):
		return info.cost
	return {}

func get_upgrade_time(building_id: String, target_level: int) -> float:
	var info: Dictionary = get_upgrade_info(building_id, target_level)
	if info.has("upgrade_time"):
		return info.upgrade_time
	return 0.0

func can_afford_upgrade(building_id: String, target_level: int, inventory: Node) -> bool:
	var cost: Dictionary = get_upgrade_cost(building_id, target_level)
	for mat_id in cost.keys():
		var needed: int = cost[mat_id]
		if not inventory.has_item(mat_id, needed):
			return false
	return true

func consume_upgrade_materials(building_id: String, target_level: int, inventory: Node) -> bool:
	if not can_afford_upgrade(building_id, target_level, inventory):
		return false
	var cost: Dictionary = get_upgrade_cost(building_id, target_level)
	for mat_id in cost.keys():
		var needed: int = cost[mat_id]
		inventory.remove_item(mat_id, needed)
	return true

func get_building_level_stats(building_id: String, level: int) -> Dictionary:
	var base: Dictionary = get_building(building_id)
	var stats: Dictionary = base.duplicate()
	if UPGRADES.has(building_id) and UPGRADES[building_id].has(level):
		var upgrade: Dictionary = UPGRADES[building_id][level]
		for key in upgrade.keys():
			stats[key] = upgrade[key]
	return stats
