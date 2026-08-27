extends CharacterBody2D
## 玩家角色控制器
## 处理移动、属性、同步、视觉表现

const SPEED := 200.0
const SPRINT_SPEED := 320.0
const ACCELERATION := 1500.0
const FRICTION := 1200.0

@export var peer_id: int = 0
@export var player_name: String = "Player"
@export var player_color: Color = Color.WHITE
@export var player_class: String = "warrior"  # 职业

# 属性（P0基础版）
var max_health: float = 100.0
var health: float = 100.0
var max_hunger: float = 100.0
var hunger: float = 100.0
var max_thirst: float = 100.0
var thirst: float = 100.0
var max_stamina: float = 100.0
var stamina: float = 100.0
var is_down: bool = false  # 倒地状态

# 载具相关
var is_in_vehicle: bool = false
var current_vehicle: Node2D = null

# ==================== 等级与属性系统 ====================
var level: int = 1
var experience: float = 0.0
var experience_to_next: float = 100.0
var attribute_points: int = 0
# 科技点与技能（通过书籍学习获得）
var tech_points: int = 0
var has_medical_skill: bool = false
var has_farming_skill: bool = false
var has_cooking_skill: bool = false
var has_engineering_skill: bool = false
var has_combat_skill: bool = false
var has_mechanic_skill: bool = false
var has_building_skill: bool = false

# 疾病与理智系统
var sanity: float = 100.0  # 理智值 0-100
var is_sick: bool = false  # 是否生病
var sickness_type: String = ""  # 疾病类型：flu/cold/food_poisoning/infection
var sickness_timer: float = 0.0  # 疾病持续时间
var stress_level: float = 0.0  # 压力等级 0-100
var sanity_regen_rate: float = 0.5  # 理智恢复速度/秒

# 核心属性
var strength: int = 5  # 力量：影响攻击力和负重
var agility: int = 5  # 敏捷：影响移动速度和攻击速度
var vitality: int = 5  # 体质：影响生命值和体力恢复
var stealth: int = 5  # 潜行：影响丧尸发现玩家的范围

var is_sprinting: bool = false
var facing: Vector2 = Vector2.DOWN
var attack_cooldown: float = 0.0
const ATTACK_DAMAGE := 25.0
const ATTACK_RANGE := 70.0
const ATTACK_COOLDOWN_TIME := 0.4

# ==================== 网络同步：服务器权威 + 客户端预测 ====================
# --- 基础输入同步 ---
var remote_input := {"up": false, "down": false, "left": false, "right": false, "sprint": false}
var input_send_timer: float = 0.0
const INPUT_SEND_INTERVAL: float = 1.0 / 30.0  # 每秒30次输入同步

# --- 客户端预测 ---
var input_sequence: int = 0  # 当前输入序列号（递增）
var predicted_inputs: Array = []  # 预测输入队列（已发送未确认的输入）
const MAX_PREDICTED_INPUTS: int = 120  # 预测队列最大长度（4秒@30fps）
var server_position: Vector2 = Vector2.ZERO  # 服务器同步的权威位置
var last_processed_sequence: int = -1  # 服务器最后处理的输入序列号
const RECONCILIATION_THRESHOLD: float = 3.0  # 校正阈值（像素，超过才校正）
var is_reconciling: bool = false  # 是否正在校正中

# --- 其他玩家位置插值 ---
var interpolation_target: Vector2 = Vector2.ZERO  # 插值目标位置
var interpolation_timer: float = 0.0  # 插值计时器
const INTERPOLATION_INTERVAL: float = 1.0 / 20.0  # 插值间隔（每秒20次）
var has_interpolation_target: bool = false  # 是否有插值目标

# --- RPC位置同步（替代不可靠的MultiplayerSynchronizer）---
var _position_sync_timer: float = 0.0
const POSITION_SYNC_INTERVAL: float = 1.0 / 20.0  # 每秒20次位置同步

# 动画相关
var anim_timer: float = 0.0
var anim_frame: int = 0
var is_attacking: bool = false
var attack_anim_timer: float = 0.0
var is_moving: bool = false
var facing_direction: int = 0  # 0=下, 1=上, 2=左, 3=右
var anim_state: int = 0  # 0=idle, 1=walk, 2=attack, 3=chop, 4=mine, 5=gather
var interact_anim_timer: float = 0.0

@onready var sprite: Sprite2D = $Sprite
@onready var name_label: Label = $NameLabel
@onready var health_bar: ProgressBar = $HealthBar
@onready var synchronizer: MultiplayerSynchronizer = $MultiplayerSynchronizer
var camera: Camera2D = null

var inventory: Node = null


func _ready() -> void:
	# 安全获取 Camera 节点（网络同步时序可能导致 @onready 获取失败）
	camera = get_node_or_null("Camera") as Camera2D
	if camera == null:
		print("[Player] 警告：未找到 Camera 节点，将动态创建")
		camera = Camera2D.new()
		camera.name = "Camera"
		camera.zoom = Vector2(2.5, 2.5)
		add_child(camera)
	# 添加到玩家组（用于NPC识别玩家）
	add_to_group("player")
	# 使用职业精灵
	if sprite:
		sprite.texture = PlayerSprite.get_player_sprite(player_class)
		sprite.modulate = Color.WHITE
		sprite.scale = Vector2(1.2, 1.2)
	# 设置名字
	if name_label:
		name_label.text = player_name
	# 服务器权威模式：服务器上所有玩家都运行物理（计算移动）
	# 客户端只有本地玩家运行物理（预测移动+发送输入）
	if GameManager and GameManager.is_server:
		set_physics_process(true)
		if camera and not is_local():
			camera.queue_free()
	else:
		if not is_local():
			set_physics_process(false)
			if camera:
				camera.queue_free()
		else:
			if camera:
				camera.make_current()
	# 同步器配置（已改用RPC手动同步位置，彻底移除MultiplayerSynchronizer避免报错）
	if synchronizer and is_instance_valid(synchronizer):
		synchronizer.queue_free()
		synchronizer = null
		print("[Player] MultiplayerSynchronizer已移除，使用RPC同步位置")
	# 健康条初始
	_update_health_bar()
	# 使用场景文件中已有的Inventory节点（不要重复创建）
	if is_local():
		inventory = get_node_or_null("Inventory")
		if inventory:
			# 给一些初始物品测试
			inventory.add_item("wood", 15)
			inventory.add_item("stone", 10)
			inventory.add_item("fiber", 10)
			inventory.add_item("berry", 8)
			inventory.add_item("water", 5)
			inventory.add_item("cloth", 5)
			print("[Inventory] 背包初始化完成")
		else:
			print("[Inventory] 警告：未找到Inventory节点！")
		# 连接InputManager的action_pressed信号，处理攻击、互动、快捷栏等瞬时动作
		if InputManager:
			InputManager.action_pressed.connect(_on_input_action_pressed)


