extends Node
## 游戏全局管理器（自动加载）
## 处理联机、玩家管理、游戏状态、聊天

signal player_joined(peer_id: int)
signal player_left(peer_id: int)
signal chat_received(peer_id: int, message: String)
signal game_started()

const PORT := 7777
const MAX_PLAYERS := 4
const PLAYER_SCENE := preload("res://scenes/entities/player.tscn")

var is_server := false
var is_connected := false
var server_ip := "127.0.0.1"
var players: Dictionary = {}  # peer_id -> player_node
var player_names: Dictionary = {}  # peer_id -> name
var player_classes: Dictionary = {}  # peer_id -> class_id
var local_peer_id := 0
var local_player_class: String = "warrior"
var game_world: Node2D = null
var chat_history: Array = []
var player_name: String = "幸存者"  # 玩家名称

# 断线重连系统
var disconnected_players: Dictionary = {}  # player_name -> {peer_id, position, health, hunger, thirst, stamina, level, experience, class, color, disconnect_time}
var reconnect_timeout: float = -1.0  # 重连超时时间（秒），-1表示永不超时，玩家可随时离开随时加入
var _reconnect_timer: float = 0.0  # 清理超时断线玩家的计时器

# 游戏状态
var infection_complete: bool = false  # 病毒是否已扩散全图
var game_completed: bool = false  # 游戏是否通关（实验室被摧毁）

# 世界种子（用于客户端和服务器生成相同的随机世界）
var world_seed: int = 12345  # 默认固定种子，服务器启动时可随机化
var world_seed_received: bool = false  # 客户端是否已收到服务器的世界种子

# 玩家颜色（用于区分不同玩家）
const PLAYER_COLORS := [
	Color("#ff6b6b"), Color("#4ecdc4"), Color("#ffe66d"), Color("#95e1d3"),
	Color("#f38181"), Color("#aa96da"), Color("#fcbad3"), Color("#a8d8ea")
]


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _process(delta: float) -> void:
	# 定期清理超时的断线玩家（每10秒检查一次，reconnect_timeout为-1时跳过）
	if reconnect_timeout < 0:
		return
	_reconnect_timer += delta
	if _reconnect_timer >= 10.0:
		_reconnect_timer = 0.0
		if is_server and not disconnected_players.is_empty():
			_cleanup_timeout_disconnected_players()


# ==================== 主机/客户端 ====================

func host_game(player_name: String = "Player", player_class: String = "warrior") -> void:
	local_player_class = player_class
	# 先重置网络状态，避免重复创建导致失败
	reset_network_state()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PLAYERS)
	if err != OK:
		push_error("Failed to create server: %d" % err)
		GameLogger.error("创建主机失败，端口: %d, 错误码: %d" % [PORT, err], "Network")
		return
	multiplayer.multiplayer_peer = peer
	is_server = true
	is_connected = true
	local_peer_id = 1
	player_names[1] = player_name
	player_classes[1] = player_class
	print("[Server] Hosting on port %d, peer_id=1" % PORT)
	GameLogger.info("创建主机，端口: %d, 玩家: %s, 职业: %s" % [PORT, player_name, player_class], "Network")
	_start_game()


func join_game(ip: String, player_name: String = "Player", player_class: String = "warrior") -> void:
	local_player_class = player_class
	server_ip = ip
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, PORT)
	if err != OK:
		push_error("Failed to create client: %d" % err)
		GameLogger.error("加入游戏失败，IP: %s, 错误码: %d" % [ip, err], "Network")
		return
	multiplayer.multiplayer_peer = peer
	is_server = false
	local_peer_id = 0  # will be set on connect
	player_names[0] = player_name  # temp, will update
	player_classes[0] = player_class  # temp, will update
	print("[Client] Connecting to %s:%d" % [ip, PORT])
	GameLogger.info("加入主机: %s:%d, 玩家: %s" % [ip, PORT, player_name], "Network")


