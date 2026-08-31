extends StaticBody2D
## 资源节点基类：树、石头、浆果丛等可采集资源

@export var resource_name: String = "Resource"
@export var max_health: float = 50.0
@export var drop_item: String = "wood"  # 掉落物品ID
@export var drop_count: int = 3  # 每次采集掉落数量
@export var hit_count: int = 3  # 需要采集几次
@export var respawn_time: float = 60.0  # 重生时间（秒），0=不重生

var health: float = 0.0
var is_depleted: bool = false
var respawn_timer: float = 0.0

# 动画相关
var sway_timer: float = 0.0
var hit_shake_timer: float = 0.0
var base_scale: Vector2 = Vector2.ONE

@onready var sprite: Sprite2D = $Sprite
@onready var area: Area2D = $Area2D

static var _textures: Dictionary = {}


func _ready() -> void:
	health = max_health
	_generate_texture()
	add_to_group("resource")
	if area:
		area.body_entered.connect(_on_body_entered)


func _generate_texture() -> void:
	if not sprite:
		return
	if not _textures.has(resource_name):
		_textures[resource_name] = _make_resource_texture()
	sprite.texture = _textures[resource_name]


func _make_resource_texture() -> Texture2D:
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := size / 2.0
	if resource_name == "Tree":
		# 树干
		for x in range(28, 36):
			for y in range(32, 56):
				img.set_pixel(x, y, Color(0.4, 0.25, 0.1, 1))
		# 树冠
		var cr := 24.0
		for x in range(size):
			for y in range(size):
				var dx := x - center
				var dy := y - (center - 6)
				if dx * dx + dy * dy <= cr * cr:
					img.set_pixel(x, y, Color(0.2, 0.55, 0.2, 1))
	elif resource_name == "Rock":
		var rr := 22.0
		for x in range(size):
			for y in range(size):
				var dx := x - center
				var dy := y - center
				var d := dx * dx + dy * dy
				if d <= rr * rr:
					var n := sin(x * 0.5) * cos(y * 0.3) * 0.1
					img.set_pixel(x, y, Color(0.55 + n, 0.55 + n, 0.6 + n, 1))
	elif resource_name == "BerryBush":
		# 灌木丛
		var br := 20.0
		for x in range(size):
			for y in range(size):
				var dx := x - center
				var dy := y - center
				if dx * dx + dy * dy <= br * br:
					img.set_pixel(x, y, Color(0.25, 0.5, 0.25, 1))
		# 浆果点
		for bx in [22, 38, 30, 42, 20]:
			for by in [24, 28, 40, 36, 44]:
				img.set_pixel(bx, by, Color(0.8, 0.1, 0.1, 1))
				img.set_pixel(bx+1, by, Color(0.8, 0.1, 0.1, 1))
				img.set_pixel(bx, by+1, Color(0.8, 0.1, 0.1, 1))
	else:
		var rr := 20.0
		for x in range(size):
			for y in range(size):
				var dx := x - center
				var dy := y - center
				if dx * dx + dy * dy <= rr * rr:
					img.set_pixel(x, y, Color(0.5, 0.5, 0.5, 1))
	return ImageTexture.create_from_image(img)


func _process(delta: float) -> void:
	# 深度优化：快速路径，没有被采集、没有抖动时直接返回
	if not is_depleted and hit_shake_timer <= 0:
		return
	
	if is_depleted:
		if respawn_time > 0:
			respawn_timer -= delta
			if respawn_timer <= 0:
				_respawn()
		return

	# 只有采集抖动时才更新（去掉了不必要的摇晃和呼吸动画）
	if hit_shake_timer > 0:
		hit_shake_timer -= delta
		var shake: float = sin(hit_shake_timer * 40) * 0.1 * (hit_shake_timer / 0.3)
		if sprite:
			sprite.position.x = shake * 20
			if hit_shake_timer <= 0 and sprite:
				sprite.position.x = 0


func hit(damage: float = 1.0, attacker_pos: Vector2 = Vector2.ZERO) -> void:
	if is_depleted:
		return
	# 客户端：通过main.gd通知服务器（通过位置查找，不依赖节点名）
	if not GameManager.is_server:
		print("[Resource] 客户端攻击资源: ", resource_name, " 位置: ", position, " 伤害: ", damage)
		var main: Node = get_tree().current_scene
		if main and main.has_method("_rpc_request_resource_hit"):
			main._rpc_request_resource_hit.rpc_id(1, position.x, position.y, damage)
		return
	# 服务器：执行受击逻辑
	_server_hit(damage)


