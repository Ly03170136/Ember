extends Node
## 全局事件总线 - 解耦系统间通信
## 用于玩家受伤、丧尸死亡、建筑被摧毁等事件的发布和订阅
## 使用方式：
##   订阅：EventBus.player_damaged.connect(_on_player_damaged)
##   发布：EventBus.player_damaged.emit(player, damage, source)

# ==================== 信号定义 ====================

# --- 玩家相关事件 ---
signal player_damaged(player, damage: float, source)
signal player_healed(player, amount: float, source)
signal player_died(player)
signal player_down(player)  # 玩家倒地（重伤）
signal player_revived(player, medic)  # 玩家被救起
signal player_joined(player_name: String, profession: String)
signal player_left(player_name: String)
signal profession_changed(player, new_profession: String)
signal level_up(player, new_level: int)
signal stat_changed(player, stat_name: String, new_value)

# --- 丧尸/敌人相关事件 ---
signal zombie_spawned(zombie, zombie_type: String)
signal zombie_damaged(zombie, damage: float, source)
signal zombie_died(zombie, killer)
signal zombie_infected_human(human_npc)
signal horde_started(day: int, zombie_count: int)
signal horde_ended(day: int)

# --- 建筑相关事件 ---
signal building_placed(building, building_type: String, position: Vector2)
signal building_damaged(building, damage: float, source)
signal building_destroyed(building, building_type: String)
signal building_upgraded(building, new_level: int)
signal building_repaired(building, repair_amount: float)

# --- 资源/物品相关事件 ---
signal resource_collected(resource_type: String, amount: int, collector)
signal item_crafted(item_id: String, amount: int, crafter)
signal item_picked_up(item_id: String, amount: int, player)
signal item_dropped(item_id: String, amount: int, position: Vector2)
signal inventory_full(player)

# --- 世界/环境相关事件 ---
signal day_changed(new_day: int)
signal season_changed(new_season: String)
signal month_changed(new_month: int)
signal weather_changed(new_weather: String, duration: float)
signal time_of_day_changed(time: float)  # 0.0-1.0
signal night_started()
signal day_started()
signal temperature_changed(new_temp: float)

# --- 病毒/感染相关事件 ---
signal virus_spread(tile_position: Vector2, infection_level: float)
signal human_infected(human_npc, infection_time: float)
signal human_turned_zombie(human_npc)
signal lab_destroyed()  # 实验室被摧毁（通关）
signal lab_entered(player)

# --- 载具相关事件 ---
signal vehicle_entered(vehicle, player)
signal vehicle_exited(vehicle, player)
signal vehicle_damaged(vehicle, damage: float, source)
signal vehicle_destroyed(vehicle)
signal vehicle_repaired(vehicle, repair_amount: float)

# --- 战斗相关事件 ---
signal attack_made(attacker, target, damage: float, weapon: String)
signal critical_hit(attacker, target, damage: float)
signal enemy_killed(enemy, killer, exp_gained: int)

# --- 任务/成就相关事件 ---
signal quest_accepted(quest_id: String)
signal quest_completed(quest_id: String, reward)
signal achievement_unlocked(achievement_id: String, player)

# --- 系统相关事件 ---
signal game_started()
signal game_ended(victory: bool)
signal game_paused()
signal game_resumed()
signal save_loaded(save_slot: int)
signal save_saved(save_slot: int)
signal settings_changed(setting_name: String, new_value)

# ==================== 内部状态 ====================

var _event_log: Array = []  # 事件日志（用于调试）
var _max_log_size: int = 100  # 最大日志条数
var _enable_logging: bool = true  # 是否启用事件日志

# ==================== 生命周期 ====================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[EventBus] 全局事件总线已启动")
	if GameLogger:
		GameLogger.info("全局事件总线已启动", "EventBus")


# ==================== 辅助方法 ====================

func log_event(event_name: String, args: Array = []) -> void:
	## 记录事件到日志（用于调试）
	if not _enable_logging:
		return
	var log_entry: Dictionary = {
		"time": Time.get_datetime_string_from_system(),
		"event": event_name,
		"args": args
	}
	_event_log.append(log_entry)
	if _event_log.size() > _max_log_size:
		_event_log.pop_front()


func get_event_log() -> Array:
	## 获取事件日志
	return _event_log.duplicate()


func clear_event_log() -> void:
	## 清空事件日志
	_event_log.clear()


func set_logging_enabled(enabled: bool) -> void:
	## 设置是否启用事件日志
	_enable_logging = enabled


