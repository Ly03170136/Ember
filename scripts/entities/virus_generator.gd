extends Node2D
## 病毒发生器：实验室副本的最终目标
## 玩家攻击摧毁后通关游戏

var health: float = 500.0
var max_health: float = 500.0
var _health_label: Label = null


func _ready() -> void:
	add_to_group("virus_generator")
	# 查找血量标签
	if has_node("HealthLabel"):
		_health_label = get_node("HealthLabel")
	_update_label()


func get_health() -> float:
	return health


func take_damage(amount: float, attacker: Node2D = null) -> void:
	health -= amount
	_update_label()
	print("[Generator] 病毒发生器受到%.0f伤害，剩余%.0f" % [amount, health])
	# 播放受击效果
	if AudioManager:
		AudioManager.play_sfx(AudioManager.SFX.HIT)
	# 检查是否被摧毁
	if health <= 0:
		_destroy()


func _update_label() -> void:
	if _health_label:
		_health_label.text = "病毒发生器: %d/%d" % [int(health), int(max_health)]


func _destroy() -> void:
	## 病毒发生器被摧毁
	print("[Generator] ===== 病毒发生器已摧毁！ =====")
	# 通知父节点（副本场景）
	if get_parent() and get_parent().has_method("_on_generator_destroyed"):
		get_parent()._on_generator_destroyed()
	# 播放爆炸效果
	if AudioManager:
		AudioManager.play_sfx(AudioManager.SFX.SUCCESS)
	# 延迟删除
	await get_tree().create_timer(0.5).timeout
	queue_free()
