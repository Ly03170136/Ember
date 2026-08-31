extends Node
## 网络实体管理器（NetworkManager）
##
## 【职责】
## 1. 分配全局唯一的 network_id
## 2. 维护实体注册表（network_id -> NetworkEntity）
## 3. 统一管理实体的生成/销毁广播
## 4. 新玩家加入时的全量状态同步
## 5. 提供 is_server / local_peer_id 等统一接口（包装 GameManager）
##
## 【与 GameManager 的分工】
## - GameManager：玩家管理、聊天、断线重连、游戏状态
## - NetworkManager：网络实体同步、生成/销毁广播、ID 分配
##
## 【使用方式】
## 服务器生成实体：
##   var zombie = NetworkManager.spawn_entity("res://scenes/entities/zombie.tscn", pos, {"type": "fast"})
##
## 服务器销毁实体：
##   NetworkManager.destroy_entity(zombie)
##
## 获取实体：
##   var entity = NetworkManager.get_entity(network_id)

signal entity_spawned(entity: Node)
signal entity_destroyed(network_id: int)

# ==================== 实体注册表 ====================

var entities: Dictionary = {}        # network_id -> NetworkEntity 节点
var _next_id: int = 1                # 下一个可用 ID

# ==================== 生成/销毁 ====================

func spawn_entity(scene_path: String, position: Vector2, data: Dictionary = {}, parent: Node = null) -> Node:
	## 【服务器调用】生成一个网络实体并广播给所有客户端
	##
	## scene_path: 场景资源路径
	## position: 生成位置
	## data: 初始属性数据（会设置到 NetworkEntity 上）
	## parent: 父节点，默认为当前场景的 WorldLayer
	##
	## 返回生成的实体节点（服务器端）
	if not is_server:
		push_error("[NetworkManager] spawn_entity 只能在服务器调用")
		return null

	var scene: PackedScene = load(scene_path)
	if scene == null:
		push_error("[NetworkManager] 无法加载场景: %s" % scene_path)
		return null

	var entity: Node = scene.instantiate()
	if entity is Node2D:
		entity.position = position

	# 确定父节点
	var target_parent: Node = parent
	if target_parent == null:
		var world: Node = get_tree().current_scene
		if world:
			target_parent = world.get_node_or_null("WorldLayer")
		if target_parent == null:
			target_parent = world

	if target_parent:
		target_parent.add_child(entity)
	else:
		add_child(entity)

	# 等待 NetworkEntity 组件注册
	await get_tree().process_frame

	# 设置初始属性
	var net_comp: Node = entity.get_node_or_null("NetworkEntity")
	if net_comp:
		for key in data.keys():
			net_comp.set_property(key, data[key])

	# 广播给所有客户端
	_broadcast_spawn.rpc(scene_path, position, data)

	entity_spawned.emit(entity)
	print("[NetManager] 生成实体: %s at %s, data=%s" % [scene_path, str(position), str(data)])
	return entity


@rpc("any_peer", "call_remote")
func _broadcast_spawn(scene_path: String, position: Vector2, data: Dictionary) -> void:
	## 【客户端调用】接收服务器的实体生成广播
	if is_server:
		return

	var scene: PackedScene = load(scene_path)
	if scene == null:
		push_error("[NetworkManager] 客户端无法加载场景: %s" % scene_path)
		return

	var entity: Node = scene.instantiate()
	if entity is Node2D:
		entity.position = position

	var world: Node = get_tree().current_scene
	var target_parent: Node = null
	if world:
		target_parent = world.get_node_or_null("WorldLayer")
	if target_parent == null:
		target_parent = world

	if target_parent:
		target_parent.add_child(entity)
	else:
		add_child(entity)

	# 设置初始属性
	await get_tree().process_frame
	var net_comp: Node = entity.get_node_or_null("NetworkEntity")
	if net_comp:
		for key in data.keys():
			net_comp._properties[key] = data[key]  # 客户端直接设置，不走 dirty

	entity_spawned.emit(entity)


func destroy_entity(entity: Node) -> void:
	## 【服务器调用】销毁一个网络实体并广播
	if not is_server:
		push_error("[NetworkManager] destroy_entity 只能在服务器调用")
		return

	var net_id: int = -1
	var net_comp: Node = entity.get_node_or_null("NetworkEntity")
	if net_comp:
		net_id = net_comp.network_id

	_broadcast_destroy.rpc(net_id)

	if is_instance_valid(entity):
		entity.queue_free()

	entity_destroyed.emit(net_id)
	print("[NetManager] 销毁实体: %s, network_id=%d" % [entity.name, net_id])


@rpc("any_peer", "call_remote")
func _broadcast_destroy(network_id: int) -> void:
	## 【客户端调用】接收服务器的实体销毁广播
	if is_server:
		return
	var entity: Node = get_entity_node(network_id)
	if entity and is_instance_valid(entity):
		entity.queue_free()
	entity_destroyed.emit(network_id)


# ==================== 实体注册表 ====================

func register_entity(comp: Node) -> int:
	## NetworkEntity 组件注册时调用，分配唯一 ID
	var id: int = _next_id
	_next_id += 1
	entities[id] = comp
	return id


func unregister_entity(network_id: int) -> void:
	entities.erase(network_id)


func get_entity(network_id: int) -> Node:
	## 获取 NetworkEntity 组件
	return entities.get(network_id, null)


func get_entity_node(network_id: int) -> Node:
	## 获取实体节点（NetworkEntity 的父节点）
	var comp: Node = entities.get(network_id, null)
	if comp and is_instance_valid(comp):
		return comp.get_parent()
	return null


func get_entity_count() -> int:
	return entities.size()


# ==================== 新玩家全量同步 ====================

func sync_all_entities_to_client(peer_id: int) -> void:
	## 【服务器调用】新玩家加入时，把所有现有实体同步给他
	if not is_server:
		return
	for net_id in entities.keys():
		var comp: Node = entities[net_id]
		if not comp or not is_instance_valid(comp):
			continue
		var entity: Node = comp.get_parent()
		if not entity or not is_instance_valid(entity):
			continue
		var scene_path: String = entity.scene_file_path
		if scene_path == "":
			continue
		var pos: Vector2 = entity.position if entity is Node2D else Vector2.ZERO
		var props: Dictionary = comp.get_all_properties()
		_broadcast_spawn.rpc_id(peer_id, scene_path, pos, props)
		print("[NetManager] 同步实体给新玩家 %d: %s" % [peer_id, scene_path])


# ==================== 统一接口（包装 GameManager） ====================

var is_active: bool = false        ## 联机是否激活（主机或已连接）
var is_server: bool = false         ## 是否是服务器/主机
var local_peer_id: int = 0          ## 本地玩家 peer_id


func _process(_delta: float) -> void:
	# 每帧同步 GameManager 的状态，保持变量实时更新
	if GameManager:
		is_active = GameManager.is_server or GameManager.is_connected
		is_server = GameManager.is_server
		local_peer_id = GameManager.local_peer_id
	else:
		is_active = false
		is_server = false
		local_peer_id = 0


func get_player_count() -> int:
	if GameManager:
		return GameManager.get_player_count()
	return 0
