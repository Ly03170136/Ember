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


# ==================== 主机/客户端 ====================

func host_game(player_name: String = "Player", player_class: String = "warrior") -> void:
	local_player_class = player_class
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PLAYERS)
	if err != OK:
		push_error("Failed to create server: %d" % err)
		return
	multiplayer.multiplayer_peer = peer
	is_server = true
	is_connected = true
	local_peer_id = 1
	player_names[1] = player_name
	player_classes[1] = player_class
	print("[Server] Hosting on port %d, peer_id=1" % PORT)
	_start_game()


func join_game(ip: String, player_name: String = "Player", player_class: String = "warrior") -> void:
	local_player_class = player_class
	server_ip = ip
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, PORT)
	if err != OK:
		push_error("Failed to create client: %d" % err)
		return
	multiplayer.multiplayer_peer = peer
	is_server = false
	local_peer_id = 0  # will be set on connect
	player_names[0] = player_name  # temp, will update
	player_classes[0] = player_class  # temp, will update
	print("[Client] Connecting to %s:%d" % [ip, PORT])


func disconnect_game() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	is_connected = false
	is_server = false
	players.clear()
	player_names.clear()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


# ==================== 游戏世界 ====================

func _start_game() -> void:
	game_started.emit()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


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
	# 等距地图中心（瓦片坐标(25,25)对应的等距世界坐标）
	var map_center_x: float = 0.0
	var map_center_y: float = (25.0 + 25.0) * 32.0 / 2.0
	var map_center: Vector2 = Vector2(map_center_x, map_center_y)
	# 尝试通过IsometricMap寻找安全出生点
	var spawn_pos: Vector2 = map_center
	var main_scene: Node = get_tree().current_scene
	if main_scene and main_scene.has_node("IsometricMap"):
		var iso_map: Node = main_scene.get_node("IsometricMap")
		if iso_map and iso_map.has_method("find_safe_spawn_position"):
			spawn_pos = iso_map.find_safe_spawn_position(map_center)
	else:
		# 备用方案：随机出生点
		spawn_pos = map_center + Vector2(randf_range(-100, 100), randf_range(-100, 100))
	player.position = spawn_pos
	game_world.add_child(player)
	players[peer_id] = player
	print("[Spawn] Player %d (%s) spawned at %s" % [peer_id, player.player_name, str(player.position)])


func _despawn_player(peer_id: int) -> void:
	if players.has(peer_id):
		var player = players[peer_id]
		if is_instance_valid(player):
			player.queue_free()
		players.erase(peer_id)
		print("[Despawn] Player %d removed" % peer_id)


# ==================== 网络回调 ====================

func _on_peer_connected(peer_id: int) -> void:
	print("[Net] Peer connected: %d" % peer_id)
	player_joined.emit(peer_id)
	if is_server:
		# 服务器为新玩家生成角色
		_spawn_player(peer_id)
		# 通知所有玩家更新名字和职业
		_sync_player_names.rpc()
		_sync_player_classes.rpc()


func _on_peer_disconnected(peer_id: int) -> void:
	print("[Net] Peer disconnected: %d" % peer_id)
	player_left.emit(peer_id)
	if is_server:
		_despawn_player(peer_id)
		player_names.erase(peer_id)
		player_classes.erase(peer_id)
		_sync_player_names.rpc()
		_sync_player_classes.rpc()


func _on_connected_to_server() -> void:
	is_connected = true
	local_peer_id = multiplayer.get_unique_id()
	print("[Client] Connected! peer_id=%d" % local_peer_id)
	# 向服务器注册名字和职业
	_register_name.rpc_id(1, player_names.get(0, "Player"))
	_register_class.rpc_id(1, player_classes.get(0, "warrior"))
	_start_game()


func _on_connection_failed() -> void:
	print("[Client] Connection failed!")
	is_connected = false
	multiplayer.multiplayer_peer = null


func _on_server_disconnected() -> void:
	print("[Client] Server disconnected!")
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
	player_names[pid] = name
	print("[Name] Player %d registered as '%s'" % [pid, name])
	if is_server:
		_sync_player_names.rpc()


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
	return players.get(local_peer_id, null)


func is_local_player(peer_id: int) -> bool:
	return peer_id == local_peer_id
