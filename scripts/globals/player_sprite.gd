extends Node
## 玩家精灵生成器：程序生成像素风格的玩家精灵和动画
## 支持四方向（上下左右）、多帧数行走、攻击/伐木/采石/采集等交互动画

const SPRITE_SIZE := 48

# 职业定义
const CLASSES := {
	"warrior": {
		"name": "战士",
		"body_color": Color(0.4, 0.4, 0.5),
		"head_color": Color(0.85, 0.7, 0.55),
		"hair_color": Color(0.3, 0.2, 0.15),
		"accent_color": Color(0.7, 0.2, 0.2),
		"has_helmet": true,
		"has_weapon": true,
		"weapon_type": "sword",
	},
	"craftsman": {
		"name": "工匠",
		"body_color": Color(0.5, 0.4, 0.3),
		"head_color": Color(0.85, 0.7, 0.55),
		"hair_color": Color(0.4, 0.3, 0.2),
		"accent_color": Color(0.8, 0.7, 0.2),
		"has_helmet": true,
		"helmet_color": Color(0.9, 0.8, 0.2),
		"has_weapon": true,
		"weapon_type": "hammer",
	},
	"doctor": {
		"name": "医生",
		"body_color": Color(0.85, 0.85, 0.85),
		"head_color": Color(0.85, 0.7, 0.55),
		"hair_color": Color(0.2, 0.2, 0.2),
		"accent_color": Color(0.9, 0.2, 0.2),
		"has_helmet": false,
		"has_weapon": true,
		"weapon_type": "medkit",
	},
	"farmer": {
		"name": "农民",
		"body_color": Color(0.45, 0.55, 0.3),
		"head_color": Color(0.85, 0.7, 0.55),
		"hair_color": Color(0.5, 0.35, 0.2),
		"accent_color": Color(0.7, 0.6, 0.2),
		"has_helmet": true,
		"helmet_color": Color(0.8, 0.7, 0.3),
		"has_weapon": true,
		"weapon_type": "hoe",
	},
	"mechanic": {
		"name": "汽修工",
		"body_color": Color(0.35, 0.35, 0.4),
		"head_color": Color(0.85, 0.7, 0.55),
		"hair_color": Color(0.3, 0.25, 0.2),
		"accent_color": Color(0.2, 0.5, 0.8),
		"has_helmet": true,
		"helmet_color": Color(0.3, 0.3, 0.35),
		"has_weapon": true,
		"weapon_type": "wrench",
	},
	"chef": {
		"name": "厨师",
		"body_color": Color(0.8, 0.8, 0.75),
		"head_color": Color(0.85, 0.7, 0.55),
		"hair_color": Color(0.3, 0.2, 0.15),
		"accent_color": Color(0.9, 0.5, 0.2),
		"has_helmet": true,
		"helmet_color": Color(0.95, 0.95, 0.95),
		"has_weapon": true,
		"weapon_type": "pan",
	},
	"lumberjack": {
		"name": "伐木工",
		"body_color": Color(0.4, 0.35, 0.25),
		"head_color": Color(0.85, 0.7, 0.55),
		"hair_color": Color(0.4, 0.3, 0.2),
		"accent_color": Color(0.6, 0.4, 0.2),
		"has_helmet": true,
		"helmet_color": Color(0.7, 0.5, 0.3),
		"has_weapon": true,
		"weapon_type": "axe",
	},
	"engineer": {
		"name": "工程师",
		"body_color": Color(0.3, 0.4, 0.5),
		"head_color": Color(0.85, 0.7, 0.55),
		"hair_color": Color(0.25, 0.25, 0.3),
		"accent_color": Color(0.2, 0.8, 0.8),
		"has_helmet": false,
		"has_goggles": true,
		"has_weapon": true,
		"weapon_type": "tool",
	},
}

static var _sprite_cache: Dictionary = {}


## 获取动画帧数
func get_frame_count(state: int) -> int:
	match state:
		0: return 1  # IDLE
		1: return 4  # WALK
		2: return 3  # ATTACK
		3: return 3  # CHOP
		4: return 3  # MINE
		5: return 2  # GATHER
	return 1


## 获取精灵纹理
func get_sprite(class_id: String, direction: int, state: int, frame: int) -> Texture2D:
	var key := "player_%s_%d_%d_%d" % [class_id, direction, state, frame]
	if _sprite_cache.has(key):
		return _sprite_cache[key]
	var class_data: Dictionary = CLASSES.get(class_id, CLASSES["warrior"])
	var tex := _make_player_texture(class_data, direction, state, frame)
	_sprite_cache[key] = tex
	return tex