func _build_replication_config() -> SceneReplicationConfig:
	var config := SceneReplicationConfig.new()
	# 属性路径用 ../ 指向玩家节点（MultiplayerSynchronizer是玩家的子节点）
	config.add_property(NodePath("../position"))
	config.add_property(NodePath("../health"))
	config.add_property(NodePath("../hunger"))
	config.add_property(NodePath("../thirst"))
	config.add_property(NodePath("../stamina"))
	config.add_property(NodePath("../is_down"))
	# 动画状态同步
	config.add_property(NodePath("../facing_direction"))
	config.add_property(NodePath("../is_moving"))
	config.add_property(NodePath("../is_attacking"))
	config.add_property(NodePath("../anim_state"))
	return config


func _process(delta: float) -> void:
	# ==================== RPC位置同步 ====================
	if GameManager and GameManager.is_server:
		# 服务器：定期发送位置给所有客户端
		_position_sync_timer += delta
		if _position_sync_timer >= POSITION_SYNC_INTERVAL:
			_position_sync_timer = 0.0
			_receive_server_position.rpc(position)
	else:
		# 客户端：非本地玩家进行位置插值
		if not is_local() and has_interpolation_target:
			position = position.lerp(interpolation_target, delta * 10.0)


@rpc("any_peer", "call_local", "unreliable")
func _receive_server_position(server_pos: Vector2) -> void:
	## 接收服务器同步的位置（客户端用）
	if GameManager and GameManager.is_server:
		return  # 服务器不需要接收
	if is_local():
		return  # 本地玩家自己控制，不需要同步位置
	# 设置插值目标
	interpolation_target = server_pos
	has_interpolation_target = true


func _physics_process(delta: float) -> void:
	# ==================== 服务器权威 + 客户端预测 ====================
	# 服务器：权威计算所有玩家移动
	# 客户端本地玩家：预测移动 + 发送输入 + 服务器校正
	# 客户端其他玩家：不运行物理，位置由服务器同步

	if GameManager and GameManager.is_server:
		# ===== 服务器端：权威计算 =====
		if is_down:
			update_down_state(delta)
			var focus_owner_down: Control = get_viewport().gui_get_focus_owner()
			if focus_owner_down and (focus_owner_down is LineEdit or focus_owner_down is TextEdit):
				velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
				move_and_slide()
				_update_animation(delta)
				return
			if is_local():
				_crawl(delta)
			else:
				_crawl_remote(delta)
			_update_animation(delta)
			return

		attack_cooldown = max(0, attack_cooldown - delta)
		if is_local():
			var focus_owner: Control = get_viewport().gui_get_focus_owner()
			if focus_owner and (focus_owner is LineEdit or focus_owner is TextEdit):
				velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
				move_and_slide()
				_update_stats(delta)
				_update_animation(delta)
				update_noise(delta)
				_update_sickness(delta)
				_update_sanity(delta)
				return
			_handle_input(delta)
		else:
			_handle_remote_input(delta)
		_move(delta)
		_update_stats(delta)
		_update_animation(delta)
		update_noise(delta)
		_update_sickness(delta)
		_update_sanity(delta)

	else:
		# ===== 客户端端 =====
		if not is_local():
			return  # 其他玩家不运行物理

		# --- 客户端本地玩家：预测移动 ---
		if is_down:
			# 倒地状态不预测，等服务器同步
			attack_cooldown = max(0, attack_cooldown - delta)
			_update_animation(delta)
			return

		attack_cooldown = max(0, attack_cooldown - delta)
		var focus_owner: Control = get_viewport().gui_get_focus_owner()
		if focus_owner and (focus_owner is LineEdit or focus_owner is TextEdit):
			velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
			move_and_slide()
			_update_stats(delta)
			_update_animation(delta)
			update_noise(delta)
			_update_sickness(delta)
			_update_sanity(delta)
			return

		# 1. 收集输入
		var input_data := _collect_input()
		# 2. 分配序列号并加入预测队列
		input_sequence += 1
		var predicted_entry := {"seq": input_sequence, "input": input_data, "pos": position}
		predicted_inputs.append(predicted_entry)
		if predicted_inputs.size() > MAX_PREDICTED_INPUTS:
			predicted_inputs.pop_front()
		# 3. 发送输入给服务器（带序列号）
		input_send_timer += delta
		if input_send_timer >= INPUT_SEND_INTERVAL:
			input_send_timer = 0.0
			_send_input_to_server(input_data, input_sequence)
		# 4. 本地预测：立即应用输入
		_apply_input_data(input_data, delta)
		move_and_slide()
		_update_stats(delta)
		_update_animation(delta)
		update_noise(delta)
		_update_sickness(delta)
		_update_sanity(delta)


func _crawl(delta: float) -> void:
	# 倒地爬行：速度为正常的20%
	var input_dir: Vector2 = Vector2.ZERO
	if InputManager and InputManager.is_action_pressed("move_up"):
		input_dir.y -= 1
	if InputManager and InputManager.is_action_pressed("move_down"):
		input_dir.y += 1
	if InputManager and InputManager.is_action_pressed("move_left"):
		input_dir.x -= 1
	if InputManager and InputManager.is_action_pressed("move_right"):
		input_dir.x += 1
	if input_dir != Vector2.ZERO:
		input_dir = input_dir.normalized()
		var crawl_speed: float = SPEED * 0.2 * move_speed_modifier
		velocity = velocity.move_toward(input_dir * crawl_speed, ACCELERATION * delta * 0.5)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
	move_and_slide()


