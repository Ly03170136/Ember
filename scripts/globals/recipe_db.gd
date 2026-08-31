extends Node
## 配方数据库：定义所有制作配方
## 自动加载为全局单例，通过 RecipeDB 访问

# 配方定义：id -> {result: 结果物品ID, count: 数量, ingredients: {材料ID: 数量}, station: 需要的建筑}
const RECIPES := {
	# ===== 工具 =====
	"stone_axe": {
		"result": "stone_axe",
		"count": 1,
		"ingredients": {"wood": 3, "stone": 2, "fiber": 1},
		"station": "",
		"name": "石斧",
	},
	"stone_pickaxe": {
		"result": "stone_pickaxe",
		"count": 1,
		"ingredients": {"wood": 3, "stone": 3, "fiber": 1},
		"station": "",
		"name": "石镐",
	},
	"tool_iron_pick": {
		"result": "tool_iron_pick",
		"count": 1,
		"ingredients": {"wood": 2, "metal": 4, "fiber": 1},
		"station": "workbench",
		"name": "铁镐",
	},
	"tool_hammer": {
		"result": "tool_hammer",
		"count": 1,
		"ingredients": {"wood": 2, "metal": 3, "fiber": 1},
		"station": "workbench",
		"name": "锤子",
	},
	"tool_saw": {
		"result": "tool_saw",
		"count": 1,
		"ingredients": {"wood": 2, "metal": 3, "fiber": 1},
		"station": "workbench",
		"name": "锯子",
	},
	"tool_wrench": {
		"result": "tool_wrench",
		"count": 1,
		"ingredients": {"metal": 5, "fiber": 1},
		"station": "workbench",
		"name": "扳手",
	},
	"tool_screwdriver": {
		"result": "tool_screwdriver",
		"count": 1,
		"ingredients": {"metal": 2, "wood": 1},
		"station": "workbench",
		"name": "螺丝刀",
	},
	"tool_knife": {
		"result": "tool_knife",
		"count": 1,
		"ingredients": {"wood": 1, "metal": 2, "fiber": 1},
		"station": "workbench",
		"name": "小刀",
	},
	"tool_fishing_rod": {
		"result": "tool_fishing_rod",
		"count": 1,
		"ingredients": {"wood": 3, "fiber": 5, "metal": 1},
		"station": "",
		"name": "钓鱼竿",
	},
	"tool_torch": {
		"result": "tool_torch",
		"count": 2,
		"ingredients": {"wood": 2, "fiber": 1, "cloth": 1},
		"station": "",
		"name": "手持火把",
	},

	# ===== 武器 =====
	"weapon_wooden_spear": {
		"result": "weapon_wooden_spear",
		"count": 1,
		"ingredients": {"wood": 4, "fiber": 2, "stone": 1},
		"station": "",
		"name": "木矛",
	},
	"weapon_stone_knife": {
		"result": "weapon_stone_knife",
		"count": 1,
		"ingredients": {"stone": 3, "wood": 1, "fiber": 1},
		"station": "",
		"name": "石刀",
	},
	"weapon_iron_sword": {
		"result": "weapon_iron_sword",
		"count": 1,
		"ingredients": {"wood": 1, "metal": 5, "fiber": 1, "mat_nail": 2},
		"station": "workbench",
		"name": "铁剑",
	},
	"weapon_steel_sword": {
		"result": "weapon_steel_sword",
		"count": 1,
		"ingredients": {"wood": 1, "mat_steel_ingot": 4, "fiber": 1, "mat_nail": 3},
		"station": "blacksmith",
		"name": "钢剑",
	},
	"weapon_bow": {
		"result": "weapon_bow",
		"count": 1,
		"ingredients": {"wood": 4, "fiber": 6, "cloth": 1},
		"station": "",
		"name": "弓",
	},
	"weapon_crossbow": {
		"result": "weapon_crossbow",
		"count": 1,
		"ingredients": {"wood": 5, "metal": 3, "fiber": 4, "mat_rope": 2},
		"station": "workbench",
		"name": "弩",
	},
	"weapon_pistol": {
		"result": "weapon_pistol",
		"count": 1,
		"ingredients": {"metal": 8, "mat_electronic": 2, "mat_nail": 5},
		"station": "workbench",
		"name": "手枪",
	},
	"weapon_rifle": {
		"result": "weapon_rifle",
		"count": 1,
		"ingredients": {"metal": 12, "wood": 3, "mat_electronic": 3, "mat_nail": 8},
		"station": "workbench",
		"name": "步枪",
	},
	"weapon_shotgun": {
		"result": "weapon_shotgun",
		"count": 1,
		"ingredients": {"metal": 10, "wood": 4, "mat_nail": 6},
		"station": "workbench",
		"name": "霰弹枪",
	},
	"weapon_bat": {
		"result": "weapon_bat",
		"count": 1,
		"ingredients": {"wood": 6, "fiber": 2},
		"station": "",
		"name": "棒球棍",
	},
	"weapon_pipe": {
		"result": "weapon_pipe",
		"count": 1,
		"ingredients": {"metal": 4, "fiber": 1},
		"station": "",
		"name": "铁管",
	},

	# ===== 弹药 =====
	"ammo_arrow": {
		"result": "ammo_arrow",
		"count": 5,
		"ingredients": {"wood": 2, "stone": 1, "fiber": 1},
		"station": "",
		"name": "箭",
	},
	"ammo_bullet": {
		"result": "ammo_bullet",
		"count": 10,
		"ingredients": {"metal": 2, "mat_gunpowder": 1, "mat_nail": 1},
		"station": "workbench",
		"name": "子弹",
	},
	"ammo_shell": {
		"result": "ammo_shell",
		"count": 6,
		"ingredients": {"metal": 3, "mat_gunpowder": 2, "mat_plastic": 1},
		"station": "workbench",
		"name": "霰弹",
	},

	# ===== 食物与饮水 =====
	"food_cooked_meat": {
		"result": "food_cooked_meat",
		"count": 1,
		"ingredients": {"food_raw_meat": 1, "wood": 1},
		"station": "campfire",
		"name": "烤肉",
	},
	"food_soup": {
		"result": "food_soup",
		"count": 1,
		"ingredients": {"food_raw_meat": 1, "food_vegetable": 2, "drink_water": 1},
		"station": "kitchen",
		"name": "炖汤",
	},
	"food_bread": {
		"result": "food_bread",
		"count": 2,
		"ingredients": {"food_wheat": 3, "drink_water": 1},
		"station": "kitchen",
		"name": "面包",
	},
	"food_canned_meat": {
		"result": "food_canned_meat",
		"count": 1,
		"ingredients": {"food_cooked_meat": 2, "mat_plastic": 1, "metal": 1},
		"station": "kitchen",
		"name": "罐装肉",
	},
	"drink_purified_water": {
		"result": "drink_purified_water",
		"count": 1,
		"ingredients": {"drink_water": 2, "mat_chemical": 1},
		"station": "campfire",
		"name": "净水",
	},

	# ===== 药品与医疗 =====
	"med_bandage": {
		"result": "med_bandage",
		"count": 3,
		"ingredients": {"cloth": 2, "fiber": 1},
		"station": "",
		"name": "绷带",
	},
	"med_antiseptic": {
		"result": "med_antiseptic",
		"count": 1,
		"ingredients": {"mat_chemical": 2, "drink_water": 1, "cloth": 1},
		"station": "med_station",
		"name": "消毒水",
	},
	"med_basic_kit": {
		"result": "med_basic_kit",
		"count": 1,
		"ingredients": {"med_bandage": 3, "med_antiseptic": 1, "cloth": 2},
		"station": "med_station",
		"name": "简易急救包",
	},
	"med_advanced_kit": {
		"result": "med_advanced_kit",
		"count": 1,
		"ingredients": {"med_basic_kit": 2, "mat_chemical": 3, "cloth": 3},
		"station": "med_station",
		"name": "高级急救包",
	},
	"med_surgical_kit": {
		"result": "med_surgical_kit",
		"count": 1,
		"ingredients": {"med_advanced_kit": 2, "mat_electronic": 3, "metal": 5, "cloth": 5},
		"station": "med_station",
		"name": "手术包",
	},
	"med_antibiotic": {
		"result": "med_antibiotic",
		"count": 2,
		"ingredients": {"mat_chemical": 3, "food_vegetable": 2},
		"station": "med_station",
		"name": "抗生素",
	},
	"med_painkiller": {
		"result": "med_painkiller",
		"count": 3,
		"ingredients": {"mat_chemical": 2, "cloth": 1},
		"station": "med_station",
		"name": "止痛药",
	},

	# ===== 衣物与护甲 =====
	"cloth_basic": {
		"result": "cloth_basic",
		"count": 1,
		"ingredients": {"cloth": 5, "fiber": 3},
		"station": "",
		"name": "布衣",
	},
	"cloth_leather": {
		"result": "cloth_leather",
		"count": 1,
		"ingredients": {"cloth": 3, "food_raw_meat": 3, "fiber": 2, "mat_rope": 1},
		"station": "workbench",
		"name": "皮夹克",
	},
	"cloth_winter": {
		"result": "cloth_winter",
		"count": 1,
		"ingredients": {"cloth": 8, "fiber": 5, "cloth_basic": 1},
		"station": "workbench",
		"name": "棉大衣",
	},
	"cloth_raincoat": {
		"result": "cloth_raincoat",
		"count": 1,
		"ingredients": {"mat_plastic": 5, "cloth": 3, "fiber": 2},
		"station": "workbench",
		"name": "雨衣",
	},
	"armor_military": {
		"result": "armor_military",
		"count": 1,
		"ingredients": {"metal": 8, "cloth": 5, "mat_nail": 5, "fiber": 3},
		"station": "workbench",
		"name": "军用护甲",
	},
	"helmet": {
		"result": "helmet",
		"count": 1,
		"ingredients": {"metal": 5, "cloth": 2, "mat_nail": 3},
		"station": "workbench",
		"name": "头盔",
	},

	# ===== 高级材料 =====
	"mat_steel_ingot": {
		"result": "mat_steel_ingot",
		"count": 1,
		"ingredients": {"metal": 3, "mat_chemical": 1, "wood": 2},
		"station": "furnace",
		"name": "钢锭",
	},
	"mat_gunpowder": {
		"result": "mat_gunpowder",
		"count": 2,
		"ingredients": {"mat_chemical": 2, "stone": 1, "wood": 1},
		"station": "workbench",
		"name": "火药",
	},
	"mat_electronic": {
		"result": "mat_electronic",
		"count": 1,
		"ingredients": {"metal": 2, "mat_plastic": 1, "mat_copper_scrap": 2},
		"station": "workbench",
		"name": "电子零件",
	},
	"mat_battery": {
		"result": "mat_battery",
		"count": 1,
		"ingredients": {"metal": 2, "mat_electronic": 1, "mat_chemical": 2, "mat_plastic": 1},
		"station": "workbench",
		"name": "电池",
	},
	"mat_fertilizer": {
		"result": "mat_fertilizer",
		"count": 2,
		"ingredients": {"mat_chemical": 1, "food_vegetable": 2, "wood": 1},
		"station": "composter",
		"name": "肥料",
	},
	"mat_rope": {
		"result": "mat_rope",
		"count": 2,
		"ingredients": {"fiber": 5},
		"station": "",
		"name": "绳索",
	},
	"mat_nail": {
		"result": "mat_nail",
		"count": 5,
		"ingredients": {"metal": 1},
		"station": "workbench",
		"name": "钉子",
	},

	# ===== 建筑材料 =====
	"wall_wood": {
		"result": "wall_wood",
		"count": 1,
		"ingredients": {"wood": 4},
		"station": "",
		"name": "木墙",
	},
	"stone_wall": {
		"result": "stone_wall",
		"count": 1,
		"ingredients": {"stone": 10, "wood": 2, "mat_nail": 2},
		"station": "workbench",
		"name": "石墙",
	},
	"metal_wall": {
		"result": "metal_wall",
		"count": 1,
		"ingredients": {"metal": 10, "stone": 5, "mat_nail": 5},
		"station": "workbench",
		"name": "金属墙",
	},
	"door_wood": {
		"result": "door_wood",
		"count": 1,
		"ingredients": {"wood": 6, "fiber": 2, "mat_nail": 2},
		"station": "",
		"name": "木门",
	},
	"trap": {
		"result": "trap",
		"count": 1,
		"ingredients": {"wood": 3, "stone": 4, "fiber": 2},
		"station": "",
		"name": "尖刺陷阱",
	},
	"tripwire_trap": {
		"result": "tripwire_trap",
		"count": 1,
		"ingredients": {"fiber": 5, "wood": 2, "metal": 1},
		"station": "",
		"name": "绊索陷阱",
	},
	"barbed_wire": {
		"result": "barbed_wire",
		"count": 1,
		"ingredients": {"metal": 6, "wood": 2, "mat_nail": 2},
		"station": "workbench",
		"name": "铁丝网",
	},
}