func disconnect_game() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	is_connected = false
	is_server = false
	players.clear()
	player_names.clear()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func reset_network_state() -> void:
	## 重置网络状态（返回主菜单时调用，不切换场景）
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	is_connected = false
	is_server = false
	players.clear()
	player_names.clear()
	player_classes.clear()
	game_world = null
	print("[GameManager] 网络状态已重置")


# ==================== 游戏世界 ====================

func _start_game() -> void:
	game_started.emit()
	# 使用加载管理器统一入口异步加载场景
	print("[GameManager] 开始加载游戏场景...")
	var load_data: Dictionary = {
		"is_multiplayer": is_server or is_connected,
		"is_server": is_server
	}
	LoadManager.load_scene("res://scenes/main.tscn", load_data, true)


func set_game_world(world: Node2D) -> void:
	game_world = world
	# 主机为所有已连接玩家生成角色
	if is_server:
		for pid: int in player_names.keys():
			_spawn_player(pid)


func _spawn_player(peer_id: int) -> void:
	if not game_world:
		return
	if players.has(peer_id):
		return
	var player: CharacterBody2D = PLAYER_SCENE.instantiate()
	player.name = "Player_%d" % peer_id
	player.peer_id = peer_id
	player.player_name = player_names.get(peer_id, "Player")
	player.player_class = player_classes.get(peer_id, "warrior")
	player.player_color = PLAYER_COLORS[peer_id % PLAYER_COLORS.size()]
	# 玩家初始生成位置：X轴=0, Y轴=0（地图左上角）
	var spawn_pos: Vector2 = Vector2(0, 0)
	player.position = spawn_pos
	game_world.add_child(player)
	# 设置多人权限，让客户端的 is_local() 正确返回 true
	player.set_multiplayer_authority(peer_id)
	players[peer_id] = player
	print("[Spawn] Player %d (%s) spawned at %s, authority=%d" % [peer_id, player.player_name, str(player.position), peer_id])
	# 通过 RPC 通知所有客户端生成玩家节点（替代不可靠的 MultiplayerSpawner）
	_spawn_player_remote.rpc(peer_id, player.player_name, player.player_class, spawn_pos)


@rpc("any_peer", "call_local")
func _spawn_player_remote(pid: int, pname: String, pclass: String, pos: Vector2) -> void:
	## 在客户端生成玩家节点（由服务器调用，同步到所有客户端）
	if game_world == null:
		print("[Spawn] 警告：game_world 为 null，无法生成玩家 %d" % pid)
		return
	var node_name := "Player_%d" % pid
	if game_world.has_node(node_name):
		print("[Spawn] 玩家 %d 已存在，跳过生成" % pid)
		return
	var player: CharacterBody2D = PLAYER_SCENE.instantiate()
	player.name = node_name
	player.peer_id = pid
	player.player_name = pname
	player.player_class = pclass
	player.position = pos
	game_world.add_child(player)
	player.set_multiplayer_authority(pid)
	players[pid] = player  # 注册到players字典，否则get_local_player()返回null
	print("[Spawn] 客户端生成玩家 %d (%s) at %s, is_local=%s, 已注册到players字典" % [pid, pname, str(pos), str(player.is_local())])


func _despawn_player(peer_id: int) -> void:
	if players.has(peer_id):
		var player = players[peer_id]
		if is_instance_valid(player):
			player.queue_free()
		players.erase(peer_id)
		print("[Despawn] Player %d removed" % peer_id)
	# 通知所有客户端移除玩家节点
	_despawn_player_remote.rpc(peer_id)


@rpc("any_peer", "call_local")
func _despawn_player_remote(pid: int) -> void:
	## 在客户端移除玩家节点
	if game_world == null:
		return
	var node_name := "Player_%d" % pid
	if game_world.has_node(node_name):
		var player = game_world.get_node(node_name)
		if is_instance_valid(player):
			player.queue_free()
		print("[Despawn] 客户端移除玩家 %d" % pid)


# ==================== 断线重连系统 ====================