func _handle_input(delta: float) -> void:
	var input_dir := Vector2.ZERO
	if InputManager and InputManager.is_action_pressed("move_up"):
		input_dir.y -= 1
	if InputManager and InputManager.is_action_pressed("move_down"):
		input_dir.y += 1
	if InputManager and InputManager.is_action_pressed("move_left"):
		input_dir.x -= 1
	if InputManager and InputManager.is_action_pressed("move_right"):
		input_dir.x += 1
	input_dir = input_dir.normalized()

	# 冲刺
	is_sprinting = (InputManager and InputManager.is_action_pressed("sprint")) and stamina > 0 and input_dir != Vector2.ZERO
	if is_sprinting:
		stamina = max(0, stamina - 20 * delta)
	else:
		stamina = min(max_stamina, stamina + 15 * delta * stamina_regen_modifier)

	if input_dir != Vector2.ZERO:
		facing = input_dir
		is_moving = true
		# 更新朝向方向
		if abs(input_dir.x) > abs(input_dir.y):
			facing_direction = 2 if input_dir.x < 0 else 3  # 左/右
		else:
			facing_direction = 1 if input_dir.y < 0 else 0  # 上/下
		var target_speed := (SPRINT_SPEED if is_sprinting else SPEED) * move_speed_modifier * get_move_speed_multiplier()
		velocity = velocity.move_toward(input_dir * target_speed, ACCELERATION * delta)
	else:
		is_moving = false
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)


func _collect_input() -> Dictionary:
	## 收集当前输入状态（用于客户端预测和发送给服务器）
	if not InputManager:
		return {"up": false, "down": false, "left": false, "right": false, "sprint": false}
	return {
		"up": InputManager.is_action_pressed("move_up"),
		"down": InputManager.is_action_pressed("move_down"),
		"left": InputManager.is_action_pressed("move_left"),
		"right": InputManager.is_action_pressed("move_right"),
		"sprint": InputManager.is_action_pressed("sprint"),
	}


func _apply_input_data(input_data: Dictionary, delta: float) -> void:
	## 根据输入数据计算移动（不调用move_and_slide，用于客户端预测）
	var input_dir := Vector2.ZERO
	if input_data.get("up", false):
		input_dir.y -= 1
	if input_data.get("down", false):
		input_dir.y += 1
	if input_data.get("left", false):
		input_dir.x -= 1
	if input_data.get("right", false):
		input_dir.x += 1
	input_dir = input_dir.normalized()

	is_sprinting = input_data.get("sprint", false) and stamina > 0 and input_dir != Vector2.ZERO
	if is_sprinting:
		stamina = max(0, stamina - 20 * delta)
	else:
		stamina = min(max_stamina, stamina + 15 * delta * stamina_regen_modifier)

	if input_dir != Vector2.ZERO:
		facing = input_dir
		is_moving = true
		if abs(input_dir.x) > abs(input_dir.y):
			facing_direction = 2 if input_dir.x < 0 else 3
		else:
			facing_direction = 1 if input_dir.y < 0 else 0
		var target_speed := (SPRINT_SPEED if is_sprinting else SPEED) * move_speed_modifier * get_move_speed_multiplier()
		velocity = velocity.move_toward(input_dir * target_speed, ACCELERATION * delta)
	else:
		is_moving = false
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)


func _handle_remote_input(delta: float) -> void:
	## 服务器端：根据客户端发来的远程输入计算移动
	_apply_input_data(remote_input, delta)


func _crawl_remote(delta: float) -> void:
	## 服务器端：根据远程输入进行倒地爬行
	var input_dir := Vector2.ZERO
	if remote_input.get("up", false):
		input_dir.y -= 1
	if remote_input.get("down", false):
		input_dir.y += 1
	if remote_input.get("left", false):
		input_dir.x -= 1
	if remote_input.get("right", false):
		input_dir.x += 1
	input_dir = input_dir.normalized()
	var crawl_speed := SPEED * 0.2
	velocity = velocity.move_toward(input_dir * crawl_speed, ACCELERATION * delta)
	move_and_slide()


func _move(delta: float) -> void:
	move_and_slide()


func _update_stats(delta: float) -> void:
	# 饥饿和口渴随时间下降
	hunger = max(0, hunger - 0.5 * delta * hunger_modifier)
	thirst = max(0, thirst - 0.8 * delta * thirst_modifier)
	# 饥饿/口渴为0时掉血
	if hunger <= 0 or thirst <= 0:
		health = max(0, health - 2 * delta)
	# 健康为0时倒地
	if health <= 0 and not is_down:
		_on_health_depleted()
	_update_health_bar()


func _on_health_depleted() -> void:
	is_down = true
	velocity = Vector2.ZERO
	print("[Player] %s is down!" % player_name)
	# 通知服务器/其他玩家
	if is_local():
		GameManager.send_chat.rpc("重伤，请等待救援！")


func _update_health_bar() -> void:
	if health_bar:
		health_bar.value = health
		health_bar.visible = health < max_health


func is_local() -> bool:
	return peer_id == GameManager.local_peer_id


func take_damage(amount: float) -> void:
	if not GameManager.is_server:
		return  # 只有服务器能造成伤害
	health = max(0, health - amount)
	# 播放受伤音效
	if AudioManager:
		AudioManager.play_sfx(AudioManager.SFX.PLAYER_HURT)
	if health <= 0 and not is_down:
		_on_health_depleted()


func heal(amount: float) -> void:
	health = min(max_health, health + amount)


func restore_hunger(amount: float) -> void:
	hunger = min(max_hunger, hunger + amount)


func restore_thirst(amount: float) -> void:
	thirst = min(max_thirst, thirst + amount)


func _input(event: InputEvent) -> void:
	if not is_local() or is_down:
		return
	# 检查是否有UI菜单打开，如果有则不处理滚轮缩放
	if event is InputEventMouseButton and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		var ui_menus: Array = get_tree().get_nodes_in_group("ui_menu")
		for menu in ui_menus:
			if menu.has_method("is_open") and menu.is_open:
				return
	# 鼠标滚轮缩放（等距视角，范围0.8-2.5）
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		var new_zoom: float = min(camera.zoom.x + 0.15, 2.5)
		camera.zoom = Vector2(new_zoom, new_zoom)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		var new_zoom: float = max(camera.zoom.x - 0.15, 0.8)
		camera.zoom = Vector2(new_zoom, new_zoom)
		get_viewport().set_input_as_handled()
		return
	# 攻击逻辑已移到 _on_input_action_pressed 函数中，使用InputManager统一管理


func _unhandled_input(event: InputEvent) -> void:
	if not is_local() or is_down:
		return
	# 输入处理已移到 _on_input_action_pressed 函数中，使用InputManager统一管理


