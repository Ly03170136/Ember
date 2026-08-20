extends Node
## 科技树系统：公共科技 + 职业专属科技 + 书籍学习
## 自动加载为全局单例，通过 TechTree 访问

# ==================== 公共科技树（13节点） ====================
const PUBLIC_TECHS := {
	# T1 (1点)
	"common_t1_wood": {
		"name": "基础木工", "desc": "解锁木墙、木门、木箱", "cost": 1, "tier": 1,
		"requires": [], "category": "crafting",
	},
	"common_t1_stone": {
		"name": "石器工具", "desc": "解锁石斧、石镐、石矛", "cost": 1, "tier": 1,
		"requires": [], "category": "tools",
	},
	"common_t1_fire": {
		"name": "基础生火", "desc": "解锁篝火、火把", "cost": 1, "tier": 1,
		"requires": [], "category": "survival",
	},
	"common_t1_cloth": {
		"name": "基础纺织", "desc": "解锁布料、绷带、布衣", "cost": 1, "tier": 1,
		"requires": [], "category": "crafting",
	},
	# T2 (1点)
	"common_t2_cooking": {
		"name": "基础烹饪", "desc": "解锁篝火烹饪", "cost": 1, "tier": 2,
		"requires": ["common_t1_fire"], "category": "cooking",
	},
	"common_t2_metal": {
		"name": "基础冶炼", "desc": "解锁熔炉、铁锭、铜锭", "cost": 1, "tier": 2,
		"requires": ["common_t1_stone"], "category": "crafting",
	},
	"common_t2_medical": {
		"name": "基础医疗", "desc": "解锁消毒水、简易急救包", "cost": 1, "tier": 2,
		"requires": ["common_t1_cloth"], "category": "medical",
	},
	"common_t2_defense": {
		"name": "基础防御", "desc": "解锁尖刺陷阱、绊索陷阱", "cost": 1, "tier": 2,
		"requires": ["common_t1_wood"], "category": "defense",
	},
	# T3 (2点)
	"common_t3_gunpowder": {
		"name": "火药", "desc": "解锁简易火枪、子弹", "cost": 2, "tier": 3,
		"requires": ["common_t2_metal"], "category": "combat",
	},
	"common_t3_electric": {
		"name": "电力基础", "desc": "解锁发电机、电灯", "cost": 2, "tier": 3,
		"requires": ["common_t2_metal"], "category": "electric",
	},
	"common_t3_advanced_med": {
		"name": "高级医疗", "desc": "解锁高级急救包（不能救倒地）", "cost": 2, "tier": 3,
		"requires": ["common_t2_medical"], "category": "medical",
	},
	# T4 (3点)
	"common_t4_auto": {
		"name": "自动化基础", "desc": "解锁简易自动门、压力板", "cost": 3, "tier": 4,
		"requires": ["common_t3_electric"], "category": "electric",
	},
}

