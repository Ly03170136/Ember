extends Node
## 网络同步组件（NetworkEntity）
##
## 【用途】
## 附加到任何需要联机同步的实体（玩家、丧尸、NPC、建筑、掉落物等）上，
## 提供统一的位置同步、属性同步、生成/销毁管理。
##
## 【为什么用组件而不是基类】
## 项目中实体继承链不统一（CharacterBody2D / StaticBody2D / Node2D），
## 用组件模式可以不破坏现有继承结构，逐步迁移。
##
## 【使用方式】
## 1. 在场景中给实体添加一个 Node 子节点，挂此脚本
## 2. 在实体的 _ready() 中获取引用：network_entity = $NetworkEntity
## 3. 声明需要同步的属性：network_entity.declare_property("hp", 100.0)
## 4. 服务器修改属性：network_entity.set_property("hp", 80.0)
## 5. 客户端读取属性：network_entity.get_property("hp")
## 6. 监听属性变化：network_entity.state_changed.connect(_on_state_changed)
##
## 【同步模型】
## - 服务器权威：只有服务器能修改属性和位置
## - 位置同步：服务器定期发送位置，客户端插值
## - 属性同步：dirty flag 机制，只同步变化的属性
## - 生成/销毁：通过 NetworkManager 统一广播
##
## 【注意】
## 此组件不处理物理/移动逻辑，只负责同步。
## 实体的移动逻辑仍在实体自身脚本中，服务器计算后位置自动同步。

signal state_changed(changes: Dictionary)  # 属性变化时触发（客户端）

# ==================== 配置 ====================

@export var sync_position: bool = true          ## 是否同步位置
@export var position_sync_interval: float = 0.1  ## 位置同步间隔（秒），默认10Hz
@export var state_sync_interval: float = 0.2     ## 属性同步间隔（秒），默认5Hz
@export var interpolation_speed: float = 10.0    ## 客户端位置插值速度
@export var interpolation_enabled: bool = true   ## 是否启用位置插值

# ==================== 运行时状态 ====================

var network_id: int = -1                          ## 全局唯一网络实体ID
var _entity: Node2D = null                        ## 父实体引用
var _registered: bool = false

# 位置同步
var _interp_target: Vector2 = Vector2.ZERO
var _has_interp_target: bool = false
var _pos_sync_timer: float = 0.0

# 属性同步
var _properties: Dictionary = {}                  ## 所有已声明的属性
var _dirty_properties: Dictionary = {}            ## 变化待同步的属性
var _state_sync_timer: float = 0.0

# ==================== 生命周期 ====================

func _ready() -> void:
	_entity = get_parent()
	if not _entity is Node2D:
		push_error("[NetworkEntity] 必须附加到 Node2D 或其子类上，当前父节点: %s" % _entity.get_class())
		return
	# 注册到 NetworkManager
	if NetworkManager:
		network_id = NetworkManager.register_entity(self)
		_registered = true
		print("[NetEntity] 注册实体: %s, network_id=%d" % [_entity.name, network_id])
	else:
		push_warning("[NetworkEntity] NetworkManager 未加载，同步功能不可用")


func _exit_tree() -> void:
	if _registered and NetworkManager:
		NetworkManager.unregister_entity(network_id)
		_registered = false


func _process(delta: float) -> void:
	if not _entity or not NetworkManager or not NetworkManager.is_active():
		return
	if NetworkManager.is_server:
		_server_process(delta)
	else:
		_client_process(delta)


# ==================== 服务器逻辑 ====================

func _server_process(delta: float) -> void:
	# 位置同步
	if sync_position:
		_pos_sync_timer += delta
		if _pos_sync_timer >= position_sync_interval:
			_pos_sync_timer = 0.0
			_sync_position.rpc(_entity.position)

	# 属性同步（只同步变化的属性）
	_state_sync_timer += delta
	if _state_sync_timer >= state_sync_interval and not _dirty_properties.is_empty():
		_state_sync_timer = 0.0
		var changes: Dictionary = _dirty_properties.duplicate()
		_dirty_properties.clear()
		_sync_state.rpc(changes)


# ==================== 客户端逻辑 ====================

func _client_process(delta: float) -> void:
	# 位置插值
	if sync_position and interpolation_enabled and _has_interp_target:
		_entity.position = _entity.position.lerp(_interp_target, delta * interpolation_speed)


# ==================== 属性 API（服务器调用） ====================

func declare_property(name: String, default_value) -> void:
	## 声明一个需要同步的属性（在 _ready 中调用）
	## 重复声明不会覆盖已有值
	if not _properties.has(name):
		_properties[name] = default_value


func set_property(name: String, value) -> void:
	## 设置属性值（仅服务器有效），自动标记为待同步
	if not NetworkManager or not NetworkManager.is_server:
		return
	if _properties.get(name, null) == value:
		return  # 值未变化，跳过
	_properties[name] = value
	_dirty_properties[name] = value


func set_properties(data: Dictionary) -> void:
	## 批量设置属性（仅服务器有效）
	for key in data.keys():
		set_property(key, data[key])


func force_sync() -> void:
	## 强制立即同步所有属性（用于新玩家加入时的全量同步）
	if not NetworkManager or not NetworkManager.is_server:
		return
	if not _properties.is_empty():
		_sync_state.rpc(_properties.duplicate())


# ==================== 属性 API（所有端调用） ====================

func get_property(name: String, default = null):
	## 获取属性值
	return _properties.get(name, default)


func has_property(name: String) -> bool:
	return _properties.has(name)


func get_all_properties() -> Dictionary:
	return _properties.duplicate()


# ==================== 位置 RPC ====================

@rpc("any_peer", "call_local", "unreliable")
func _sync_position(pos: Vector2) -> void:
	## 接收服务器同步的位置（客户端用）
	if not NetworkManager or NetworkManager.is_server:
		return
	_interp_target = pos
	_has_interp_target = true


func teleport(pos: Vector2) -> void:
	## 服务器：瞬移实体并立即同步位置（不插值）
	if not NetworkManager or not NetworkManager.is_server:
		return
	_entity.position = pos
	_teleport_rpc.rpc(pos)


@rpc("any_peer", "call_local")
func _teleport_rpc(pos: Vector2) -> void:
	if not NetworkManager or NetworkManager.is_server:
		return
	_entity.position = pos
	_interp_target = pos
	_has_interp_target = false


# ==================== 属性 RPC ====================

@rpc("any_peer", "call_local")
func _sync_state(changes: Dictionary) -> void:
	## 接收服务器同步的属性变化（客户端用）
	if not NetworkManager or NetworkManager.is_server:
		return
	for key in changes.keys():
		_properties[key] = changes[key]
	state_changed.emit(changes)


# ==================== 工具方法 ====================

func is_server() -> bool:
	return NetworkManager and NetworkManager.is_server


func is_local_client() -> bool:
	## 检查父实体是否是本地玩家（如果父实体有 peer_id 属性）
	if not _entity:
		return false
	if "peer_id" in _entity and NetworkManager:
		return _entity.peer_id == NetworkManager.local_peer_id
	return false


func get_entity() -> Node2D:
	return _entity