# 获取配方
func get_recipe(recipe_id: String) -> Dictionary:
	if _custom_recipes.has(recipe_id):
		return _custom_recipes[recipe_id]
	if RECIPES.has(recipe_id):
		return RECIPES[recipe_id]
	return {}


# 获取所有配方
func get_all_recipes() -> Dictionary:
	var result: Dictionary = RECIPES.duplicate()
	for recipe_id in _custom_recipes.keys():
		result[recipe_id] = _custom_recipes[recipe_id]
	return result


# 检查是否能制作（材料足够 + 工作站条件）
func can_craft(recipe_id: String, inventory: Node, station: String = "") -> bool:
	var recipe: Dictionary = get_recipe(recipe_id)
	if recipe.is_empty():
		return false
	# 检查工作站
	if recipe.station != "" and recipe.station != station:
		return false
	# 检查材料
	for mat_id in recipe.ingredients.keys():
		var needed: int = recipe.ingredients[mat_id]
		if not inventory.has_item(mat_id, needed):
			return false
	return true


# 执行制作（消耗材料，添加结果物品）
func craft(recipe_id: String, inventory: Node) -> bool:
	var recipe: Dictionary = get_recipe(recipe_id)
	if recipe.is_empty():
		return false
	# 检查材料
	for mat_id in recipe.ingredients.keys():
		var needed: int = recipe.ingredients[mat_id]
		if not inventory.has_item(mat_id, needed):
			return false
	# 消耗材料
	for mat_id in recipe.ingredients.keys():
		var needed: int = recipe.ingredients[mat_id]
		inventory.remove_item(mat_id, needed)
	# 添加结果
	inventory.add_item(recipe.result, recipe.count)
	print("[Craft] 制作了 %s x%d" % [recipe.name, recipe.count])
	return true