# ==================== 职业专属科技树（每职业4节点） ====================
const CLASS_TECHS := {
	"warrior": {
		"war_t1_combat": {"name": "近战精通", "desc": "近战伤害+15%", "cost": 1, "tier": 1, "requires": []},
		"war_t2_gun": {"name": "枪械训练", "desc": "解锁手枪、步枪", "cost": 1, "tier": 2, "requires": ["war_t1_combat"]},
		"war_t3_upgrade": {"name": "武器升级台", "desc": "可升级改造武器", "cost": 2, "tier": 3, "requires": ["war_t2_gun"]},
		"war_t4_mastery": {"name": "武器大师", "desc": "耐久消耗-25%，暴击+10%", "cost": 3, "tier": 4, "requires": ["war_t3_upgrade"]},
	},
	"builder": {
		"bld_t1_fast": {"name": "快速建造", "desc": "建造时间-30%", "cost": 1, "tier": 1, "requires": []},
		"bld_t2_stone": {"name": "石造建筑", "desc": "解锁石墙、石建筑", "cost": 1, "tier": 2, "requires": ["bld_t1_fast"]},
		"bld_t3_metal": {"name": "金属建筑", "desc": "解锁金属墙、金属建筑", "cost": 2, "tier": 3, "requires": ["bld_t2_stone"]},
		"bld_t4_auto": {"name": "远程建造", "desc": "可远程放置建筑", "cost": 3, "tier": 4, "requires": ["bld_t3_metal"]},
	},
	"doctor": {
		"doc_t1_rescue": {"name": "战地急救", "desc": "救援速度+50%，恢复40%生命", "cost": 1, "tier": 1, "requires": []},
		"doc_t2_pharm": {"name": "制药学", "desc": "解锁抗生素等药品", "cost": 1, "tier": 2, "requires": ["doc_t1_rescue"]},
		"doc_t3_surgery": {"name": "外科手术", "desc": "解锁手术包", "cost": 2, "tier": 3, "requires": ["doc_t2_pharm"]},
		"doc_t4_virus": {"name": "病毒研究", "desc": "病毒伤害-10%", "cost": 3, "tier": 4, "requires": ["doc_t3_surgery"]},
	},
	"farmer": {
		"far_t1_seed": {"name": "种子提取", "desc": "可从作物提取种子", "cost": 1, "tier": 1, "requires": []},
		"far_t2_fertile": {"name": "肥沃土壤", "desc": "作物生长+20%", "cost": 1, "tier": 2, "requires": ["far_t1_seed"]},
		"far_t3_greenhouse": {"name": "温室大棚", "desc": "解锁大棚，冬季可种植", "cost": 2, "tier": 3, "requires": ["far_t2_fertile"]},
		"far_t4_breed": {"name": "高级育种", "desc": "解锁高级作物", "cost": 3, "tier": 4, "requires": ["far_t3_greenhouse"]},
	},
	"mechanic": {
		"mec_t1_repair": {"name": "快速修理", "desc": "修车速度+50%", "cost": 1, "tier": 1, "requires": []},
		"mec_t2_mod": {"name": "改装台", "desc": "解锁载具改装", "cost": 1, "tier": 2, "requires": ["mec_t1_repair"]},
		"mec_t3_fuel": {"name": "节油技术", "desc": "油耗-30%", "cost": 2, "tier": 3, "requires": ["mec_t2_mod"]},
		"mec_t4_armor": {"name": "装甲车辆", "desc": "解锁装甲车", "cost": 3, "tier": 4, "requires": ["mec_t3_fuel"]},
	},
	"cook": {
		"cok_t1_recipe": {"name": "高级菜谱", "desc": "解锁高级食物", "cost": 1, "tier": 1, "requires": []},
		"cok_t2_preserve": {"name": "食物腌制", "desc": "解锁腌制食物", "cost": 1, "tier": 2, "requires": ["cok_t1_recipe"]},
		"cok_t3_boost": {"name": "营养强化", "desc": "食物效果+20%", "cost": 2, "tier": 3, "requires": ["cok_t2_preserve"]},
		"cok_t4_medfood": {"name": "药膳", "desc": "解锁药用食物", "cost": 3, "tier": 4, "requires": ["cok_t3_boost"]},
	},
	"lumberjack": {
		"lum_t1_strength": {"name": "力量训练", "desc": "负重+20%", "cost": 1, "tier": 1, "requires": []},
		"lum_t2_giant": {"name": "巨型伐木", "desc": "可砍伐巨型树木", "cost": 1, "tier": 2, "requires": ["lum_t1_strength"]},
		"lum_t3_efficiency": {"name": "高效采集", "desc": "采集速度+30%", "cost": 2, "tier": 3, "requires": ["lum_t2_giant"]},
		"lum_t4_woodart": {"name": "木制弩", "desc": "解锁木制弩", "cost": 3, "tier": 4, "requires": ["lum_t3_efficiency"]},
	},
	"engineer": {
		"eng_t1_circuit": {"name": "电路基础", "desc": "电力效率+30%", "cost": 1, "tier": 1, "requires": []},
		"eng_t2_grid": {"name": "电网扩展", "desc": "供电范围+50%", "cost": 1, "tier": 2, "requires": ["eng_t1_circuit"]},
		"eng_t3_turret": {"name": "自动炮塔", "desc": "解锁自动炮塔", "cost": 2, "tier": 3, "requires": ["eng_t2_grid"]},
		"eng_t4_automation": {"name": "自动化防御", "desc": "解锁自动门、自动陷阱", "cost": 3, "tier": 4, "requires": ["eng_t3_turret"]},
	},
}