func _server_hit(damage: float) -> void:
	## 服务器端受击处理：抖动 + 扣血 + 广播抖动
	hit_shake_timer = 0.3
	print("[Resource] 服务器受击: ", resource_name, " 位置: ", position, " 伤害: ", damage, " 剩余血量: ", health - damage)
	# 广播抖动给所有客户端
	_rpc_resource_shake.rpc()
	health -= damage
	if health <= 0:
		print("[Resource] 资源被采集: ", resource_name, " 位置: ", position)
		_collect()


@rpc("any_peer", "call_local")
func _rpc_request_hit(damage: float) -> void:
	## 客户端请求服务器处理资源受击
	if not GameManager.is_server:
		return
	print("[Resource] 收到客户端攻击请求: ", resource_name, " 位置: ", position, " 伤害: ", damage)
	if is_depleted:
		# 资源已经被采集，重新广播采集状态给请求的客户端
		var main: Node = get_tree().current_scene
		if main and main.has_method("_on_resource_collected"):
			main._on_resource_collected(position)
		return
	_server_hit(damage)


@rpc("any_peer", "call_remote")
func _rpc_resource_shake() -> void:
	## 客户端接收抖动广播
	if GameManager.is_server:
		return
	hit_shake_timer = 0.3


func _collect() -> void:
	is_depleted = true
	health = 0
	if sprite:
		sprite.visible = false
	# 禁用碰撞，让玩家可以穿过
	var collision: CollisionShape2D = get_node_or_null("CollisionShape2D")
	if collision:
		collision.disabled = true
	# 掉落物品（给附近玩家）
	_drop_items()
	if respawn_time > 0:
		respawn_timer = respawn_time
	else:
		queue_free()
	# 服务器：广播采集状态给所有客户端
	if GameManager.is_server:
		var main: Node = get_tree().current_scene
		if main and main.has_method("_on_resource_collected"):
			main._on_resource_collected(position)


func _set_collected_state(collected: bool) -> void:
	## 客户端：设置采集状态（由服务器同步调用）
	is_depleted = collected
	health = 0 if collected else max_health
	if collected:
		# 关键：设置重生计时器，否则 _process 会立即触发 _respawn()
		respawn_timer = respawn_time
	else:
		respawn_timer = 0.0
	print("[Resource] _set_collected_state: ", resource_name, " collected=", collected, " sprite=", sprite, " sprite_valid=", is_instance_valid(sprite), " respawn_timer=", respawn_timer)
	if sprite and is_instance_valid(sprite):
		sprite.visible = not collected
		print("[Resource] sprite.visible 设置为: ", sprite.visible)
	else:
		print("[Resource] 警告：sprite 为 null 或无效！")
	var collision: CollisionShape2D = get_node_or_null("CollisionShape2D")
	if collision:
		collision.disabled = collected


func _drop_items() -> void:
	# 查找附近的玩家，将物品添加到玩家背包
	var players := get_tree().get_nodes_in_group("player")
	var nearest_player: Node = null
	var nearest_dist: float = 9999.0
	for player in players:
		if player and is_instance_valid(player):
			var dist: float = global_position.distance_to(player.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest_player = player
	# 如果找到附近玩家（150像素范围内），将物品添加到背包
	if nearest_player and nearest_dist < 150.0:
		var peer_id: int = nearest_player.get_multiplayer_authority()
		# 检查玩家是否有本地 inventory（主机玩家有，客户端玩家在服务器端的副本没有）
		var inv = nearest_player.get("inventory")
		if inv != null and inv.has_method("add_item"):
			# 主机玩家：直接添加
			var added: int = inv.add_item(drop_item, drop_count)
			print("[Resource] %s collected, added %dx %s to %s's inventory (本地)" % [resource_name, added, drop_item, nearest_player.player_name])
		else:
			# 客户端玩家：通过 RPC 通知客户端添加物品
			if nearest_player.has_method("_rpc_add_item"):
				nearest_player._rpc_add_item.rpc_id(peer_id, drop_item, drop_count)
				print("[Resource] %s collected, RPC通知客户端%d添加 %dx %s" % [resource_name, peer_id, drop_count, drop_item])
			else:
				print("[Resource] %s collected, 玩家没有_rpc_add_item方法" % resource_name)
	else:
		print("[Resource] %s collected, dropped %dx %s (no nearby player, dist=%.1f)" % [resource_name, drop_count, drop_item, nearest_dist])


func _respawn() -> void:
	is_depleted = false
	health = max_health
	if sprite:
		sprite.visible = true
	# 恢复碰撞
	var collision: CollisionShape2D = get_node_or_null("CollisionShape2D")
	if collision:
		collision.disabled = false
	# 服务器：广播重生状态给所有客户端
	if GameManager.is_server:
		var main: Node = get_tree().current_scene
		if main and main.has_method("_on_resource_respawned"):
			main._on_resource_respawned(position)


func _on_body_entered(body: Node) -> void:
	pass  # 后续处理交互提示
