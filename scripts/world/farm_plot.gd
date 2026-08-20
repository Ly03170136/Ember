extends Node2D
## 农田建筑：可种植作物，作物成熟后可收获
## 附加到农田建筑节点上使用

# 农田状态
enum State { EMPTY, PLANTED, GROWING, MATURE }

var state: int = State.EMPTY
var planted_seed: String = ""  # 种植的种子ID
var crop_id: String = ""  # 作物ID
var grow_progress: float = 0.0  # 生长进度 0-1
var grow_time: float = 150.0  # 总生长时间（秒）
var current_season: String = "spring"

# 应季作物配置
const SEASON_CROPS := {
	"spring": ["berry", "wheat", "potato", "cabbage"],
	"summer": ["berry", "corn", "potato"],
	"autumn": ["corn", "wheat", "potato", "cabbage"],
	"winter": []  # 冬季露地不能种植
}

@onready var sprite: Sprite2D = $Sprite
@onready var progress_bar: ProgressBar = null


func _ready() -> void:
	add_to_group("farm_plot")
	add_to_group("interactable")
	# 尝试获取进度条
	if has_node("ProgressBar"):
		progress_bar = $ProgressBar
	_update_appearance()


func _process(delta: float) -> void:
	if state == State.GROWING:
		# 获取当前季节
		var main: Node = get_tree().current_scene
		if main and main.has_method("get_season"):
			current_season = main.get_season()
		# 计算生长速度（应季作物正常生长，非应季减半，冬季停止）
		var grow_speed: float = 1.0
		if current_season == "winter":
			grow_speed = 0.0  # 冬季停止生长
		elif crop_id in SEASON_CROPS.get(current_season, []):
			grow_speed = 1.2  # 应季加速20%
		else:
			grow_speed = 0.5  # 非应季减半
		# 更新生长进度
		grow_progress += delta / grow_time * grow_speed
		if grow_progress >= 1.0:
			grow_progress = 1.0
			state = State.MATURE
			print("[Farm] 作物成熟: %s" % crop_id)
		_update_appearance()


func interact(player: Node) -> void:
	## 玩家交互：空地种植种子，成熟地收获
	if state == State.EMPTY:
		_try_plant(player)
	elif state == State.MATURE:
		_harvest(player)
	else:
		print("[Farm] 作物正在生长中: %.0f%%" % (grow_progress * 100))


func _try_plant(player: Node) -> void:
	## 尝试种植种子
	# 检查是否是农民职业（或已学习农业技能）
	var can_farm: bool = (player.player_class == "farmer")
	if not can_farm and player.has_method("has_tech"):
		can_farm = player.has_tech("farming")
	if not can_farm:
		print("[Farm] 只有农民或学习农业技能的人才能种植")
		return
	# 检查冬季
	if current_season == "winter":
		print("[Farm] 冬季无法在露地种植")
		return
	# 检查玩家背包里是否有种子
	if not player.inventory:
		return
	var seed_id: String = ""
	var seeds: Array = ["seed_carrot", "seed_potato", "seed_corn", "seed_berry", "seed_wheat", "seed_cabbage"]
	for s in seeds:
		if player.inventory.has_item(s, 1):
			seed_id = s
			break
	if seed_id == "":
		print("[Farm] 没有可种植的种子")
		return
	# 消耗种子
	player.inventory.remove_item(seed_id, 1)
	# 获取种子信息
	var seed_data: Dictionary = ItemDB.ITEMS.get(seed_id, {})
	crop_id = seed_data.get("crop", seed_id.replace("seed_", ""))
	grow_time = seed_data.get("grow_time", 150.0)
	planted_seed = seed_id
	grow_progress = 0.0
	state = State.GROWING
	print("[Farm] 种植了 %s，预计 %.0f 秒后成熟" % [seed_id, grow_time])
	_update_appearance()


func _harvest(player: Node) -> void:
	## 收获成熟作物
	if state != State.MATURE:
		return
	# 给玩家作物
	if player.inventory:
		var harvest_count: int = randi_range(2, 4)
		player.inventory.add_item(crop_id, harvest_count)
		print("[Farm] 收获了 %dx %s" % [harvest_count, crop_id])
	# 重置农田
	state = State.EMPTY
	planted_seed = ""
	crop_id = ""
	grow_progress = 0.0
	_update_appearance()


func _update_appearance() -> void:
	## 更新农田外观
	if not sprite:
		return
	match state:
		State.EMPTY:
			sprite.modulate = Color(0.45, 0.3, 0.15)  # 泥土色
		State.GROWING:
			# 生长中：颜色从浅绿到深绿
			var green: float = 0.3 + grow_progress * 0.4
			sprite.modulate = Color(0.3, green, 0.2)
		State.MATURE:
			sprite.modulate = Color(0.8, 0.7, 0.2)  # 成熟金黄色
	# 更新进度条
	if progress_bar:
		progress_bar.visible = state == State.GROWING
		progress_bar.value = grow_progress * 100