# 获取配方名称
func get_recipe_name(recipe_id: String) -> String:
	var recipe := get_recipe(recipe_id)
	if not recipe.is_empty():
		return recipe.get("name", "未知配方")
	return "未知配方"


# 获取配方所需的工作站
func get_recipe_station(recipe_id: String) -> String:
	var recipe := get_recipe(recipe_id)
	if not recipe.is_empty():
		return recipe.get("station", "")
	return ""


# 配方是否存在
func recipe_exists(recipe_id: String) -> bool:
	return _custom_recipes.has(recipe_id) or RECIPES.has(recipe_id)


# ==================== MOD扩展支持 ====================
## 运行时添加的自定义配方（MOD内容）
var _custom_recipes := {}


## 注册/覆盖一个配方（MOD使用）
func register_recipe(recipe_id: String, data: Dictionary) -> void:
	_custom_recipes[recipe_id] = data
	print("[RecipeDB] MOD注册配方: %s" % recipe_id)


## 取消注册一个配方
func unregister_recipe(recipe_id: String) -> void:
	if _custom_recipes.has(recipe_id):
		_custom_recipes.erase(recipe_id)
		print("[RecipeDB] MOD取消注册配方: %s" % recipe_id)


## 获取所有MOD添加的配方
func get_custom_recipes() -> Dictionary:
	return _custom_recipes.duplicate()


## 检查配方是否来自MOD
func is_custom_recipe(recipe_id: String) -> bool:
	return _custom_recipes.has(recipe_id)