func _save_disconnected_player(peer_id: int) -> void:
	# 保存断线玩家的数据，用于重连
	if not players.has(peer_id):
		return
	var player = players[peer_id]
	if not is_instance_valid(player):
		return
	# 保存物品栏数据
	var inventory_data = []
	var selected_slot = 0
	if player.has_node("Inventory"):
		var inv = player.get_node("Inventory")
		if inv and inv.has_method("get_inventory_data"):
			inventory_data = inv.get_inventory_data()
		if inv and "selected_slot" in inv:
			selected_slot = inv.selected_slot
	var player_data = {
		"peer_id": peer_id,
		"name": player_names.get(peer_id, "Player"),
		"class": player_classes.get(peer_id, "warrior"),
		"color": player.player_color,
		"position": player.position,
		"health": player.health,
		"max_health": player.max_health,
		"hunger": player.hunger,
		"thirst": player.thirst,
		"stamina": player.stamina,
		"level": player.level,
		"experience": player.experience,
		"attribute_points": player.attribute_points,
		"tech_points": player.tech_points,
		"strength": player.strength,
		"agility": player.agility,
		"vitality": player.vitality,
		"stealth": player.stealth,
		"sanity": player.sanity,
		"is_sick": player.is_sick,
		"sickness_type": player.sickness_type,
		"inventory_slots": inventory_data,
		"selected_slot": selected_slot,
		"disconnect_time": Time.get_ticks_msec() / 1000.0
	}
	var name = player_names.get(peer_id, "Player")
	disconnected_players[name] = player_data
	print("[Reconnect] Saved disconnected player '%s' (peer_id=%d) with %d inventory items for reconnection" % [name, peer_id, inventory_data.size()])


func _restore_disconnected_player(peer_id: int, player_data: Dictionary) -> void:
	# 恢复断线玩家的数据
	if not players.has(peer_id):
		return
	var player = players[peer_id]
	if not is_instance_valid(player):
		return
	player.position = player_data.get("position", Vector2.ZERO)
	player.health = player_data.get("health", 100.0)
	player.max_health = player_data.get("max_health", 100.0)
	player.hunger = player_data.get("hunger", 100.0)
	player.thirst = player_data.get("thirst", 100.0)
	player.stamina = player_data.get("stamina", 100.0)
	player.level = player_data.get("level", 1)
	player.experience = player_data.get("experience", 0.0)
	player.attribute_points = player_data.get("attribute_points", 0)
	player.tech_points = player_data.get("tech_points", 0)
	player.strength = player_data.get("strength", 5)
	player.agility = player_data.get("agility", 5)
	player.vitality = player_data.get("vitality", 5)
	player.stealth = player_data.get("stealth", 5)
	player.sanity = player_data.get("sanity", 100.0)
	player.is_sick = player_data.get("is_sick", false)
	player.sickness_type = player_data.get("sickness_type", "")
	# 恢复物品栏数据
	if player.has_node("Inventory"):
		var inv = player.get_node("Inventory")
		var inventory_data = player_data.get("inventory_slots", [])
		var selected_slot = player_data.get("selected_slot", 0)
		if inv and inv.has_method("load_inventory_data"):
			inv.load_inventory_data(inventory_data)
		if inv and "selected_slot" in inv:
			inv.selected_slot = selected_slot
		print("[Reconnect] Restored %d inventory items for player '%s'" % [inventory_data.size(), player_names.get(peer_id, "Player")])
	print("[Reconnect] Restored player '%s' data (peer_id=%d)" % [player_names.get(peer_id, "Player"), peer_id])


func _cleanup_timeout_disconnected_players() -> void:
	# 清理超时的断线玩家数据（reconnect_timeout为-1时永不清理）
	if reconnect_timeout < 0:
		return
	var current_time = Time.get_ticks_msec() / 1000.0
	var to_remove = []
	for name in disconnected_players.keys():
		var data = disconnected_players[name]
		var disconnect_time = data.get("disconnect_time", 0.0)
		if current_time - disconnect_time > reconnect_timeout:
			to_remove.append(name)
	for name in to_remove:
		disconnected_players.erase(name)
		print("[Reconnect] Removed timeout disconnected player '%s'" % name)


