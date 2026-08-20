extends Node
## 背包组件：管理物品格子、堆叠、负重
## 附加到玩家节点上使用

const SLOT_COUNT := 30       # 背包总格子数
const QUICKBAR_COUNT := 9    # 快捷栏格子数（前9格）
const MAX_WEIGHT := 50.0     # 最大负重

var slots: Array = []         # 背包格子数组，每个元素是 {id: String, count: int} 或 null
var selected_slot: int = 0    # 当前选中的快捷栏格子


func _ready() -> void:
	# 初始化空格子
	for i in range(SLOT_COUNT):
		slots.append(null)


# ==================== 基础操作 ====================

# 添加物品，返回实际添加的数量
func add_item(item_id: String, count: int) -> int:
	if not ItemDB.item_exists(item_id):
		return 0
	var max_stack: int = ItemDB.get_max_stack(item_id)
	var remaining: int = count
	# 先尝试堆叠到已有格子
	for i in range(SLOT_COUNT):
		if remaining <= 0:
			break
		if slots[i] != null and slots[i].id == item_id and slots[i].count < max_stack:
			var can_add: int = min(remaining, max_stack - slots[i].count)
			# 检查负重
			var add_weight: float = can_add * ItemDB.get_weight(item_id)
			if get_total_weight() + add_weight > MAX_WEIGHT:
				can_add = int(floor((MAX_WEIGHT - get_total_weight()) / ItemDB.get_weight(item_id)))
				if can_add <= 0:
					break
			slots[i].count += can_add
			remaining -= can_add
	# 再放到空格子
	for i in range(SLOT_COUNT):
		if remaining <= 0:
			break
		if slots[i] == null:
			var can_add: int = min(remaining, max_stack)
			var add_weight: float = can_add * ItemDB.get_weight(item_id)
			if get_total_weight() + add_weight > MAX_WEIGHT:
				can_add = int(floor((MAX_WEIGHT - get_total_weight()) / ItemDB.get_weight(item_id)))
				if can_add <= 0:
					break
			slots[i] = {"id": item_id, "count": can_add}
			remaining -= can_add
	var added: int = count - remaining
	if added > 0:
		emit_signal("inventory_changed")
	return added


# 移除物品，返回实际移除的数量
func remove_item(item_id: String, count: int) -> int:
	var remaining: int = count
	for i in range(SLOT_COUNT):
		if remaining <= 0:
			break
		if slots[i] != null and slots[i].id == item_id:
			var can_remove: int = min(remaining, slots[i].count)
			slots[i].count -= can_remove
			remaining -= can_remove
			if slots[i].count <= 0:
				slots[i] = null
	var removed: int = count - remaining
	if removed > 0:
		emit_signal("inventory_changed")
	return removed


# 获取某物品总数
func get_item_count(item_id: String) -> int:
	var total: int = 0
	for slot in slots:
		if slot != null and slot.id == item_id:
			total += slot.count
	return total


# 是否有足够的物品
func has_item(item_id: String, count: int) -> bool:
	return get_item_count(item_id) >= count


# 获取某格物品
func get_slot(index: int) -> Dictionary:
	if index >= 0 and index < SLOT_COUNT and slots[index] != null:
		return slots[index]
	return {}


# 设置某格物品
func set_slot(index: int, item: Dictionary) -> void:
	if index >= 0 and index < SLOT_COUNT:
		if item.is_empty() or item.count <= 0:
			slots[index] = null
		else:
			slots[index] = item
		emit_signal("inventory_changed")


# 交换两格物品
func swap_slots(index1: int, index2: int) -> void:
	if index1 >= 0 and index1 < SLOT_COUNT and index2 >= 0 and index2 < SLOT_COUNT:
		var temp: Variant = slots[index1]
		slots[index1] = slots[index2]
		slots[index2] = temp
		emit_signal("inventory_changed")


