extends Node
## NPC数据库：定义所有NPC类型、属性和行为模板
## 自动加载为全局单例，通过 NPCDB 访问
##
## 采用混合架构：基础NPC类型硬编码保证稳定，MOD通过JSON动态加载扩展

# ==================== 基础NPC类型（硬编码默认值） ====================
const NPC_TYPES := {
	"civilian": {
		"name": "市民",
		"speed": 40.0,
		"max_health": 50.0,
		"color": Color(0.7, 0.6, 0.5),
		"scale": 1.0,
		"is_police": false,
		"behavior": "civilian",
		"can_trade": false,
		"trade_items": [],
		"dialogue_tree": "",
		"spawn_weight": 10,
		"faction": "civilian",
	},
	"police": {
		"name": "警察",
		"speed": 60.0,
		"max_health": 100.0,
		"color": Color(0.2, 0.3, 0.6),
		"scale": 1.1,
		"is_police": true,
		"damage": 15.0,
		"attack_range": 50.0,
		"attack_cooldown": 1.0,
		"behavior": "police",
		"can_trade": false,
		"trade_items": [],
		"dialogue_tree": "",
		"spawn_weight": 3,
		"faction": "police",
	},
}

# ==================== 行为模板注册表 ====================
## 内置行为模板名称（实际逻辑在npc.gd中实现）
const BUILTIN_BEHAVIORS := ["civilian", "police"]

## MOD注册的自定义行为模板 {行为名: 描述}
var _custom_behaviors := {}


# ==================== MOD扩展支持 ====================
## 运行时添加的自定义NPC类型（MOD内容）
var _custom_npcs := {}


## 注册/覆盖一个NPC类型（MOD使用）
## 如果npc_type已存在，会覆盖原有类型
func register_npc(npc_type: String, data: Dictionary) -> void:
	# 颜色字段转换：如果是数组则转成Color
	var converted: Dictionary = data.duplicate()
	if converted.has("color") and converted.color is Array:
		var c = converted.color
		converted.color = Color(c[0], c[1], c[2], c[3] if c.size() > 3 else 1.0)
	_custom_npcs[npc_type] = converted
	print("[NPCDB] MOD注册NPC类型: %s" % npc_type)


## 取消注册一个NPC类型
func unregister_npc(npc_type: String) -> void:
	if _custom_npcs.has(npc_type):
		_custom_npcs.erase(npc_type)
		print("[NPCDB] MOD取消注册NPC类型: %s" % npc_type)


## 注册一个自定义行为模板（MOD使用）
## 注意：行为逻辑需要MOD脚本实现并连接到NPC的行为钩子
func register_behavior(behavior_name: String, description: String = "") -> void:
	_custom_behaviors[behavior_name] = description
	print("[NPCDB] MOD注册行为模板: %s" % behavior_name)


## 取消注册一个行为模板
func unregister_behavior(behavior_name: String) -> void:
	if _custom_behaviors.has(behavior_name):
		_custom_behaviors.erase(behavior_name)
		print("[NPCDB] MOD取消注册行为模板: %s" % behavior_name)


# ==================== 查询方法 ====================

## 获取NPC类型配置
func get_npc(npc_type: String) -> Dictionary:
	if _custom_npcs.has(npc_type):
		return _custom_npcs[npc_type]
	if NPC_TYPES.has(npc_type):
		return NPC_TYPES[npc_type]
	return {}


## 获取NPC名称
func get_npc_name(npc_type: String) -> String:
	var npc := get_npc(npc_type)
	return npc.get("name", "未知NPC")


## 获取NPC最大生命值
func get_npc_max_health(npc_type: String) -> float:
	var npc := get_npc(npc_type)
	return npc.get("max_health", 50.0)


## 获取NPC移动速度
func get_npc_speed(npc_type: String) -> float:
	var npc := get_npc(npc_type)
	return npc.get("speed", 40.0)


## 获取NPC颜色
func get_npc_color(npc_type: String) -> Color:
	var npc := get_npc(npc_type)
	return npc.get("color", Color(1, 1, 1))


## 获取NPC缩放
func get_npc_scale(npc_type: String) -> float:
	var npc := get_npc(npc_type)
	return npc.get("scale", 1.0)


## 获取NPC行为模板名
func get_npc_behavior(npc_type: String) -> String:
	var npc := get_npc(npc_type)
	return npc.get("behavior", "civilian")


## NPC是否是警察
func is_police(npc_type: String) -> bool:
	var npc := get_npc(npc_type)
	return npc.get("is_police", false)


## NPC是否可以交易
func can_trade(npc_type: String) -> bool:
	var npc := get_npc(npc_type)
	return npc.get("can_trade", false)


## 获取NPC可交易物品列表
func get_trade_items(npc_type: String) -> Array:
	var npc := get_npc(npc_type)
	return npc.get("trade_items", [])


## 获取NPC对话树ID
func get_dialogue_tree(npc_type: String) -> String:
	var npc := get_npc(npc_type)
	return npc.get("dialogue_tree", "")


## 获取NPC阵营
func get_faction(npc_type: String) -> String:
	var npc := get_npc(npc_type)
	return npc.get("faction", "neutral")


## 获取NPC生成权重
func get_spawn_weight(npc_type: String) -> int:
	var npc := get_npc(npc_type)
	return npc.get("spawn_weight", 1)


## NPC类型是否存在
func npc_exists(npc_type: String) -> bool:
	return _custom_npcs.has(npc_type) or NPC_TYPES.has(npc_type)


## 获取所有NPC类型
func get_all_npcs() -> Dictionary:
	var result: Dictionary = NPC_TYPES.duplicate()
	for npc_type in _custom_npcs.keys():
		result[npc_type] = _custom_npcs[npc_type]
	return result


## 获取所有MOD添加的NPC类型
func get_custom_npcs() -> Dictionary:
	return _custom_npcs.duplicate()


## 检查NPC是否来自MOD
func is_custom_npc(npc_type: String) -> bool:
	return _custom_npcs.has(npc_type)


# ==================== 行为模板查询 ====================

## 行为是否存在（内置或MOD注册）
func behavior_exists(behavior_name: String) -> bool:
	return behavior_name in BUILTIN_BEHAVIORS or _custom_behaviors.has(behavior_name)


## 是否是内置行为
func is_builtin_behavior(behavior_name: String) -> bool:
	return behavior_name in BUILTIN_BEHAVIORS


## 获取所有已注册的行为模板
func get_all_behaviors() -> Array:
	var result: Array = BUILTIN_BEHAVIORS.duplicate()
	for behavior_name in _custom_behaviors.keys():
		result.append(behavior_name)
	return result


## 获取MOD添加的行为模板
func get_custom_behaviors() -> Dictionary:
	return _custom_behaviors.duplicate()


# ==================== 生成相关 ====================

## 根据权重随机选择一个NPC类型（用于生成系统）
func get_random_npc_type() -> String:
	var all_npcs := get_all_npcs()
	var total_weight := 0
	for npc_type in all_npcs.keys():
		total_weight += get_spawn_weight(npc_type)
	
	if total_weight <= 0:
		return "civilian"
	
	var roll := randi() % total_weight
	var current := 0
	for npc_type in all_npcs.keys():
		current += get_spawn_weight(npc_type)
		if roll < current:
			return npc_type
	
	return "civilian"


## 获取指定阵营的所有NPC类型
func get_npcs_by_faction(faction: String) -> Array:
	var result := []
	var all_npcs := get_all_npcs()
	for npc_type in all_npcs.keys():
		if get_faction(npc_type) == faction:
			result.append(npc_type)
	return result