func is_player_disconnected(player_name: String) -> bool:
	# 检查玩家是否在断线列表中
	return disconnected_players.has(player_name)


func get_disconnected_player_data(player_name: String) -> Dictionary:
	# 获取断线玩家的数据
	if disconnected_players.has(player_name):
		return disconnected_players[player_name]
	return {}


# ==================== 网络回调 ====================

func _on_peer_connected(peer_id: int) -> void:
	print("[Net] Peer connected: %d" % peer_id)
	GameLogger.info("玩家加入，peer_id: %d" % peer_id, "Network")
	player_joined.emit(peer_id)
	if is_server:
		# 不在连接时立即生成玩家，等待客户端场景加载完成后通过 _client_ready 通知
		# 这样可以确保 MultiplayerSpawner 同步时客户端已准备好
		_sync_player_names.rpc()
		_sync_player_classes.rpc()


@rpc("any_peer", "call_local")
func _client_ready() -> void:
	## 客户端通知服务器：场景已加载完成，可以生成玩家角色了
	var pid := multiplayer.get_remote_sender_id()
	if pid == 0:
		pid = local_peer_id
	print("[Net] Client ready RPC received: pid=%d, is_server=%s, game_world=%s" % [pid, str(is_server), str(game_world != null)])
	if is_server and game_world:
		if players.has(pid):
			print("[Net] 玩家 %d 已存在，跳过生成" % pid)
		else:
			_spawn_player(pid)
		_sync_player_names.rpc()
		_sync_player_classes.rpc()
		# 把世界种子发给客户端，让客户端生成相同的随机世界
		_receive_world_seed.rpc_id(pid, world_seed)
		print("[Net] 已发送世界种子 %d 给客户端 %d" % [world_seed, pid])
		# 把所有已存在的玩家都同步给新客户端（解决主机玩家在客户端连接前生成导致看不到的问题）
		for existing_pid in players.keys():
			var existing_player = players[existing_pid]
			if is_instance_valid(existing_player):
				_spawn_player_remote.rpc_id(pid, existing_pid, existing_player.player_name, existing_player.player_class, existing_player.position)
				print("[Net] 同步已存在玩家 %d (%s) 给新客户端 %d" % [existing_pid, existing_player.player_name, pid])
	elif not is_server:
		print("[Net] 警告：_client_ready 在非服务器端执行，is_server=%s" % str(is_server))
	elif not game_world:
		print("[Net] 警告：game_world 为 null，无法生成玩家")


@rpc("any_peer", "call_local")
func _receive_world_seed(seed_val: int) -> void:
	## 客户端接收服务器发来的世界种子，设置全局随机数生成器
	world_seed = seed_val
	world_seed_received = true
	seed(seed_val)
	print("[Net] 客户端收到世界种子: %d，已设置全局随机种子" % seed_val)


func _on_peer_disconnected(peer_id: int) -> void:
	print("[Net] Peer disconnected: %d" % peer_id)
	GameLogger.info("玩家离开，peer_id: %d" % peer_id, "Network")
	player_left.emit(peer_id)
	if is_server:
		# 保存断线玩家数据用于重连
		_save_disconnected_player(peer_id)
		# 移除玩家角色
		_despawn_player(peer_id)
		player_names.erase(peer_id)
		player_classes.erase(peer_id)
		_sync_player_names.rpc()
		_sync_player_classes.rpc()


func _on_connected_to_server() -> void:
	is_connected = true
	local_peer_id = multiplayer.get_unique_id()
	print("[Client] Connected! peer_id=%d" % local_peer_id)
	GameLogger.info("连接服务器成功，peer_id: %d" % local_peer_id, "Network")
	# 向服务器注册名字和职业
	_register_name.rpc_id(1, player_names.get(0, "Player"))
	_register_class.rpc_id(1, player_classes.get(0, "warrior"))
	_start_game()


func _on_connection_failed() -> void:
	print("[Client] Connection failed!")
	GameLogger.error("连接服务器失败", "Network")
	is_connected = false
	multiplayer.multiplayer_peer = null