# ==================== 书籍列表（8种） ====================
const BOOKS := {
	"book_med": {"name": "医学精通", "desc": "解锁医生职业树，+3科技点", "class_unlock": "doctor", "points": 3, "study_time": 7200.0, "locations": "医院/诊所"},
	"book_agri": {"name": "农业指南", "desc": "解锁农民职业树，+3科技点", "class_unlock": "farmer", "points": 3, "study_time": 5400.0, "locations": "农场/书店"},
	"book_eng": {"name": "工程制图", "desc": "解锁工匠职业树，+3科技点", "class_unlock": "builder", "points": 3, "study_time": 7200.0, "locations": "工地/五金店"},
	"book_mech": {"name": "汽车维修", "desc": "解锁汽修工职业树，+3科技点", "class_unlock": "mechanic", "points": 3, "study_time": 7200.0, "locations": "修车厂"},
	"book_cook": {"name": "高级菜谱", "desc": "解锁厨师职业树，+3科技点", "class_unlock": "cook", "points": 3, "study_time": 3600.0, "locations": "餐厅/厨房"},
	"book_elec": {"name": "电工手册", "desc": "解锁工程师职业树，+3科技点", "class_unlock": "engineer", "points": 3, "study_time": 9000.0, "locations": "军事基地/发电站"},
	"book_weapon": {"name": "武器改造", "desc": "解锁战士职业树，+3科技点", "class_unlock": "warrior", "points": 3, "study_time": 5400.0, "locations": "军事基地/枪店"},
	"book_lumber": {"name": "重型伐木", "desc": "解锁伐木工职业树，+3科技点", "class_unlock": "lumberjack", "points": 3, "study_time": 5400.0, "locations": "林场/工具店"},
}


# ==================== 查询方法 ====================

func get_tech(tech_id: String) -> Dictionary:
	if PUBLIC_TECHS.has(tech_id):
		return PUBLIC_TECHS[tech_id]
	for class_id in CLASS_TECHS.keys():
		if CLASS_TECHS[class_id].has(tech_id):
			return CLASS_TECHS[class_id][tech_id]
	return {}


func get_tech_name(tech_id: String) -> String:
	var tech: Dictionary = get_tech(tech_id)
	return tech.get("name", "未知科技")


func get_tech_cost(tech_id: String) -> int:
	var tech: Dictionary = get_tech(tech_id)
	return tech.get("cost", 1)


func get_tech_requires(tech_id: String) -> Array:
	var tech: Dictionary = get_tech(tech_id)
	return tech.get("requires", [])


func get_tech_tier(tech_id: String) -> int:
	var tech: Dictionary = get_tech(tech_id)
	return tech.get("tier", 1)


func is_public_tech(tech_id: String) -> bool:
	return PUBLIC_TECHS.has(tech_id)


func get_class_techs(class_id: String) -> Dictionary:
	return CLASS_TECHS.get(class_id, {})


func get_all_public_techs() -> Dictionary:
	return PUBLIC_TECHS


func get_techs_by_tier(tier: int) -> Array:
	var result: Array = []
	for tech_id in PUBLIC_TECHS.keys():
		if PUBLIC_TECHS[tech_id].tier == tier:
			result.append(tech_id)
	return result


func can_unlock_tech(tech_id: String, player: Node) -> bool:
	var tech: Dictionary = get_tech(tech_id)
	if tech.is_empty():
		return false
	# 已解锁
	if tech_id in player.unlocked_techs:
		return false
	# 检查前置科技
	for req_id in get_tech_requires(tech_id):
		if req_id not in player.unlocked_techs:
			return false
	# 检查科技点
	if player.skill_points < get_tech_cost(tech_id):
		return false
	# 职业专属科技检查
	if not is_public_tech(tech_id):
		var found: bool = false
		for class_id in CLASS_TECHS.keys():
			if CLASS_TECHS[class_id].has(tech_id):
				if player.player_class == class_id:
					found = true
				break
		if not found:
			return false
	return true


func unlock_tech(tech_id: String, player: Node) -> bool:
	if not can_unlock_tech(tech_id, player):
		return false
	player.skill_points -= get_tech_cost(tech_id)
	player.unlocked_techs.append(tech_id)
	print("[TechTree] %s 解锁了科技: %s" % [player.player_name, get_tech_name(tech_id)])
	return true


# ==================== 书籍学习 ====================

func get_book_info(book_id: String) -> Dictionary:
	return BOOKS.get(book_id, {})


func get_all_books() -> Dictionary:
	return BOOKS


func can_study_book(book_id: String, player: Node) -> bool:
	var book: Dictionary = get_book_info(book_id)
	if book.is_empty():
		return false
	# 已经学习过该职业树
	var class_unlock: String = book.get("class_unlock", "")
	if class_unlock != "" and player.player_class == class_unlock:
		return false  # 已经是该职业，不需要学习
	return true


func study_book(book_id: String, player: Node) -> bool:
	if not can_study_book(book_id, player):
		return false
	var book: Dictionary = get_book_info(book_id)
	var points: int = book.get("points", 3)
	player.add_skill_points(points)
	print("[TechTree] %s 学习了 %s，获得%d科技点" % [player.player_name, book.name, points])
	return true


func get_study_time(book_id: String) -> float:
	var book: Dictionary = get_book_info(book_id)
	return book.get("study_time", 3600.0)