func _on_input_action_pressed(action: String) -> void:
	## 处理InputManager的action_pressed信号，处理攻击、互动、快捷栏等瞬时动作
	print("[Player] _on_input_action_pressed: ", action, " is_local=", is_local(), " is_down=", is_down)
	if not is_local() or is_down:
		print("[Player] 不是本地玩家或已倒下，跳过")
		return
	# 攻击
	if action == "attack":
		# 检查是否有UI菜单打开（建造/背包/制作），如果有则不攻击，让按钮接收点击
		var ui_menus: Array = get_tree().get_nodes_in_group("ui_menu")
		for menu in ui_menus:
			if menu and menu.is_open:
				print("[Player] UI菜单打开中，跳过攻击: ", menu.name)
				return  # UI菜单打开时不攻击
		# 检查是否处于建造放置模式
		var build_ui_nodes: Array = get_tree().get_nodes_in_group("build_ui")
		if build_ui_nodes.size() > 0:
			var build_ui = build_ui_nodes[0]
			if build_ui and build_ui.is_placing:
				print("[Player] 建造放置模式中，跳过攻击")
				return  # 放置模式下不攻击
		print("[Player] 调用 _attack()")
		_attack()
		return
	# 互动/采集
	if action == "interact":
		if not _interact_with_nearest():
			if inventory:
				if inventory.use_selected_item():
					print("[Inventory] 使用了物品")
		return
	# 快捷栏 1-9
	if action.begins_with("quickbar_"):
		var slot_index: int = action.to_int() - 1
		if slot_index >= 0 and slot_index <= 8 and inventory:
			inventory.select_slot(slot_index)
			print("[Inventory] 选中快捷栏 ", slot_index + 1)
		return
	# 手动存档（F5）
	if action == "save":
		var main: Node = get_tree().current_scene
		if main and main.has_method("manual_save"):
			main.manual_save()
		return


# ==================== 网络同步：输入发送与服务器校正 ====================

func _send_input_to_server(input_data: Dictionary, sequence: int) -> void:
	## 客户端：把输入状态和序列号发送给服务器
	if GameManager and GameManager.is_server:
		return  # 主机不需要发输入
	rpc_id(1, "_server_receive_input", input_data, sequence)


@rpc("any_peer", "call_local", "unreliable")
func _server_receive_input(input_data: Dictionary, sequence: int) -> void:
	## 服务器：接收客户端发来的输入和序列号
	if not (GameManager and GameManager.is_server):
		return
	if is_local():
		return  # 主机自己的输入本地处理
	remote_input = input_data
	last_processed_sequence = sequence
	# 立即把服务器状态发回客户端（位置+已处理的序列号）
	rpc_id(multiplayer.get_remote_sender_id(), "_client_receive_server_state", position, sequence)


@rpc("any_peer", "call_local", "unreliable")
func _client_receive_server_state(server_pos: Vector2, server_seq: int) -> void:
	## 客户端：接收服务器同步的位置和已处理的序列号，执行预测校正
	if GameManager and GameManager.is_server:
		return  # 主机不需要校正
	if not is_local():
		return  # 只校正本地玩家
	_reconcile_prediction(server_pos, server_seq)


func _reconcile_prediction(server_pos: Vector2, server_seq: int) -> void:
	## 客户端预测校正：对比预测位置和服务器位置，差异大则校正并重算
	# 从预测队列中移除已确认的输入
	var i := 0
	while i < predicted_inputs.size():
		if predicted_inputs[i]["seq"] <= server_seq:
			predicted_inputs.remove_at(i)
		else:
			i += 1

	# 计算当前预测位置和服务器位置的差异
	var diff: float = position.distance_to(server_pos)
	if diff > RECONCILIATION_THRESHOLD:
		# 差异超过阈值，校正位置
		is_reconciling = true
		position = server_pos
		velocity = Vector2.ZERO
		# 重新应用所有未确认的输入（回滚重算）
		for entry in predicted_inputs:
			_apply_input_data(entry["input"], get_physics_process_delta_time())
			move_and_slide()
		is_reconciling = false