## 兼容旧接口：获取默认站立精灵
func get_player_sprite(class_id: String = "warrior") -> Texture2D:
	return get_sprite(class_id, 0, 0, 0)  # DOWN, IDLE, frame 0


## 兼容旧接口：获取行走帧
func get_walk_frame(class_id: String, frame: int) -> Texture2D:
	return get_sprite(class_id, 0, 1, frame % 4)  # DOWN, WALK


## 兼容旧接口：获取攻击帧
func get_attack_frame(class_id: String) -> Texture2D:
	return get_sprite(class_id, 0, 2, 1)  # DOWN, ATTACK, frame 1


## 兼容旧接口：获取倒地帧
func get_down_frame(class_id: String) -> Texture2D:
	var key := "player_" + class_id + "_down"
	if _sprite_cache.has(key):
		return _sprite_cache[key]
	var class_data: Dictionary = CLASSES.get(class_id, CLASSES["warrior"])
	var img := Image.create(SPRITE_SIZE, SPRITE_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_draw_rect(img, 8, 20, 32, 12, class_data["body_color"])
	_draw_rect(img, 32, 18, 10, 10, class_data["head_color"])
	img.set_pixel(35, 21, Color(0.2, 0.2, 0.2))
	img.set_pixel(37, 23, Color(0.2, 0.2, 0.2))
	img.set_pixel(37, 21, Color(0.2, 0.2, 0.2))
	img.set_pixel(35, 23, Color(0.2, 0.2, 0.2))
	var tex := ImageTexture.create_from_image(img)
	_sprite_cache[key] = tex
	return tex


## 获取职业名称
func get_class_name(class_id: String) -> String:
	if CLASSES.has(class_id):
		return CLASSES[class_id]["name"]
	return "未知"


## 获取所有职业列表
func get_all_classes() -> Dictionary:
	return CLASSES


## 生成玩家纹理（核心函数）
func _make_player_texture(class_data: Dictionary, direction: int, state: int, frame: int) -> Texture2D:
	var img := Image.create(SPRITE_SIZE, SPRITE_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var body_color: Color = class_data["body_color"]
	var head_color: Color = class_data["head_color"]
	var hair_color: Color = class_data["hair_color"]
	var accent_color: Color = class_data["accent_color"]

	# 根据状态计算身体偏移和手臂位置
	var body_y_offset: int = 0
	var left_arm_y: int = 22
	var right_arm_y: int = 22
	var left_arm_x: int = 12
	var right_arm_x: int = 32
	var weapon_offset_y: int = 0
	var weapon_rotate: bool = false

	# 行走动画：4帧
	if state == 1:
		match frame:
			0: body_y_offset = 0
			1: body_y_offset = -1
			2: body_y_offset = 0
			3: body_y_offset = -1

	# 攻击/伐木/采石动画：3帧（预备、挥击、收回）
	if state == 2 or state == 3 or state == 4:
		match frame:
			0:  # 预备：手臂抬起
				right_arm_y = 16
				weapon_offset_y = -6
			1:  # 挥击：手臂向前
				right_arm_y = 20
				weapon_offset_y = 2
				weapon_rotate = true
			2:  # 收回
				right_arm_y = 22
				weapon_offset_y = 0

	# 采集动画：2帧（弯腰、起身）
	if state == 5:
		match frame:
			0: body_y_offset = 2
			1: body_y_offset = 0

	# 根据方向绘制
	match direction:
		0:
			_draw_player_down(img, class_data, body_y_offset, left_arm_y, right_arm_y, left_arm_x, right_arm_x, state, frame, weapon_offset_y, weapon_rotate)
		1:
			_draw_player_up(img, class_data, body_y_offset, left_arm_y, right_arm_y, left_arm_x, right_arm_x, state, frame, weapon_offset_y, weapon_rotate)
		2:
			_draw_player_side(img, class_data, body_y_offset, left_arm_y, right_arm_y, state, frame, weapon_offset_y, weapon_rotate, true)
		3:
			_draw_player_side(img, class_data, body_y_offset, left_arm_y, right_arm_y, state, frame, weapon_offset_y, weapon_rotate, false)

	return ImageTexture.create_from_image(img)


## 绘制正面（朝下）玩家
func _draw_player_down(img: Image, class_data: Dictionary, body_y: int, left_arm_y: int, right_arm_y: int, left_arm_x: int, right_arm_x: int, state: int, frame: int, weapon_off_y: int, weapon_rot: bool) -> void:
	var body_color: Color = class_data["body_color"]
	var head_color: Color = class_data["head_color"]
	var hair_color: Color = class_data["hair_color"]
	var accent_color: Color = class_data["accent_color"]

	# 腿（行走时交替）
	var leg1_off: int = 0
	var leg2_off: int = 0
	if state == 1:
		match frame:
			0: leg1_off = 0; leg2_off = 0
			1: leg1_off = 2; leg2_off = -1
			2: leg1_off = 0; leg2_off = 0
			3: leg1_off = -1; leg2_off = 2
	_draw_rect(img, 18, 32 + body_y + leg1_off, 5, 8, body_color.darkened(0.2))
	_draw_rect(img, 25, 32 + body_y + leg2_off, 5, 8, body_color.darkened(0.2))

	# 身体
	_draw_rect(img, 16, 20 + body_y, 16, 14, body_color)
	_draw_rect(img, 16, 28 + body_y, 16, 2, accent_color)

	# 手臂
	_draw_rect(img, left_arm_x, left_arm_y + body_y, 4, 10, body_color)
	_draw_rect(img, right_arm_x, right_arm_y + body_y, 4, 10, body_color)

	# 头
	_draw_rect(img, 17, 8 + body_y, 14, 12, head_color)
	# 头发
	_draw_rect(img, 17, 8 + body_y, 14, 4, hair_color)
	_draw_rect(img, 16, 10 + body_y, 2, 4, hair_color)
	_draw_rect(img, 30, 10 + body_y, 2, 4, hair_color)

	# 眼睛
	img.set_pixel(21, 15 + body_y, Color(0.15, 0.15, 0.15))
	img.set_pixel(27, 15 + body_y, Color(0.15, 0.15, 0.15))

	# 头盔
	if class_data.get("has_helmet", false):
		var helmet_color: Color = class_data.get("helmet_color", Color(0.6, 0.6, 0.65))
		_draw_rect(img, 16, 6 + body_y, 16, 6, helmet_color)
		_draw_rect(img, 15, 10 + body_y, 18, 2, helmet_color.darkened(0.2))

	# 护目镜
	if class_data.get("has_goggles", false):
		_draw_rect(img, 19, 13 + body_y, 4, 3, Color(0.2, 0.2, 0.25))
		_draw_rect(img, 25, 13 + body_y, 4, 3, Color(0.2, 0.2, 0.25))
		_draw_rect(img, 23, 14 + body_y, 2, 1, Color(0.4, 0.4, 0.45))

	# 武器（右手）
	if class_data.get("has_weapon", false) and state != 5:
		var weapon_type: String = class_data.get("weapon_type", "sword")
		_draw_weapon(img, weapon_type, right_arm_x + 1, right_arm_y + body_y + weapon_off_y, weapon_rot)


## 绘制背面（朝上）玩家
func _draw_player_up(img: Image, class_data: Dictionary, body_y: int, left_arm_y: int, right_arm_y: int, left_arm_x: int, right_arm_x: int, state: int, frame: int, weapon_off_y: int, weapon_rot: bool) -> void:
	var body_color: Color = class_data["body_color"]
	var head_color: Color = class_data["head_color"]
	var hair_color: Color = class_data["hair_color"]
	var accent_color: Color = class_data["accent_color"]

	# 腿
	var leg1_off: int = 0
	var leg2_off: int = 0
	if state == 1:
		match frame:
			0: leg1_off = 0; leg2_off = 0
			1: leg1_off = 2; leg2_off = -1
			2: leg1_off = 0; leg2_off = 0
			3: leg1_off = -1; leg2_off = 2
	_draw_rect(img, 18, 32 + body_y + leg1_off, 5, 8, body_color.darkened(0.2))
	_draw_rect(img, 25, 32 + body_y + leg2_off, 5, 8, body_color.darkened(0.2))

	# 身体
	_draw_rect(img, 16, 20 + body_y, 16, 14, body_color)
	_draw_rect(img, 16, 28 + body_y, 16, 2, accent_color)

	# 手臂（背面看不到手的细节）
	_draw_rect(img, left_arm_x, left_arm_y + body_y, 4, 10, body_color)
	_draw_rect(img, right_arm_x, right_arm_y + body_y, 4, 10, body_color)

	# 头（背面，看不到脸）
	_draw_rect(img, 17, 8 + body_y, 14, 12, head_color)
	# 头发（背面更多）
	_draw_rect(img, 17, 8 + body_y, 14, 6, hair_color)
	_draw_rect(img, 16, 10 + body_y, 2, 6, hair_color)
	_draw_rect(img, 30, 10 + body_y, 2, 6, hair_color)

	# 头盔（背面）
	if class_data.get("has_helmet", false):
		var helmet_color: Color = class_data.get("helmet_color", Color(0.6, 0.6, 0.65))
		_draw_rect(img, 16, 6 + body_y, 16, 6, helmet_color)
		_draw_rect(img, 15, 10 + body_y, 18, 2, helmet_color.darkened(0.2))

	# 武器（右手，背面）
	if class_data.get("has_weapon", false) and state != 5:
		var weapon_type: String = class_data.get("weapon_type", "sword")
		_draw_weapon(img, weapon_type, right_arm_x + 1, right_arm_y + body_y + weapon_off_y, weapon_rot)


## 绘制侧面玩家（flip_left=true为左，false为右）
func _draw_player_side(img: Image, class_data: Dictionary, body_y: int, left_arm_y: int, right_arm_y: int, state: int, frame: int, weapon_off_y: int, weapon_rot: bool, flip_left: bool) -> void:
	var body_color: Color = class_data["body_color"]
	var head_color: Color = class_data["head_color"]
	var hair_color: Color = class_data["hair_color"]
	var accent_color: Color = class_data["accent_color"]

	# 侧面用临时画布绘制，然后翻转
	var side_img := Image.create(SPRITE_SIZE, SPRITE_SIZE, false, Image.FORMAT_RGBA8)
	side_img.fill(Color(0, 0, 0, 0))

	# 腿（侧面，前后交替）
	var leg_front_off: int = 0
	var leg_back_off: int = 0
	if state == 1:
		match frame:
			0: leg_front_off = 0; leg_back_off = 0
			1: leg_front_off = 2; leg_back_off = -1
			2: leg_front_off = 0; leg_back_off = 0
			3: leg_front_off = -1; leg_back_off = 2
	# 后腿
	_draw_rect(side_img, 19, 32 + body_y + leg_back_off, 4, 8, body_color.darkened(0.3))
	# 前腿
	_draw_rect(side_img, 24, 32 + body_y + leg_front_off, 5, 8, body_color.darkened(0.2))

	# 身体（侧面稍窄）
	_draw_rect(side_img, 19, 20 + body_y, 11, 14, body_color)
	_draw_rect(side_img, 19, 28 + body_y, 11, 2, accent_color)

	# 手臂（侧面，一只在前一只在后）
	_draw_rect(side_img, 17, left_arm_y + body_y, 3, 10, body_color.darkened(0.1))  # 后臂
	_draw_rect(side_img, 28, right_arm_y + body_y, 4, 10, body_color)  # 前臂

	# 头（侧面）
	_draw_rect(side_img, 20, 8 + body_y, 12, 12, head_color)
	# 头发（侧面）
	_draw_rect(side_img, 20, 8 + body_y, 12, 4, hair_color)
	_draw_rect(side_img, 19, 10 + body_y, 2, 5, hair_color)
	# 眼睛（侧面只有一只）
	side_img.set_pixel(28, 15 + body_y, Color(0.15, 0.15, 0.15))

	# 头盔（侧面）
	if class_data.get("has_helmet", false):
		var helmet_color: Color = class_data.get("helmet_color", Color(0.6, 0.6, 0.65))
		_draw_rect(side_img, 19, 6 + body_y, 14, 6, helmet_color)
		_draw_rect(side_img, 18, 10 + body_y, 16, 2, helmet_color.darkened(0.2))

	# 护目镜（侧面）
	if class_data.get("has_goggles", false):
		_draw_rect(side_img, 26, 13 + body_y, 5, 3, Color(0.2, 0.2, 0.25))

	# 武器（前臂）
	if class_data.get("has_weapon", false) and state != 5:
		var weapon_type: String = class_data.get("weapon_type", "sword")
		_draw_weapon(side_img, weapon_type, 30, right_arm_y + body_y + weapon_off_y, weapon_rot)

	# 如果是朝左，水平翻转；否则直接复制
	if flip_left:
		for x in range(SPRITE_SIZE):
			for y in range(SPRITE_SIZE):
				img.set_pixel(x, y, side_img.get_pixel(SPRITE_SIZE - 1 - x, y))
	else:
		for x in range(SPRITE_SIZE):
			for y in range(SPRITE_SIZE):
				img.set_pixel(x, y, side_img.get_pixel(x, y))


## 绘制武器
func _draw_weapon(img: Image, weapon_type: String, wx: int, wy: int, rotate: bool) -> void:
	match weapon_type:
		"sword":
			if rotate:
				# 横挥
				_draw_rect(img, wx - 4, wy, 12, 2, Color(0.8, 0.8, 0.85))
				_draw_rect(img, wx - 6, wy - 1, 4, 4, Color(0.6, 0.5, 0.3))
			else:
				_draw_rect(img, wx, wy, 2, 12, Color(0.8, 0.8, 0.85))
				_draw_rect(img, wx - 2, wy + 10, 6, 2, Color(0.6, 0.5, 0.3))
				_draw_rect(img, wx, wy + 12, 2, 4, Color(0.5, 0.35, 0.15))
		"axe":
			if rotate:
				_draw_rect(img, wx - 4, wy, 10, 2, Color(0.5, 0.35, 0.15))
				_draw_rect(img, wx - 8, wy - 3, 6, 5, Color(0.65, 0.65, 0.7))
			else:
				_draw_rect(img, wx, wy, 2, 14, Color(0.5, 0.35, 0.15))
				_draw_rect(img, wx - 4, wy, 8, 5, Color(0.65, 0.65, 0.7))
				_draw_rect(img, wx - 5, wy + 1, 2, 3, Color(0.75, 0.75, 0.8))
		"hammer":
			if rotate:
				_draw_rect(img, wx - 4, wy, 10, 2, Color(0.5, 0.35, 0.15))
				_draw_rect(img, wx - 7, wy - 2, 6, 5, Color(0.6, 0.6, 0.65))
			else:
				_draw_rect(img, wx, wy + 4, 2, 12, Color(0.5, 0.35, 0.15))
				_draw_rect(img, wx - 3, wy, 8, 6, Color(0.6, 0.6, 0.65))
		"hoe":
			if rotate:
				_draw_rect(img, wx - 4, wy, 10, 2, Color(0.5, 0.35, 0.15))
				_draw_rect(img, wx - 8, wy - 1, 6, 3, Color(0.6, 0.6, 0.65))
			else:
				_draw_rect(img, wx, wy, 2, 14, Color(0.5, 0.35, 0.15))
				_draw_rect(img, wx - 4, wy, 8, 3, Color(0.6, 0.6, 0.65))
		"wrench":
			if rotate:
				_draw_rect(img, wx - 4, wy, 10, 2, Color(0.6, 0.6, 0.65))
				_draw_rect(img, wx - 6, wy - 1, 4, 4, Color(0.65, 0.65, 0.7))
			else:
				_draw_rect(img, wx, wy + 2, 2, 12, Color(0.6, 0.6, 0.65))
				_draw_rect(img, wx - 2, wy, 6, 4, Color(0.65, 0.65, 0.7))
				_draw_rect(img, wx - 1, wy + 1, 4, 2, Color(0.4, 0.4, 0.45))
		"pan":
			if rotate:
				_draw_rect(img, wx - 4, wy, 8, 2, Color(0.4, 0.3, 0.2))
				_draw_rect(img, wx - 8, wy - 2, 8, 6, Color(0.3, 0.3, 0.35))
			else:
				_draw_rect(img, wx, wy + 4, 2, 8, Color(0.4, 0.3, 0.2))
				_draw_rect(img, wx - 4, wy, 10, 8, Color(0.3, 0.3, 0.35))
				_draw_rect(img, wx - 3, wy + 1, 8, 2, Color(0.4, 0.4, 0.45))
		"medkit":
			_draw_rect(img, wx, wy + 2, 6, 8, Color(0.85, 0.85, 0.85))
			_draw_rect(img, wx + 2, wy + 4, 2, 4, Color(0.9, 0.2, 0.2))
			_draw_rect(img, wx + 1, wy + 5, 4, 2, Color(0.9, 0.2, 0.2))
		"tool":
			if rotate:
				_draw_rect(img, wx - 4, wy, 10, 2, Color(0.5, 0.5, 0.55))
				_draw_rect(img, wx - 6, wy - 1, 4, 3, Color(0.3, 0.7, 0.8))
			else:
				_draw_rect(img, wx, wy, 2, 12, Color(0.5, 0.5, 0.55))
				_draw_rect(img, wx - 2, wy, 6, 3, Color(0.3, 0.7, 0.8))
				_draw_rect(img, wx - 1, wy + 12, 4, 2, Color(0.4, 0.4, 0.45))


## 绘制矩形辅助函数
func _draw_rect(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for i in range(x, x + w):
		for j in range(y, y + h):
			if i >= 0 and i < SPRITE_SIZE and j >= 0 and j < SPRITE_SIZE:
				img.set_pixel(i, j, color)