# 获取总重量
func get_total_weight() -> float:
	var total: float = 0.0
	for slot in slots:
		if slot != null:
			total += slot.count * ItemDB.get_weight(slot.id)
	return total


# 是否能添加指定数量的物品
func can_add(item_id: String, count: int) -> bool:
	var current_weight: float = get_total_weight()
	var add_weight: float = count * ItemDB.get_weight(item_id)
	return current_weight + add_weight <= MAX_WEIGHT


# 获取当前选中的快捷栏物品
func get_selected_item() -> Dictionary:
	return get_slot(selected_slot)


# 选中快捷栏格子
func select_slot(index: int) -> void:
	if index >= 0 and index < QUICKBAR_COUNT:
		selected_slot = index
		emit_signal("selected_slot_changed", selected_slot)


# 使用当前选中的物品（如食物、药品）
func use_selected_item() -> bool:
	var item: Dictionary = get_selected_item()
	if item.is_empty():
		return false
	var item_id: String = item.id
	var item_data: Dictionary = ItemDB.get_item(item_id)
	# 食物
	if item_data.type == ItemDB.ItemType.FOOD:
		if item_data.has("hunger_restore") and get_parent().has_method("restore_hunger"):
			get_parent().restore_hunger(item_data.hunger_restore)
		if item_data.has("thirst_restore") and get_parent().has_method("restore_thirst"):
			get_parent().restore_thirst(item_data.thirst_restore)
		if item_data.has("health_restore") and get_parent().has_method("heal"):
			get_parent().heal(item_data.health_restore)
		remove_item(item_id, 1)
		return true
	# 药品
	if item_data.type == ItemDB.ItemType.MEDICINE:
		if item_data.has("health_restore") and get_parent().has_method("heal"):
			get_parent().heal(item_data.health_restore)
		remove_item(item_id, 1)
		return true
	# 书籍
	if item_data.has("book_type"):
		var book_type: String = item_data.book_type
		if get_parent().has_method("learn_book"):
			get_parent().learn_book(book_type)
		remove_item(item_id, 1)
		return true
	return false


# ==================== 存档/同步 ====================

# 获取背包数据（用于存档/网络同步）
func get_inventory_data() -> Array:
	var data: Array = []
	for slot in slots:
		if slot != null:
			data.append({"id": slot.id, "count": slot.count})
		else:
			data.append(null)
	return data


# 加载背包数据
func load_inventory_data(data: Array) -> void:
	slots = data.duplicate(true)
	emit_signal("inventory_changed")


# 清空背包
func clear() -> void:
	for i in range(SLOT_COUNT):
		slots[i] = null
	emit_signal("inventory_changed")


# ==================== 食物腐烂系统 ====================

# 更新食物腐烂（受季节和天气影响）
func update_food_rot(season: String, weather: String) -> void:
	var rot_chance: float = 0.005  # 基础腐烂概率
	# 季节影响
	match season:
		"summer":
			rot_chance *= 2.0  # 夏天腐烂加倍
		"winter":
			rot_chance *= 0.3  # 冬天腐烂减慢
		"spring":
			rot_chance *= 0.8
		"autumn":
			rot_chance *= 0.9
	# 天气影响
	match weather:
		"storm", "rain":
			rot_chance *= 1.3  # 潮湿天气加速腐烂
		"snow":
			rot_chance *= 0.5  # 雪天减慢腐烂
	# 遍历所有物品，食物有概率腐烂
	var changed: bool = false
	for i in range(SLOT_COUNT):
		if slots[i] == null:
			continue
		var item_id: String = slots[i].id
		if ItemDB.is_food(item_id):
			# 检查是否有冰箱保存（简化：暂不实现）
			if randf() < rot_chance:
				slots[i].count -= 1
				if slots[i].count <= 0:
					slots[i] = null
				changed = true
				print("[Inventory] 食物腐烂: %s" % item_id)
	if changed:
		emit_signal("inventory_changed")


# ==================== 信号 ====================

signal inventory_changed
signal selected_slot_changed(index)
