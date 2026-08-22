extends "res://scripts/world/resource_node.gd"
## 可破坏树木脚本
## 功能：饥荒风格砍伐摇晃、倒下动画、树桩残留、掉落物品、自动重生

# ==================== 摇晃动画参数（弹簧阻尼系统） ====================
var sway_angle: float = 0.0           # 当前摇晃角度（度）
var sway_velocity: float = 0.0        # 摇晃角速度
var sway_damping: float = 0.85        # 阻尼（越小停得越快）
var sway_stiffness: float = 0.15      # 弹性（越大回弹越快）
var hit_direction: float = 1.0         # 砍伐方向（1=向右倒，-1=向左倒）
var natural_sway_timer: float = 0.0    # 自然微风摇晃计时器

# ==================== 倒下动画参数 ====================
var is_falling: bool = false           # 是否正在倒下
var fall_timer: float = 0.0            # 倒下动画计时器
var fall_duration: float = 0.6         # 倒下动画时长（秒）

# ==================== 节点引用 ====================
@onready var tree_sprite: Sprite2D = $TreeSprite
@onready var fallen_sprite: Sprite2D = $FallenSprite
@onready var stump_sprite: Sprite2D = $StumpSprite
@onready var stump_collision: CollisionShape2D = $StumpCollision


func _ready() -> void:
	# 初始化基础属性（不调用父类_ready，避免父类的程序化纹理生成）
	health = max_health
	add_to_group("resource")
	if area:
		area.body_entered.connect(_on_body_entered)
	
	# 初始化精灵状态
	if tree_sprite:
		tree_sprite.visible = true
	if fallen_sprite:
		fallen_sprite.visible = false
	if stump_sprite:
		stump_sprite.visible = false
	if stump_collision:
		stump_collision.disabled = true
	
	# 深度优化3：减少碰撞层，树木只和玩家碰撞，不和其他实体碰撞
	if self is CollisionObject2D:
		collision_layer = 1  # 树木在第1层
		collision_mask = 1   # 只检测第1层（玩家）


func hit(damage: float = 1.0, attacker_pos: Vector2 = Vector2.ZERO) -> void:
	## 被砍伐时调用
	## attacker_pos: 攻击者位置，用于计算砍伐方向
	if is_depleted or is_falling:
		return
	
	# 受击抖动反馈
	hit_shake_timer = 0.3
	
	# 计算砍伐方向（攻击者在左边则向右倒，反之亦然）
	if attacker_pos != Vector2.ZERO:
		hit_direction = 1.0 if attacker_pos.x < global_position.x else -1.0
	
	# 给一个初始角速度（饥荒风格的弹性摇晃）
	sway_velocity += hit_direction * 8.0
	
	# 只有服务器能修改资源状态
	if not GameManager.is_server:
		return
	
	health -= damage
	if health <= 0:
		_collect()


func _process(delta: float) -> void:
	# 深度优化：快速路径，完全静止的树直接返回，不做任何计算
	if not is_falling and not is_depleted and abs(sway_angle) <= 0.01 and abs(sway_velocity) <= 0.01 and hit_shake_timer <= 0:
		return
	
	if is_falling:
		_update_fall(delta)
		return
	
	if is_depleted:
		# 已采集状态，处理重生计时
		if respawn_time > 0:
			respawn_timer -= delta
			if respawn_timer <= 0:
				_respawn()
		return
	
	# 正常状态：只有在摇晃时才更新
	if abs(sway_angle) > 0.01 or abs(sway_velocity) > 0.01:
		_update_sway(delta)
	
	# 受击抖动计时
	if hit_shake_timer > 0:
		hit_shake_timer -= delta
	
	# 摇晃完全停止后重置精灵状态
	if abs(sway_angle) <= 0.01 and abs(sway_velocity) <= 0.01 and hit_shake_timer <= 0:
		if tree_sprite:
			tree_sprite.rotation = 0
			tree_sprite.position = Vector2.ZERO
		sway_angle = 0.0
		sway_velocity = 0.0


func _update_sway(delta: float) -> void:
	## 弹簧阻尼系统，模拟饥荒风格的树木摇晃
	# 弹簧阻尼计算
	sway_velocity += -sway_angle * sway_stiffness  # 弹性回正
	sway_velocity *= sway_damping                     # 阻尼衰减
	sway_angle += sway_velocity * delta               # 更新角度
	
	# 应用到精灵
	if tree_sprite:
		tree_sprite.rotation = deg_to_rad(sway_angle)
		tree_sprite.position.x = sway_angle * 0.5  # 轻微位置偏移


func _update_fall(delta: float) -> void:
	## 倒下动画
	fall_timer -= delta
	var progress: float = 1.0 - (fall_timer / fall_duration)
	
	if tree_sprite:
		# 从当前摇晃角度旋转到倒下角度（90度）
		var target_angle: float = hit_direction * 90.0
		tree_sprite.rotation = deg_to_rad(lerp(sway_angle, target_angle, progress))
		# 逐渐下沉
		tree_sprite.position.y = progress * 20
	
	if fall_timer <= 0:
		_finish_fall()


func _finish_fall() -> void:
	## 倒下完成，切换到树桩+倒木状态
	is_falling = false
	
	# 隐藏正常树木精灵
	if tree_sprite:
		tree_sprite.visible = false
		tree_sprite.rotation = 0
		tree_sprite.position = Vector2.ZERO
	
	# 显示倒下的树木精灵
	if fallen_sprite:
		fallen_sprite.visible = true
		fallen_sprite.rotation = deg_to_rad(hit_direction * 90.0)
		fallen_sprite.position.y = 10
	
	# 显示树桩精灵
	if stump_sprite:
		stump_sprite.visible = true
		stump_sprite.position = Vector2(0, 12)
	
	# 启用树桩碰撞
	if stump_collision:
		stump_collision.disabled = false
	
	# 掉落物品
	_drop_items()
	
	# 设置重生计时
	if respawn_time > 0:
		respawn_timer = respawn_time


func _collect() -> void:
	## 重写父类的采集函数，实现倒下动画而不是直接消失
	is_depleted = true
	health = 0
	
	# 开始倒下动画
	is_falling = true
	fall_timer = fall_duration
	
	# 禁用树木碰撞体（玩家可以穿过）
	var collision: CollisionShape2D = get_node_or_null("CollisionShape2D")
	if collision:
		collision.disabled = true


func _respawn() -> void:
	## 重写父类的重生函数，恢复所有状态
	is_depleted = false
	health = max_health
	is_falling = false
	sway_angle = 0.0
	sway_velocity = 0.0
	
	# 恢复正常树木精灵
	if tree_sprite:
		tree_sprite.visible = true
		tree_sprite.rotation = 0
		tree_sprite.position = Vector2.ZERO
	
	# 隐藏倒下的树木和树桩
	if fallen_sprite:
		fallen_sprite.visible = false
	if stump_sprite:
		stump_sprite.visible = false
	
	# 禁用树桩碰撞
	if stump_collision:
		stump_collision.disabled = true
	
	# 恢复树木碰撞
	var collision: CollisionShape2D = get_node_or_null("CollisionShape2D")
	if collision:
		collision.disabled = false


func _on_body_entered(body: Node) -> void:
	pass  # 后续处理交互提示