func _on_server_disconnected() -> void:
	print("[Client] Server disconnected!")
	GameLogger.warning("服务器断开连接", "Network")
	is_connected = false
	multiplayer.multiplayer_peer = null
	players.clear()
	player_names.clear()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


# ==================== RPC ====================

@rpc("any_peer", "call_local")
func _register_name(name: String) -> void:
	var pid := multiplayer.get_remote_sender_id()
	if pid == 0:
		pid = local_peer_id
	# 检查是否是断线重连
	if is_server and disconnected_players.has(name):
		var old_data = disconnected_players[name]
		var old_peer_id = old_data.get("peer_id", 0)
		print("[Reconnect] Player '%s' is reconnecting! Old peer_id=%d, New peer_id=%d" % [name, old_peer_id, pid])
		GameLogger.info("玩家重连: %s, 旧peer_id=%d, 新peer_id=%d" % [name, old_peer_id, pid], "Network")
		# 从断线列表中移除
		disconnected_players.erase(name)
		# 恢复玩家职业
		player_classes[pid] = old_data.get("class", "warrior")
		# 延迟恢复玩家数据（等待玩家角色生成完成）
		_restore_player_data_delayed.rpc_id(pid, old_data)
	player_names[pid] = name
	print("[Name] Player %d registered as '%s'" % [pid, name])
	if is_server:
		_sync_player_names.rpc()
		_sync_player_classes.rpc()


@rpc("any_peer")
func _restore_player_data_delayed(player_data: Dictionary) -> void:
	# 延迟恢复玩家数据（等待角色生成完成）
	var pid = multiplayer.get_remote_sender_id()
	if pid == 0:
		pid = local_peer_id
	# 等待一帧让玩家角色生成完成
	await get_tree().process_frame
	if players.has(pid):
		_restore_disconnected_player(pid, player_data)
		print("[Reconnect] Player data restored for peer_id=%d" % pid)


@rpc("any_peer")
func _sync_player_names() -> void:
	# 服务器同步所有玩家名字给客户端
	if is_server:
		_receive_names.rpc(player_names)
	else:
		# 客户端忽略，等待服务器推送
		pass


@rpc("any_peer")
func _receive_names(names: Dictionary) -> void:
	player_names = names.duplicate()
	print("[Names] Synced %d player names" % player_names.size())


@rpc("any_peer", "call_local")
func _register_class(class_id: String) -> void:
	var pid := multiplayer.get_remote_sender_id()
	if pid == 0:
		pid = local_peer_id
	player_classes[pid] = class_id
	print("[Class] Player %d registered as '%s'" % [pid, class_id])
	if is_server:
		_sync_player_classes.rpc()


@rpc("any_peer")
func _sync_player_classes() -> void:
	if is_server:
		_receive_classes.rpc(player_classes)
	else:
		pass


@rpc("any_peer")
func _receive_classes(classes: Dictionary) -> void:
	player_classes = classes.duplicate()
	print("[Classes] Synced %d player classes" % player_classes.size())


@rpc("any_peer", "call_local")
func send_chat(message: String) -> void:
	var pid := multiplayer.get_remote_sender_id()
	if pid == 0:
		pid = local_peer_id
	var name: String = player_names.get(pid, "Unknown")
	var formatted: String = "[%s] %s" % [name, message]
	chat_history.append(formatted)
	chat_received.emit(pid, message)
	print("[Chat] %s" % formatted)
	# 广播给所有玩家
	if is_server:
		_broadcast_chat.rpc(pid, message)


@rpc("any_peer")
func _broadcast_chat(peer_id: int, message: String) -> void:
	var name: String = player_names.get(peer_id, "Unknown")
	var formatted: String = "[%s] %s" % [name, message]
	chat_history.append(formatted)
	chat_received.emit(peer_id, message)


# ==================== 工具函数 ====================

func get_player_count() -> int:
	return players.size()


func get_local_player() -> CharacterBody2D:
	var player = players.get(local_peer_id, null)
	if player and is_instance_valid(player):
		return player
	return null


func is_local_player(peer_id: int) -> bool:
	return peer_id == local_peer_id