func _attack() -> void:
	print("[Attack] _attack() 被调用，冷却: ", attack_cooldown)
	if attack_cooldown > 0:
		print("[Attack] 冷却中，跳过")
		return
	attack_cooldown = ATTACK_COOLDOWN_TIME / get_attack_speed_multiplier()
	is_attacking = true
	attack_anim_timer = 0.3
	anim_state = 2  # attack
	anim_frame = 0
	anim_timer = 0
	# 播放攻击音效
	if AudioManager:
		AudioManager.play_sfx(AudioManager.SFX.ATTACK)
	# 产生噪音，吸引附近丧尸
	emit_noise(15.0)
	# 攻击朝向方向上最近的目标（丧尸、NPC或建筑）
	var world: Node = get_tree().current_scene
	if not world:
		print("[Attack] 没有找到 current_scene")
		return
	var world_layer: Node = world.get_node_or_null("WorldLayer")
	if not world_layer:
		print("[Attack] 没有找到 WorldLayer")
		return
	var nearest_target: Node = null
	var nearest_dist: float = ATTACK_RANGE
	# 递归检测所有子节点中的目标
	var all_targets: Array = []
	_collect_targets(world_layer, all_targets)
	print("[Attack] 玩家位置: ", global_position, " 检测到 ", all_targets.size(), " 个目标")
	for target in all_targets:
		var dist: float = global_position.distance_to(target.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_target = target
	if not nearest_target:
		# 打印最近的3个目标
		var closest_list: Array = []
		for t in all_targets:
			closest_list.append({"name": t.name, "pos": t.global_position, "dist": global_position.distance_to(t.global_position)})
		for i in range(closest_list.size()):
			for j in range(i + 1, closest_list.size()):
				if closest_list[j].dist < closest_list[i].dist:
					var tmp = closest_list[i]
					closest_list[i] = closest_list[j]
					closest_list[j] = tmp
		for i in range(min(3, closest_list.size())):
			print("[Attack] 最近目标", i, ": ", closest_list[i].name, " 位置: ", closest_list[i].pos, " 距离: ", closest_list[i].dist)
		print("[Attack] 没有找到近距离目标，攻击范围: ", ATTACK_RANGE)
		return
	print("[Attack] 最近目标: ", nearest_target.name, " 距离: ", nearest_dist, " 组: ", nearest_target.get_groups())
	var damage: float = ATTACK_DAMAGE * get_attack_damage_multiplier()
	# 优先检测鼠标指向的围墙/房屋（不受70范围限制，鼠标离玩家200以内即可）
	var mouse_pos: Vector2 = get_global_mouse_position()
	if global_position.distance_to(mouse_pos) < 200.0:
		for target in all_targets:
			# 瓦片房屋/旧围墙（按瓦片破坏）
			if (target.is_in_group("tile_house") or target.is_in_group("wall")) and target.has_method("damage_tile_at_world_pos"):
				var hit: bool = target.damage_tile_at_world_pos(mouse_pos, damage)
				if hit:
					print("[Attack] 鼠标指向攻击命中，目标: ", target.name, " 位置: ", mouse_pos)
					return
			# 独立Sprite2D墙体（整面墙破坏）
			elif target.is_in_group("wall") and target.has_method("take_damage"):
				var sprite = target.get_node_or_null("Sprite2D")
				if sprite:
					var local_mouse = target.to_local(mouse_pos)
					if sprite.get_rect().has_point(local_mouse):
						target.take_damage(damage, self)
						print("[Attack] 鼠标指向攻击命中（独立墙体），目标: ", target.name)
						return
	# 对丧尸/NPC调用take_damage
	if nearest_target.has_method("take_damage"):
		nearest_target.take_damage(damage, self)
		var target_name: String = nearest_target.name if nearest_target.name else "Unknown"
		print("[Attack] 攻击 %s，造成 %d 伤害（职业:%s）" % [target_name, damage, player_class])
	# 对瓦片房屋/围墙调用damage_tile_at_world_pos（最近目标方式）
	elif (nearest_target.is_in_group("tile_house") or nearest_target.is_in_group("wall")) and nearest_target.has_method("damage_tile_at_world_pos"):
		var attack_pos: Vector2 = mouse_pos
		print("[Attack] 攻击房屋，玩家位置: ", global_position, " 鼠标位置: ", attack_pos)
		var hit: bool = nearest_target.damage_tile_at_world_pos(attack_pos, damage)
		if hit:
			print("[Attack] 攻击房屋瓦片命中，造成 %d 伤害" % damage)
		else:
			print("[Attack] 攻击房屋瓦片未命中，攻击点不在瓦片上")


func _collect_targets(node: Node, results: Array) -> void:
	## 递归收集所有可攻击目标（丧尸、NPC、瓦片房屋）
	for child in node.get_children():
		if child.is_in_group("zombie") or child.name.begins_with("Zombie") or child.is_in_group("npc") or child.is_in_group("tile_house") or child.is_in_group("wall"):
			results.append(child)
		_collect_targets(child, results)


func _interact_with_nearest() -> bool:
	# 检测附近的可交互对象（农田、建筑、资源节点、载具）
	const INTERACT_RANGE := 70.0
	var world: Node = get_tree().current_scene
	if not world:
		return false
	var world_layer: Node = world.get_node_or_null("WorldLayer")
	if not world_layer:
		return false
	# 优先检测载具（如果正在驾驶，F键退出载具）
	if is_in_vehicle and current_vehicle:
		current_vehicle.exit_vehicle()
		is_in_vehicle = false
		current_vehicle = null
		set_physics_process(true)
		return true
	# 检测附近载具
	var nearest_vehicle: Node = null
	var nearest_vehicle_dist: float = INTERACT_RANGE
	for child in world_layer.get_children():
		if child.is_in_group("vehicle") and not child.is_wreck:
			var dist: float = position.distance_to(child.position)
			if dist < nearest_vehicle_dist:
				nearest_vehicle_dist = dist
				nearest_vehicle = child
	if nearest_vehicle and nearest_vehicle.has_method("enter_vehicle"):
		if nearest_vehicle.enter_vehicle(self):
			is_in_vehicle = true
			current_vehicle = nearest_vehicle
			set_physics_process(false)
			return true
	# 优先检测农田
	var nearest_farm: Node = null
	var nearest_farm_dist: float = INTERACT_RANGE
	# 检测电力建筑
	var nearest_power: Node = null
	var nearest_power_dist: float = INTERACT_RANGE
	# 检测资源节点
	var nearest_resource: Node = null
	var nearest_dist: float = INTERACT_RANGE
	for child in world_layer.get_children():
		var dist: float = position.distance_to(child.position)
		# 检测农田
		if child.is_in_group("farm_plot") and dist < nearest_farm_dist:
			nearest_farm_dist = dist
			nearest_farm = child
		# 检测电力建筑
		if child.is_in_group("power_building") and dist < nearest_power_dist:
			nearest_power_dist = dist
			nearest_power = child
		# 检测资源节点
		if (child.is_in_group("resource") or child.has_method("hit")) and dist < nearest_dist:
			nearest_dist = dist
			nearest_resource = child
	# 优先与电力建筑交互
	if nearest_power and nearest_power.has_method("interact"):
		nearest_power.interact(self)
		return true
	# 优先与农田交互
	if nearest_farm and nearest_farm.has_method("interact"):
		nearest_farm.interact(self)
		# 播放交互音效
		if AudioManager:
			AudioManager.play_sfx(AudioManager.SFX.GATHER)
		return true
	# 与资源节点交互
	if nearest_resource:
		# 触发对应交互动画
		var res_name: String = nearest_resource.resource_name
		if res_name == "Tree":
			anim_state = 3  # chop
		elif res_name == "Rock":
			anim_state = 4  # mine
		else:
			anim_state = 5  # gather
		interact_anim_timer = 0.4
		anim_frame = 0
		anim_timer = 0
		# 传入玩家位置，让树木向玩家相反方向倒下
		nearest_resource.hit(20.0, global_position)
		# 播放采集音效
		if AudioManager:
			AudioManager.play_sfx(AudioManager.SFX.GATHER)
		# 产生噪音，吸引附近丧尸
		emit_noise(8.0)
		# 采集后给玩家物品
		if nearest_resource.is_depleted and inventory:
			inventory.add_item(nearest_resource.drop_item, nearest_resource.drop_count)
			print("[Interact] 采集了 %s，获得 %dx %s" % [nearest_resource.resource_name, nearest_resource.drop_count, nearest_resource.drop_item])
		return true
	return false


func revive() -> void:
	if is_down:
		is_down = false
		health = max_health * 0.3
		print("[Player] %s revived!" % player_name)


func _update_animation(delta: float) -> void:
	if not sprite:
		return
	# 倒地动画
	if is_down:
		sprite.texture = PlayerSprite.get_down_frame(player_class)
		return

	# 确定当前动画状态
	var current_state: int = 0  # idle
	if is_attacking:
		current_state = 2  # attack
	elif anim_state >= 3 and interact_anim_timer > 0:
		current_state = anim_state  # chop/mine/gather
	elif is_moving:
		current_state = 1  # walk

	# 交互动画计时
	if interact_anim_timer > 0:
		interact_anim_timer -= delta
		if interact_anim_timer <= 0:
			anim_state = 0

	# 攻击动画计时
	if is_attacking:
		attack_anim_timer -= delta
		if attack_anim_timer <= 0:
			is_attacking = false

	# 计算帧数
	var frame_count: int = PlayerSprite.get_frame_count(current_state)
	anim_timer += delta
	var frame_duration: float = 0.12
	if current_state == 2:  # attack
		frame_duration = 0.1
	elif current_state >= 3:  # interact
		frame_duration = 0.15

	if anim_timer >= frame_duration:
		anim_timer = 0
		anim_frame += 1
		if anim_frame >= frame_count:
			if current_state == 1:  # walk循环
				anim_frame = 0
			else:
				anim_frame = frame_count - 1  # 停在最后一帧

	# 播放对应精灵
	sprite.texture = PlayerSprite.get_sprite(player_class, facing_direction, current_state, anim_frame)

	# 非移动非交互时重置帧
	if current_state == 0:
		anim_frame = 0
		anim_timer = 0


# ==================== P1: 职业效果系统 ====================

func get_attack_damage_multiplier() -> float:
	var mult: float = 1.0
	match player_class:
		"warrior": mult = 1.2
		_: mult = 1.0
	mult *= 1.0 + (strength - 5) * 0.02
	return mult

func get_attack_speed_multiplier() -> float:
	var mult: float = 1.0
	match player_class:
		"warrior": mult = 1.1
		_: mult = 1.0
	mult *= 1.0 + (agility - 5) * 0.02
	return mult

func get_move_speed_multiplier() -> float:
	return 1.0 + (agility - 5) * 0.015

func get_stealth_multiplier() -> float:
	return max(0.3, 1.0 - (stealth - 5) * 0.05)

# ==================== 经验与升级 ====================
# ==================== 书籍学习系统 ====================
func learn_book(book_type: String) -> void:
	## 学习书籍，解锁技能树并获得科技点
	var tech_points_gained: int = 1
	var tech_name: String = ""
	match book_type:
		"medical_book":
			tech_name = "医学"
			has_medical_skill = true
		"farming_book":
			tech_name = "农业"
			has_farming_skill = true
		"cooking_book":
			tech_name = "烹饪"
			has_cooking_skill = true
		"engineering_book":
			tech_name = "工程"
			has_engineering_skill = true
		"combat_book":
			tech_name = "战斗"
			has_combat_skill = true
		"mechanic_book":
			tech_name = "汽修"
			has_mechanic_skill = true
		"building_book":
			tech_name = "建筑"
			has_building_skill = true
		_:
			tech_name = "通用"
	# 获得科技点
	tech_points += tech_points_gained
	print("[Learn] 学习了%s书籍，获得%d科技点，当前科技点：%d" % [tech_name, tech_points_gained, tech_points])
	if AudioManager:
		AudioManager.play_sfx(AudioManager.SFX.SUCCESS)


# ==================== 经验升级系统 ====================
func add_experience(amount: float) -> void:
	experience += amount
	while experience >= experience_to_next:
		experience -= experience_to_next
		level_up()

func level_up() -> void:
	level += 1
	attribute_points += 3
	experience_to_next = int(experience_to_next * 1.5)
	health = min(max_health + get_max_health_bonus(), health + 30.0)
	stamina = max_stamina
	if AudioManager:
		AudioManager.play_sfx(AudioManager.SFX.SUCCESS)

func spend_attribute_point(attr: String) -> bool:
	if attribute_points <= 0:
		return false
	match attr:
		"strength": strength += 1
		"agility": agility += 1
		"vitality":
			vitality += 1
			max_health += 10.0
			health += 10.0
		"stealth": stealth += 1
		_: return false
	attribute_points -= 1
	return true

func get_attribute_value(attr: String) -> int:
	match attr:
		"strength": return strength
		"agility": return agility
		"vitality": return vitality
		"stealth": return stealth
	return 0

func get_weapon_durability_multiplier() -> float:
	match player_class:
		"warrior": return 0.5  # 战士武器耐久消耗-50%
		_: return 1.0

func get_gather_speed_multiplier() -> float:
	match player_class:
		"lumberjack": return 1.5  # 伐木工砍树速度+50%
		_: return 1.0

func get_build_speed_multiplier() -> float:
	match player_class:
		"builder": return 2.0  # 工匠建造时间-50%
		_: return 1.0

func get_repair_efficiency() -> float:
	match player_class:
		"builder": return 1.5  # 工匠修理效率+50%
		"mechanic": return 1.5  # 汽修工修车效率+50%
		_: return 1.0

func get_max_health_bonus() -> float:
	match player_class:
		"warrior": return 20.0
		"lumberjack": return 15.0
		_: return 0.0

func get_weight_bonus() -> float:
	match player_class:
		"lumberjack": return 15.0  # 伐木工负重+30%（50*0.3=15）
		_: return 0.0

func get_cooking_speed_multiplier() -> float:
	match player_class:
		"cook": return 1.5  # 厨师烹饪速度+50%
		_: return 1.0

func get_food_effect_multiplier() -> float:
	match player_class:
		"cook": return 1.2  # 厨师食物效果+20%
		_: return 1.0

func get_farming_speed_multiplier() -> float:
	match player_class:
		"farmer": return 1.3  # 农民种植速度+30%
		_: return 1.0

func get_harvest_bonus() -> float:
	match player_class:
		"farmer": return 1.2  # 农民收获产量+20%
		_: return 1.0

func get_medical_efficiency() -> float:
	match player_class:
		"doctor": return 1.5  # 医生治疗效率+50%
		_: return 1.0

func get_medicine_cost_reduction() -> float:
	match player_class:
		"doctor": return 0.8  # 医生药品材料-20%
		_: return 1.0

func get_vehicle_fuel_reduction() -> float:
	match player_class:
		"mechanic": return 0.8  # 汽修工载具油耗-20%
		_: return 1.0

func get_electric_efficiency() -> float:
	match player_class:
		"engineer": return 1.3  # 工程师电力效率+30%
		_: return 1.0

func get_electric_cost_reduction() -> float:
	match player_class:
		"engineer": return 0.7  # 工程师电器建造-30%
		_: return 1.0

func can_build_advanced() -> bool:
	return player_class == "builder" or has_tech("bld_t2_stone") or has_tech("book_eng")

func can_craft_medical() -> bool:
	return player_class == "doctor" or has_tech("common_t2_medical") or has_tech("book_med")

func can_craft_advanced_food() -> bool:
	return player_class == "cook" or has_tech("cok_t1_recipe") or has_tech("book_cook")

func can_farm() -> bool:
	return player_class == "farmer" or has_tech("far_t1_seed") or has_tech("book_agri")

func can_repair_vehicle() -> bool:
	return player_class == "mechanic" or has_tech("mec_t1_repair") or has_tech("book_mech")

func can_build_electric() -> bool:
	return player_class == "engineer" or has_tech("eng_t1_circuit") or has_tech("book_elec")

func can_upgrade_weapon() -> bool:
	return player_class == "warrior" or has_tech("war_t3_upgrade") or has_tech("book_weapon")

func can_chop_giant_tree() -> bool:
	return player_class == "lumberjack" or has_tech("lum_t2_giant") or has_tech("book_lumber")

func can_revive() -> bool:
	return player_class == "doctor" or has_tech("doc_t1_rescue")

func get_class_name_cn() -> String:
	match player_class:
		"warrior": return "战士"
		"builder": return "工匠"
		"doctor": return "医生"
		"farmer": return "农民"
		"mechanic": return "汽修工"
		"cook": return "厨师"
		"lumberjack": return "伐木工"
		"engineer": return "工程师"
		_: return "未知"


# ==================== P1: 温度系统 ====================
var body_temperature: float = 37.0  # 体温
var warmth_level: float = 1.0  # 保暖值（基础衣物1.0，衣服/篝火/暖气提供额外）
var is_cold: bool = false
var is_hot: bool = false
# 天气/季节修正
var move_speed_modifier: float = 1.0
var hunger_modifier: float = 1.0
var thirst_modifier: float = 1.0
var stamina_regen_modifier: float = 1.0

func set_move_speed_modifier(mod: float) -> void:
	move_speed_modifier = clamp(mod, 0.1, 2.0)

func set_survival_modifiers(hunger_mod: float, thirst_mod: float, stamina_mod: float) -> void:
	hunger_modifier = clamp(hunger_mod, 0.1, 3.0)
	thirst_modifier = clamp(thirst_mod, 0.1, 3.0)
	stamina_regen_modifier = clamp(stamina_mod, 0.1, 2.0)

func update_temperature(delta: float, ambient_temp: float) -> void:
	# 计算附近热源加成
	var heat_bonus: float = _calc_nearby_heat()
	# 舒适温度阈值
	const COMFORT_TEMP := 20.0
	const BASE_BODY_TEMP := 37.0
	# 计算温度差（环境温度低于舒适温度时，体温会下降）
	var temp_diff: float = COMFORT_TEMP - ambient_temp - heat_bonus
	# 保暖值减缓体温下降（每点保暖减少10%的温度影响）
	var warmth_protection: float = 1.0 - warmth_level * 0.1
	warmth_protection = clamp(warmth_protection, 0.1, 1.0)
	# 体温变化率（环境越冷，下降越快）
	var temp_change_rate: float = temp_diff * 0.002 * warmth_protection
	# 更新体温（向基础体温靠拢，但受环境影响）
	if temp_diff > 0:
		# 环境冷，体温下降
		body_temperature = max(30.0, body_temperature - temp_change_rate * delta)
	else:
		# 环境热或舒适，体温恢复到正常
		body_temperature = min(BASE_BODY_TEMP, body_temperature + 0.01 * delta)
	is_cold = body_temperature < 35.0
	is_hot = body_temperature > 39.0
	# 寒冷效果：体力消耗加速
	if is_cold:
		stamina = max(0, stamina - delta * 1.0)
		# 严重失温（<32°C）才掉血，且掉血速度较慢
		if body_temperature < 32.0:
			health = max(0, health - delta * 0.3)
	# 炎热效果：口渴加速
	if is_hot:
		thirst = max(0, thirst - delta * 1.0)
		# 严重中暑（>41°C）才掉血
		if body_temperature > 41.0:
			health = max(0, health - delta * 0.2)


func _calc_nearby_heat() -> float:
	# 检测附近的热源（篝火、炉子、暖气等）
	var heat: float = 0.0
	var world: Node = get_tree().current_scene
	if not world:
		return heat
	var world_layer: Node = world.get_node_or_null("WorldLayer")
	if not world_layer:
		return heat
	for child in world_layer.get_children():
		if child.is_in_group("heat_source") or child.name.begins_with("Campfire") or child.name.begins_with("Fireplace"):
			var dist: float = position.distance_to(child.position)
			if dist < 150.0:
				heat += (150.0 - dist) / 150.0 * 10.0  # 最多+10度
	return heat


# ==================== P1: 科技树系统 ====================
var skill_points: int = 0
var unlocked_techs: Array = []

func add_skill_points(amount: int) -> void:
	skill_points += amount

func unlock_tech(tech_id: String) -> bool:
	if skill_points <= 0:
		return false
	if tech_id in unlocked_techs:
		return false
	skill_points -= 1
	unlocked_techs.append(tech_id)
	return true

func has_tech(tech_id: String) -> bool:
	return tech_id in unlocked_techs


# ==================== P1: 装备栏系统 ====================
var equipment: Dictionary = {
	"weapon": null,
	"armor": null,
	"helmet": null,
	"backpack": null,
}

func equip_item(slot: String, item: Dictionary) -> void:
	equipment[slot] = item

func unequip_item(slot: String) -> void:
	equipment[slot] = null


# ==================== P1: 噪音系统 ====================
var noise_level: float = 0.0

func emit_noise(amount: float) -> void:
	noise_level += amount
	# 通知附近的丧尸
	var world: Node = get_tree().current_scene
	if world:
		var world_layer: Node = world.get_node_or_null("WorldLayer")
		if world_layer:
			for child in world_layer.get_children():
				if child.is_in_group("zombie") and position.distance_to(child.position) < 300 + noise_level * 10:
					if child.has_method("attract_to"):
						child.attract_to(position)

func update_noise(delta: float) -> void:
	noise_level = max(0, noise_level - delta * 5.0)


# ==================== 疾病与理智系统 ====================
func _update_sickness(delta: float) -> void:
	## 更新疾病状态
	if not is_sick:
		return
	sickness_timer -= delta
	# 疾病效果
	match sickness_type:
		"flu":
			# 流感：体力恢复减慢，偶尔掉血
			stamina = max(0, stamina - delta * 0.5)
			if randf() < 0.001 * delta:
				health = max(1, health - 1)
		"cold":
			# 感冒：移动速度减慢
			pass
		"food_poisoning":
			# 食物中毒：饥饿和口渴加速消耗
			hunger = max(0, hunger - delta * 0.5)
			thirst = max(0, thirst - delta * 0.5)
		"infection":
			# 感染：持续掉血，需要抗生素
			health = max(1, health - delta * 0.3)
	# 疾病结束
	if sickness_timer <= 0:
		is_sick = false
		sickness_type = ""
		print("[Health] 疾病痊愈了")


func _update_sanity(delta: float) -> void:
	## 更新理智值（细化版）
	var main: Node = get_tree().current_scene
	if not main:
		return
	var world_layer: Node = main.get_node_or_null("WorldLayer")
	if not world_layer:
		return
	# 检查是否是夜晚
	var is_night: bool = false
	if main.has_method("is_night_time"):
		is_night = main.is_night_time()
	# 检查附近是否有篝火/光源（120像素范围内）
	var near_campfire: bool = false
	var near_light: bool = false
	for child in world_layer.get_children():
		if child.is_in_group("building") or child.name.begins_with("Building"):
			var dist: float = position.distance_to(child.position)
			if dist < 120:
				var bid: String = child.building_id if "building_id" in child else ""
				if bid == "campfire" or bid == "torch":
					near_campfire = true
					near_light = true
				elif bid == "electric_light":
					near_light = true
	# 检查附近队友数量（150像素范围内）
	var nearby_teammates: int = 0
	for pid: int in GameManager.players.keys():
		var p: Node2D = GameManager.players[pid]
		if is_instance_valid(p) and p != self:
			if position.distance_to(p.position) < 150:
				nearby_teammates += 1
	# 附近有丧尸时，理智下降（优先级最高）
	var nearby_zombies: int = 0
	for child in world_layer.get_children():
		if child.is_in_group("zombie"):
			if position.distance_to(child.position) < 200:
				nearby_zombies += 1
	if nearby_zombies > 0:
		sanity = max(0, sanity - delta * nearby_zombies * 0.3)
		stress_level = min(100, stress_level + delta * nearby_zombies * 0.6)
		return
	# 根据时间和环境调整理智
	if not is_night:
		# 白天：正常恢复理智
		sanity = min(100, sanity + delta * 0.5)
		stress_level = max(0, stress_level - delta * 0.3)
	else:
		# 夜晚
		if near_campfire:
			# 在篝火旁：缓慢增加理智
			sanity = min(100, sanity + delta * 0.8)
			stress_level = max(0, stress_level - delta * 0.5)
		elif near_light:
			# 在其他光源旁：轻微增加理智
			sanity = min(100, sanity + delta * 0.3)
			stress_level = max(0, stress_level - delta * 0.2)
		elif nearby_teammates >= 1:
			# 夜晚二人以上团队出行（150像素内有队友）：理智保持不变
			# 不增不减
			pass
		else:
			# 夜晚独自离开篝火范围：缓慢降低理智
			sanity = max(0, sanity - delta * 0.4)
			stress_level = min(100, stress_level + delta * 0.2)
	# 理智过低的效果
	if sanity < 30:
		# 低理智：移动速度减慢，攻击速度减慢
		pass
	if sanity < 10:
		# 极低理智：偶尔失控
		if randf() < 0.0001 * delta:
			print("[Sanity] 理智过低，玩家开始失控！")


func get_sick(sickness: String, duration: float = 120.0) -> void:
	## 让玩家生病
	if is_sick:
		return
	is_sick = true
	sickness_type = sickness
	sickness_timer = duration
	print("[Health] 玩家生病了：%s，持续%.0f秒" % [sickness, duration])


func cure_sickness() -> void:
	## 治愈疾病
	if not is_sick:
		return
	is_sick = false
	sickness_type = ""
	sickness_timer = 0
	print("[Health] 疾病被治愈了")


func restore_sanity(amount: float) -> void:
	## 恢复理智
	sanity = min(100, sanity + amount)
	print("[Sanity] 理智恢复%.1f点，当前：%.1f" % [amount, sanity])


# ==================== P1: 倒地救援系统（按GDD细化） ====================
var down_timer: float = 0.0
const DOWN_BLEED_TIME := 60.0  # 倒地后流血倒计时60秒
var can_self_revive: bool = true  # 医生自救被动（每局限1次）
var self_revive_timer: float = 0.0
const SELF_REVIVE_TIME := 30.0  # 医生倒地30秒后可自救

func go_down() -> void:
	is_down = true
	down_timer = 0.0
	GameManager.send_chat.rpc("%s 重伤，请等待救援！" % player_name)
	# 医生自救被动计时
	if player_class == "doctor" and can_self_revive:
		self_revive_timer = 0.0

func update_down_state(delta: float) -> void:
	if not is_down:
		return
	down_timer += delta
	# 流血倒计时，超过时间死亡
	if down_timer >= DOWN_BLEED_TIME:
		health = 0
		GameManager.send_chat.rpc("%s 因流血过多死亡..." % player_name)
		return
	# 医生自救被动
	if player_class == "doctor" and can_self_revive:
		self_revive_timer += delta
		if self_revive_timer >= SELF_REVIVE_TIME:
			_self_revive()

func _self_revive() -> void:
	if not can_self_revive:
		return
	can_self_revive = false
	is_down = false
	health = max_health * 0.1
	down_timer = 0.0
	GameManager.send_chat.rpc("%s 使用自救技能站起了！（恢复10%生命）" % player_name)

func be_revived_by(healer: Node) -> void:
	# 医生职业救援：读条1.5秒，恢复30%生命
	if healer.player_class == "doctor":
		is_down = false
		health = max_health * 0.3
		down_timer = 0.0
		GameManager.send_chat.rpc("%s 被医生 %s 救起了！（恢复30%%生命）" % [player_name, healer.player_name])
	else:
		# 其他玩家简易救援：需急救包，读条3秒，成功率60%，恢复10%生命
		if randf() < 0.6:
			is_down = false
			health = max_health * 0.1
			down_timer = 0.0
			GameManager.send_chat.rpc("%s 被 %s 简易救起了！（恢复10%%生命）" % [player_name, healer.player_name])
		else:
			GameManager.send_chat.rpc("%s 救援 %s 失败！" % [healer.player_name, player_name])

func get_down_remaining_time() -> float:
	return max(0, DOWN_BLEED_TIME - down_timer)

# 脚本已更新 - 强制Godot重新加载