func is_logging_enabled() -> bool:
	## 获取是否启用事件日志
	return _enable_logging


# ==================== 常用事件发布辅助方法 ====================
# 这些方法提供了更简洁的事件发布方式，同时自动记录日志

## 玩家受伤
func publish_player_damaged(player, damage: float, source = null) -> void:
	log_event("player_damaged", [player, damage, source])
	player_damaged.emit(player, damage, source)

## 玩家治愈
func publish_player_healed(player, amount: float, source = null) -> void:
	log_event("player_healed", [player, amount, source])
	player_healed.emit(player, amount, source)

## 玩家死亡
func publish_player_died(player) -> void:
	log_event("player_died", [player])
	player_died.emit(player)

## 玩家倒地
func publish_player_down(player) -> void:
	log_event("player_down", [player])
	player_down.emit(player)

## 玩家被救起
func publish_player_revived(player, medic) -> void:
	log_event("player_revived", [player, medic])
	player_revived.emit(player, medic)

## 丧尸生成
func publish_zombie_spawned(zombie, zombie_type: String) -> void:
	log_event("zombie_spawned", [zombie, zombie_type])
	zombie_spawned.emit(zombie, zombie_type)

## 丧尸受伤
func publish_zombie_damaged(zombie, damage: float, source = null) -> void:
	log_event("zombie_damaged", [zombie, damage, source])
	zombie_damaged.emit(zombie, damage, source)

## 丧尸死亡
func publish_zombie_died(zombie, killer = null) -> void:
	log_event("zombie_died", [zombie, killer])
	zombie_died.emit(zombie, killer)

## 建筑放置
func publish_building_placed(building, building_type: String, position: Vector2) -> void:
	log_event("building_placed", [building, building_type, position])
	building_placed.emit(building, building_type, position)

## 建筑受伤
func publish_building_damaged(building, damage: float, source = null) -> void:
	log_event("building_damaged", [building, damage, source])
	building_damaged.emit(building, damage, source)

## 建筑被摧毁
func publish_building_destroyed(building, building_type: String) -> void:
	log_event("building_destroyed", [building, building_type])
	building_destroyed.emit(building, building_type)

## 建筑升级
func publish_building_upgraded(building, new_level: int) -> void:
	log_event("building_upgraded", [building, new_level])
	building_upgraded.emit(building, new_level)

## 资源采集
func publish_resource_collected(resource_type: String, amount: int, collector = null) -> void:
	log_event("resource_collected", [resource_type, amount, collector])
	resource_collected.emit(resource_type, amount, collector)

## 物品制作
func publish_item_crafted(item_id: String, amount: int, crafter = null) -> void:
	log_event("item_crafted", [item_id, amount, crafter])
	item_crafted.emit(item_id, amount, crafter)

## 天数变更
func publish_day_changed(new_day: int) -> void:
	log_event("day_changed", [new_day])
	day_changed.emit(new_day)

## 季节变更
func publish_season_changed(new_season: String) -> void:
	log_event("season_changed", [new_season])
	season_changed.emit(new_season)

## 天气变更
func publish_weather_changed(new_weather: String, duration: float) -> void:
	log_event("weather_changed", [new_weather, duration])
	weather_changed.emit(new_weather, duration)

## 夜晚开始
func publish_night_started() -> void:
	log_event("night_started")
	night_started.emit()

## 白天开始
func publish_day_started() -> void:
	log_event("day_started")
	day_started.emit()

## 尸潮开始
func publish_horde_started(day: int, zombie_count: int) -> void:
	log_event("horde_started", [day, zombie_count])
	horde_started.emit(day, zombie_count)

## 尸潮结束
func publish_horde_ended(day: int) -> void:
	log_event("horde_ended", [day])
	horde_ended.emit(day)

## 游戏开始
func publish_game_started() -> void:
	log_event("game_started")
	game_started.emit()

## 游戏结束
func publish_game_ended(victory: bool) -> void:
	log_event("game_ended", [victory])
	game_ended.emit(victory)

## 游戏暂停
func publish_game_paused() -> void:
	log_event("game_paused")
	game_paused.emit()

## 游戏恢复
func publish_game_resumed() -> void:
	log_event("game_resumed")
	game_resumed.emit()

## 存档加载
func publish_save_loaded(save_slot: int) -> void:
	log_event("save_loaded", [save_slot])
	save_loaded.emit(save_slot)

## 存档保存
func publish_save_saved(save_slot: int) -> void:
	log_event("save_saved", [save_slot])
	save_saved.emit(save_slot)
