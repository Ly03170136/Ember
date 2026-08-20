extends Node
## 美术资源生成器：程序生成像素风格的图标和精灵
## 自动加载为全局单例，通过 ArtAssets 访问

const ICON_SIZE := 32

static var _icon_cache: Dictionary = {}


## 获取物品图标
static func get_item_icon(item_id: String) -> Texture2D:
	if _icon_cache.has("item_" + item_id):
		return _icon_cache["item_" + item_id]
	var img := Image.create(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	match item_id:
		"wood":
			_draw_wood_icon(img)
		"stone":
			_draw_stone_icon(img)
		"fiber":
			_draw_fiber_icon(img)
		"metal":
			_draw_metal_icon(img)
		"cloth":
			_draw_cloth_icon(img)
		"scrap":
			_draw_scrap_icon(img)
		"berry":
			_draw_berry_icon(img)
		"stone_axe":
			_draw_axe_icon(img, Color(0.6, 0.6, 0.65))
		"stone_pickaxe":
			_draw_pickaxe_icon(img, Color(0.6, 0.6, 0.65))
		"metal_axe":
			_draw_axe_icon(img, Color(0.8, 0.8, 0.85))
		"wooden_club":
			_draw_club_icon(img)
		"stone_spear":
			_draw_spear_icon(img, Color(0.6, 0.6, 0.65))
		"metal_sword":
			_draw_sword_icon(img)
		"cooked_meat":
			_draw_meat_icon(img, Color(0.7, 0.35, 0.2))
		"cooked_berry":
			_draw_berry_icon(img, Color(0.5, 0.05, 0.05))
		"water":
			_draw_water_icon(img)
		"bandage":
			_draw_bandage_icon(img)
		"medkit":
			_draw_medkit_icon(img)
		"wall_wood":
			_draw_wall_icon(img)
		"door_wood":
			_draw_door_icon(img)
		_:
			_draw_default_icon(img)
	var tex := ImageTexture.create_from_image(img)
	_icon_cache["item_" + item_id] = tex
	return tex


## 绘制像素
static func _px(img: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and x < ICON_SIZE and y >= 0 and y < ICON_SIZE:
		img.set_pixel(x, y, color)


## 绘制矩形
static func _rect(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for i in range(x, x + w):
		for j in range(y, y + h):
			_px(img, i, j, color)


static func _draw_wood_icon(img: Image) -> void:
	# 木材：棕色矩形带木纹
	_rect(img, 6, 10, 20, 12, Color(0.55, 0.35, 0.15))
	_rect(img, 6, 10, 20, 2, Color(0.4, 0.25, 0.1))
	_rect(img, 6, 20, 20, 2, Color(0.4, 0.25, 0.1))
	for i in range(8, 24, 4):
		_px(img, i, 15, Color(0.45, 0.28, 0.12))
		_px(img, i, 17, Color(0.45, 0.28, 0.12))


static func _draw_stone_icon(img: Image) -> void:
	# 石头：灰色不规则形状
	_rect(img, 8, 10, 16, 12, Color(0.55, 0.55, 0.6))
	_rect(img, 10, 8, 12, 2, Color(0.6, 0.6, 0.65))
	_rect(img, 6, 14, 2, 6, Color(0.5, 0.5, 0.55))
	_rect(img, 24, 12, 2, 8, Color(0.5, 0.5, 0.55))
	_px(img, 12, 14, Color(0.45, 0.45, 0.5))
	_px(img, 18, 16, Color(0.45, 0.45, 0.5))


static func _draw_fiber_icon(img: Image) -> void:
	# 纤维：黄色线条
	for i in range(6):
		_rect(img, 8 + i * 3, 8, 2, 16, Color(0.75, 0.7, 0.4))
	_rect(img, 6, 14, 20, 4, Color(0.65, 0.6, 0.35))


static func _draw_metal_icon(img: Image) -> void:
	# 金属锭：银灰色矩形
	_rect(img, 6, 12, 20, 8, Color(0.75, 0.75, 0.8))
	_rect(img, 6, 12, 20, 2, Color(0.9, 0.9, 0.95))
	_rect(img, 6, 18, 20, 2, Color(0.55, 0.55, 0.6))
	_px(img, 10, 15, Color(0.85, 0.85, 0.9))
	_px(img, 16, 16, Color(0.85, 0.85, 0.9))


static func _draw_cloth_icon(img: Image) -> void:
	# 布料：白色折叠布
	_rect(img, 6, 8, 20, 16, Color(0.85, 0.8, 0.75))
	_rect(img, 6, 8, 20, 2, Color(0.95, 0.9, 0.85))
	_rect(img, 8, 12, 16, 1, Color(0.7, 0.65, 0.6))
	_rect(img, 8, 16, 16, 1, Color(0.7, 0.65, 0.6))
	_rect(img, 8, 20, 16, 1, Color(0.7, 0.65, 0.6))


static func _draw_scrap_icon(img: Image) -> void:
	# 废铁：深灰色不规则
	_rect(img, 8, 12, 14, 8, Color(0.45, 0.45, 0.5))
	_rect(img, 18, 10, 6, 4, Color(0.4, 0.4, 0.45))
	_rect(img, 6, 16, 4, 4, Color(0.5, 0.5, 0.55))
	_px(img, 12, 14, Color(0.6, 0.6, 0.65))
	_px(img, 16, 17, Color(0.35, 0.35, 0.4))


static func _draw_berry_icon(img: Image, color: Color = Color(0.8, 0.1, 0.1)) -> void:
	# 浆果：红色圆形带叶子
	_rect(img, 10, 12, 12, 10, color)
	_px(img, 9, 14, color)
	_px(img, 23, 14, color)
	_px(img, 9, 19, color)
	_px(img, 23, 19, color)
	_px(img, 12, 11, color)
	_px(img, 20, 11, color)
	# 高光
	_px(img, 13, 14, Color(1, 0.5, 0.5))
	_px(img, 14, 15, Color(1, 0.5, 0.5))
	# 叶子
	_rect(img, 14, 8, 4, 3, Color(0.2, 0.6, 0.2))


static func _draw_axe_icon(img: Image, head_color: Color) -> void:
	# 斧头：木柄+斧头
	_rect(img, 14, 6, 4, 20, Color(0.5, 0.35, 0.15))
	_rect(img, 8, 6, 16, 6, head_color)
	_rect(img, 6, 8, 4, 4, head_color)
	_rect(img, 22, 8, 4, 4, head_color)
	_rect(img, 8, 6, 16, 2, head_color.lightened(0.2))


static func _draw_pickaxe_icon(img: Image, head_color: Color) -> void:
	# 镐子：木柄+镐头
	_rect(img, 14, 8, 4, 18, Color(0.5, 0.35, 0.15))
	_rect(img, 6, 6, 20, 4, head_color)
	_rect(img, 4, 8, 4, 4, head_color)
	_rect(img, 24, 8, 4, 4, head_color)
	_rect(img, 6, 6, 20, 1, head_color.lightened(0.2))


static func _draw_club_icon(img: Image) -> void:
	# 木棍：棕色粗棒
	_rect(img, 12, 4, 8, 24, Color(0.5, 0.35, 0.15))
	_rect(img, 10, 4, 12, 6, Color(0.55, 0.38, 0.18))
	_rect(img, 12, 4, 8, 2, Color(0.6, 0.42, 0.2))
	for i in range(8, 26, 4):
		_px(img, 14, i, Color(0.4, 0.28, 0.12))
		_px(img, 17, i + 2, Color(0.4, 0.28, 0.12))


static func _draw_spear_icon(img: Image, head_color: Color) -> void:
	# 矛：长杆+矛头
	_rect(img, 15, 8, 2, 20, Color(0.5, 0.35, 0.15))
	_rect(img, 13, 4, 6, 6, head_color)
	_px(img, 14, 3, head_color)
	_px(img, 15, 2, head_color)
	_px(img, 16, 3, head_color)
	_rect(img, 13, 4, 6, 1, head_color.lightened(0.2))


static func _draw_sword_icon(img: Image) -> void:
	# 剑：金属剑刃+护手+柄
	_rect(img, 14, 4, 4, 16, Color(0.8, 0.8, 0.85))
	_rect(img, 15, 4, 2, 14, Color(0.95, 0.95, 1))
	_rect(img, 10, 18, 12, 3, Color(0.6, 0.5, 0.3))
	_rect(img, 14, 21, 4, 6, Color(0.5, 0.35, 0.15))
	_rect(img, 13, 26, 6, 2, Color(0.6, 0.5, 0.3))


static func _draw_meat_icon(img: Image, color: Color) -> void:
	# 肉：不规则形状带骨头
	_rect(img, 8, 10, 14, 10, color)
	_px(img, 7, 12, color)
	_px(img, 7, 17, color)
	_px(img, 22, 13, color)
	_px(img, 22, 16, color)
	# 骨头
	_rect(img, 20, 14, 6, 3, Color(0.9, 0.85, 0.75))
	_px(img, 25, 13, Color(0.9, 0.85, 0.75))
	_px(img, 25, 17, Color(0.9, 0.85, 0.75))
	# 高光
	_px(img, 11, 12, color.lightened(0.2))
	_px(img, 14, 13, color.lightened(0.2))


static func _draw_water_icon(img: Image) -> void:
	# 水：蓝色水滴/瓶子
	_rect(img, 12, 6, 8, 4, Color(0.7, 0.7, 0.75))
	_rect(img, 10, 10, 12, 14, Color(0.3, 0.6, 0.9))
	_rect(img, 10, 10, 12, 2, Color(0.5, 0.8, 1))
	_px(img, 12, 14, Color(0.6, 0.85, 1))
	_px(img, 13, 15, Color(0.6, 0.85, 1))
	_px(img, 14, 16, Color(0.6, 0.85, 1))


static func _draw_bandage_icon(img: Image) -> void:
	# 绷带：白色卷
	_rect(img, 8, 10, 16, 12, Color(0.9, 0.9, 0.9))
	_rect(img, 8, 10, 16, 2, Color(1, 1, 1))
	_rect(img, 8, 20, 16, 2, Color(0.75, 0.75, 0.75))
	_rect(img, 14, 10, 4, 12, Color(0.85, 0.85, 0.85))
	# 红十字
	_rect(img, 14, 13, 4, 6, Color(0.9, 0.2, 0.2))
	_rect(img, 12, 15, 8, 2, Color(0.9, 0.2, 0.2))


static func _draw_medkit_icon(img: Image) -> void:
	# 医疗包：白色箱子+红十字
	_rect(img, 6, 8, 20, 16, Color(0.85, 0.85, 0.85))
	_rect(img, 6, 8, 20, 2, Color(0.95, 0.95, 0.95))
	_rect(img, 6, 22, 20, 2, Color(0.7, 0.7, 0.7))
	# 红十字
	_rect(img, 14, 11, 4, 10, Color(0.9, 0.15, 0.15))
	_rect(img, 10, 14, 12, 4, Color(0.9, 0.15, 0.15))
	# 提手
	_rect(img, 12, 5, 8, 3, Color(0.6, 0.6, 0.65))


static func _draw_wall_icon(img: Image) -> void:
	# 木墙：木板纹理
	_rect(img, 4, 4, 24, 24, Color(0.5, 0.35, 0.15))
	for i in range(4, 28, 6):
		_rect(img, i, 4, 1, 24, Color(0.4, 0.28, 0.12))
	for j in range(4, 28, 8):
		_rect(img, 4, j, 24, 1, Color(0.4, 0.28, 0.12))
	# 钉子
	_px(img, 7, 7, Color(0.3, 0.3, 0.3))
	_px(img, 24, 7, Color(0.3, 0.3, 0.3))
	_px(img, 7, 24, Color(0.3, 0.3, 0.3))
	_px(img, 24, 24, Color(0.3, 0.3, 0.3))


static func _draw_door_icon(img: Image) -> void:
	# 木门：带门把手
	_rect(img, 8, 4, 16, 24, Color(0.45, 0.3, 0.12))
	_rect(img, 8, 4, 16, 2, Color(0.55, 0.38, 0.18))
	for i in range(10, 22, 4):
		_rect(img, i, 6, 1, 20, Color(0.35, 0.22, 0.08))
	# 门把手
	_px(img, 20, 15, Color(0.8, 0.7, 0.3))
	_px(img, 20, 16, Color(0.8, 0.7, 0.3))
	_px(img, 21, 15, Color(0.9, 0.8, 0.4))


static func _draw_default_icon(img: Image) -> void:
	# 默认图标：问号
	_rect(img, 6, 6, 20, 20, Color(0.5, 0.5, 0.5))
	_rect(img, 14, 10, 4, 4, Color(1, 1, 1))
	_rect(img, 14, 16, 4, 2, Color(1, 1, 1))
	_px(img, 15, 19, Color(1, 1, 1))
	_px(img, 16, 22, Color(1, 1, 1))


## ==================== 建筑图标 ====================

static var _building_icon_cache: Dictionary = {}

## 获取建筑图标
static func get_building_icon(building_id: String) -> Texture2D:
	if _building_icon_cache.has(building_id):
		return _building_icon_cache[building_id]
	var img := Image.create(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	match building_id:
		"campfire":
			_draw_campfire_icon(img)
		"wall_wood":
			_draw_wall_icon(img)
		"door_wood":
			_draw_door_icon(img)
		"workbench":
			_draw_workbench_icon(img)
		"storage":
			_draw_storage_icon(img)
		"bed":
			_draw_bed_icon(img)
		"trap":
			_draw_trap_icon(img)
		"torch":
			_draw_torch_icon(img)
		"farm_plot":
			_draw_farm_plot_icon(img)
		"small_generator":
			_draw_generator_icon(img)
		"electric_light":
			_draw_electric_light_icon(img)
		"auto_turret":
			_draw_turret_icon(img)
		"laboratory":
			_draw_laboratory_icon(img)
		_:
			_draw_default_building_icon(img)
	var tex := ImageTexture.create_from_image(img)
	_building_icon_cache[building_id] = tex
	return tex


static func _draw_campfire_icon(img: Image) -> void:
	# 石头圈
	_rect(img, 8, 22, 16, 4, Color(0.5, 0.5, 0.55))
	_px(img, 7, 23, Color(0.55, 0.55, 0.6))
	_px(img, 24, 23, Color(0.55, 0.55, 0.6))
	# 木柴
	_rect(img, 10, 18, 12, 3, Color(0.45, 0.3, 0.15))
	_rect(img, 12, 16, 8, 2, Color(0.5, 0.35, 0.18))
	# 火焰
	_rect(img, 13, 8, 6, 8, Color(0.9, 0.4, 0.1))
	_rect(img, 14, 6, 4, 4, Color(1, 0.6, 0.2))
	_px(img, 15, 5, Color(1, 0.8, 0.4))
	_rect(img, 14, 10, 4, 4, Color(1, 0.7, 0.3))


static func _draw_workbench_icon(img: Image) -> void:
	# 桌面
	_rect(img, 4, 12, 24, 4, Color(0.6, 0.45, 0.25))
	_rect(img, 4, 12, 24, 1, Color(0.7, 0.55, 0.35))
	# 桌腿
	_rect(img, 6, 16, 3, 10, Color(0.5, 0.38, 0.2))
	_rect(img, 23, 16, 3, 10, Color(0.5, 0.38, 0.2))
	# 工具
	_rect(img, 10, 8, 2, 6, Color(0.5, 0.35, 0.15))
	_rect(img, 8, 6, 6, 3, Color(0.65, 0.65, 0.7))
	_rect(img, 18, 9, 2, 5, Color(0.5, 0.35, 0.15))
	_rect(img, 16, 7, 6, 3, Color(0.6, 0.6, 0.65))


static func _draw_storage_icon(img: Image) -> void:
	# 木箱
	_rect(img, 5, 8, 22, 18, Color(0.65, 0.45, 0.2))
	_rect(img, 5, 8, 22, 2, Color(0.75, 0.55, 0.3))
	_rect(img, 5, 24, 22, 2, Color(0.5, 0.35, 0.15))
	# 木板纹理
	_rect(img, 5, 14, 22, 1, Color(0.55, 0.38, 0.18))
	_rect(img, 5, 19, 22, 1, Color(0.55, 0.38, 0.18))
	# 金属包边
	_rect(img, 5, 8, 2, 18, Color(0.4, 0.4, 0.45))
	_rect(img, 25, 8, 2, 18, Color(0.4, 0.4, 0.45))
	# 锁
	_rect(img, 14, 15, 4, 4, Color(0.7, 0.6, 0.3))


static func _draw_bed_icon(img: Image) -> void:
	# 床架
	_rect(img, 4, 14, 24, 10, Color(0.55, 0.4, 0.25))
	_rect(img, 4, 14, 24, 2, Color(0.65, 0.5, 0.35))
	# 床垫
	_rect(img, 6, 12, 20, 4, Color(0.8, 0.75, 0.7))
	# 枕头
	_rect(img, 6, 10, 6, 3, Color(0.9, 0.9, 0.85))
	# 被子
	_rect(img, 14, 12, 12, 4, Color(0.6, 0.5, 0.6))
	# 床腿
	_rect(img, 5, 24, 2, 4, Color(0.45, 0.32, 0.2))
	_rect(img, 25, 24, 2, 4, Color(0.45, 0.32, 0.2))


static func _draw_trap_icon(img: Image) -> void:
	# 底座
	_rect(img, 6, 20, 20, 6, Color(0.4, 0.4, 0.45))
	# 尖刺
	for i in range(5):
		var sx := 8 + i * 4
		_px(img, sx, 18, Color(0.7, 0.7, 0.75))
		_px(img, sx, 17, Color(0.7, 0.7, 0.75))
		_px(img, sx + 1, 16, Color(0.75, 0.75, 0.8))
		_px(img, sx, 15, Color(0.8, 0.8, 0.85))
	# 血迹
	_px(img, 12, 19, Color(0.7, 0.1, 0.1))
	_px(img, 18, 20, Color(0.6, 0.08, 0.08))


static func _draw_torch_icon(img: Image) -> void:
	# 手柄
	_rect(img, 14, 14, 4, 14, Color(0.5, 0.35, 0.15))
	# 火把头
	_rect(img, 12, 10, 8, 5, Color(0.4, 0.4, 0.45))
	# 火焰
	_rect(img, 13, 4, 6, 7, Color(0.9, 0.4, 0.1))
	_rect(img, 14, 2, 4, 4, Color(1, 0.6, 0.2))
	_px(img, 15, 1, Color(1, 0.8, 0.4))
	_rect(img, 14, 5, 4, 3, Color(1, 0.7, 0.3))


static func _draw_farm_plot_icon(img: Image) -> void:
	# 泥土背景
	_rect(img, 4, 8, 24, 20, Color(0.45, 0.3, 0.15))
	# 田垄
	_rect(img, 6, 10, 20, 2, Color(0.35, 0.22, 0.1))
	_rect(img, 6, 15, 20, 2, Color(0.35, 0.22, 0.1))
	_rect(img, 6, 20, 20, 2, Color(0.35, 0.22, 0.1))
	_rect(img, 6, 25, 20, 2, Color(0.35, 0.22, 0.1))
	# 小苗
	_px(img, 10, 12, Color(0.4, 0.7, 0.3))
	_px(img, 18, 12, Color(0.4, 0.7, 0.3))
	_px(img, 26, 12, Color(0.4, 0.7, 0.3))
	_px(img, 10, 17, Color(0.4, 0.7, 0.3))
	_px(img, 18, 17, Color(0.4, 0.7, 0.3))
	_px(img, 26, 17, Color(0.4, 0.7, 0.3))


static func _draw_generator_icon(img: Image) -> void:
	# 机身
	_rect(img, 6, 12, 20, 16, Color(0.6, 0.6, 0.65))
	# 油箱
	_rect(img, 8, 8, 8, 6, Color(0.7, 0.3, 0.2))
	# 控制面板
	_rect(img, 18, 10, 6, 4, Color(0.3, 0.3, 0.35))
	_px(img, 19, 11, Color(0, 1, 0))
	_px(img, 22, 11, Color(1, 0.5, 0))
	# 散热口
	_rect(img, 8, 20, 16, 2, Color(0.4, 0.4, 0.45))
	_rect(img, 8, 23, 16, 2, Color(0.4, 0.4, 0.45))
	# 轮子
	_px(img, 8, 28, Color(0.2, 0.2, 0.2))
	_px(img, 24, 28, Color(0.2, 0.2, 0.2))


static func _draw_electric_light_icon(img: Image) -> void:
	# 灯泡
	_rect(img, 12, 6, 8, 10, Color(1, 0.95, 0.6))
	_px(img, 11, 8, Color(1, 0.95, 0.6))
	_px(img, 20, 8, Color(1, 0.95, 0.6))
	_px(img, 11, 13, Color(1, 0.95, 0.6))
	_px(img, 20, 13, Color(1, 0.95, 0.6))
	# 灯丝
	_rect(img, 14, 9, 4, 4, Color(1, 0.8, 0.3))
	# 灯头
	_rect(img, 13, 16, 6, 3, Color(0.5, 0.5, 0.55))
	_rect(img, 14, 19, 4, 2, Color(0.4, 0.4, 0.45))
	# 光线
	_px(img, 8, 10, Color(1, 0.9, 0.5))
	_px(img, 24, 10, Color(1, 0.9, 0.5))
	_px(img, 6, 14, Color(1, 0.9, 0.5))
	_px(img, 26, 14, Color(1, 0.9, 0.5))


static func _draw_turret_icon(img: Image) -> void:
	# 底座
	_rect(img, 8, 20, 16, 8, Color(0.4, 0.4, 0.45))
	# 炮塔主体
	_rect(img, 10, 14, 12, 8, Color(0.5, 0.5, 0.55))
	# 炮管
	_rect(img, 14, 6, 4, 10, Color(0.3, 0.3, 0.35))
	_px(img, 13, 7, Color(0.3, 0.3, 0.35))
	_px(img, 18, 7, Color(0.3, 0.3, 0.35))
	# 炮口
	_rect(img, 13, 4, 6, 3, Color(0.2, 0.2, 0.25))
	# 指示灯
	_px(img, 12, 17, Color(1, 0.2, 0.2))
	_px(img, 20, 17, Color(0, 1, 0))


static func _draw_laboratory_icon(img: Image) -> void:
	# 实验室建筑图标
	# 主体建筑
	_rect(img, 4, 8, 24, 20, Color(0.35, 0.38, 0.42))
	_rect(img, 4, 8, 24, 2, Color(0.45, 0.48, 0.52))
	# 屋顶
	_rect(img, 2, 6, 28, 3, Color(0.3, 0.33, 0.37))
	# 门
	_rect(img, 13, 18, 6, 10, Color(0.2, 0.22, 0.25))
	_rect(img, 14, 19, 4, 8, Color(0.25, 0.28, 0.32))
	# 窗户（发光的绿色，暗示病毒）
	_rect(img, 6, 12, 4, 4, Color(0.2, 0.6, 0.3))
	_rect(img, 22, 12, 4, 4, Color(0.2, 0.6, 0.3))
	_rect(img, 6, 12, 4, 1, Color(0.4, 0.8, 0.5))
	_rect(img, 22, 12, 4, 1, Color(0.4, 0.8, 0.5))
	# 生物危害标志（简化）
	_px(img, 15, 11, Color(0.8, 0.8, 0.2))
	_px(img, 16, 11, Color(0.8, 0.8, 0.2))
	_px(img, 14, 12, Color(0.8, 0.8, 0.2))
	_px(img, 17, 12, Color(0.8, 0.8, 0.2))
	_px(img, 15, 13, Color(0.8, 0.8, 0.2))
	_px(img, 16, 13, Color(0.8, 0.8, 0.2))
	# 烟囱
	_rect(img, 20, 2, 3, 6, Color(0.3, 0.32, 0.36))
	_px(img, 21, 1, Color(0.4, 0.4, 0.4))


static func _draw_default_building_icon(img: Image) -> void:
	# 默认建筑图标：房子
	_rect(img, 6, 14, 20, 14, Color(0.6, 0.5, 0.4))
	# 屋顶
	_rect(img, 4, 10, 24, 4, Color(0.7, 0.3, 0.2))
	_px(img, 5, 9, Color(0.7, 0.3, 0.2))
	_px(img, 26, 9, Color(0.7, 0.3, 0.2))
	# 门
	_rect(img, 13, 18, 6, 10, Color(0.4, 0.3, 0.2))
	_px(img, 17, 23, Color(0.8, 0.7, 0.3))
	# 窗户
	_rect(img, 8, 16, 4, 4, Color(0.6, 0.7, 0.8))
	_rect(img, 20, 16, 4, 4, Color(0.6, 0.7, 0.8))


# ==================== 地面瓦片纹理 ====================
const TILE_SIZE := 64
static var _tile_cache: Dictionary = {}


## 获取地面瓦片纹理
static func get_tile_texture(tile_type: String) -> Texture2D:
	if _tile_cache.has(tile_type):
		return _tile_cache[tile_type]
	var img := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	match tile_type:
		"grass":
			_draw_grass_tile(img)
		"dirt":
			_draw_dirt_tile(img)
		"stone":
			_draw_stone_tile(img)
		"sand":
			_draw_sand_tile(img)
		"water":
			_draw_water_tile(img)
		"concrete":
			_draw_concrete_tile(img)
		"snow":
			_draw_snow_tile(img)
		_:
			_draw_grass_tile(img)
	var tex := ImageTexture.create_from_image(img)
	_tile_cache[tile_type] = tex
	return tex


static func _draw_grass_tile(img: Image) -> void:
	# 基础草地颜色
	img.fill(Color(0.35, 0.55, 0.25))
	# 随机深浅斑点
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for i in range(200):
		var x: int = rng.randi_range(0, TILE_SIZE - 1)
		var y: int = rng.randi_range(0, TILE_SIZE - 1)
		var shade: float = rng.randf_range(-0.1, 0.1)
		_px(img, x, y, Color(0.35 + shade, 0.55 + shade, 0.25 + shade))
	# 一些草叶
	for i in range(30):
		var x: int = rng.randi_range(0, TILE_SIZE - 2)
		var y: int = rng.randi_range(0, TILE_SIZE - 3)
		_px(img, x, y, Color(0.45, 0.65, 0.3))
		_px(img, x + 1, y + 1, Color(0.4, 0.6, 0.28))


static func _draw_dirt_tile(img: Image) -> void:
	img.fill(Color(0.45, 0.32, 0.2))
	var rng := RandomNumberGenerator.new()
	rng.seed = 23456
	for i in range(250):
		var x: int = rng.randi_range(0, TILE_SIZE - 1)
		var y: int = rng.randi_range(0, TILE_SIZE - 1)
		var shade: float = rng.randf_range(-0.08, 0.08)
		_px(img, x, y, Color(0.45 + shade, 0.32 + shade, 0.2 + shade))
	# 小石子
	for i in range(15):
		var x: int = rng.randi_range(0, TILE_SIZE - 2)
		var y: int = rng.randi_range(0, TILE_SIZE - 2)
		_px(img, x, y, Color(0.5, 0.45, 0.4))
		_px(img, x + 1, y, Color(0.45, 0.4, 0.35))


static func _draw_stone_tile(img: Image) -> void:
	img.fill(Color(0.45, 0.45, 0.48))
	var rng := RandomNumberGenerator.new()
	rng.seed = 34567
	# 裂纹
	for i in range(8):
		var x: int = rng.randi_range(0, TILE_SIZE - 1)
		var y: int = rng.randi_range(0, TILE_SIZE - 1)
		var len: int = rng.randi_range(5, 15)
		for j in range(len):
			if x + j < TILE_SIZE:
				_px(img, x + j, y, Color(0.3, 0.3, 0.32))
	# 随机斑点
	for i in range(200):
		var x: int = rng.randi_range(0, TILE_SIZE - 1)
		var y: int = rng.randi_range(0, TILE_SIZE - 1)
		var shade: float = rng.randf_range(-0.1, 0.1)
		_px(img, x, y, Color(0.45 + shade, 0.45 + shade, 0.48 + shade))


static func _draw_sand_tile(img: Image) -> void:
	img.fill(Color(0.75, 0.68, 0.5))
	var rng := RandomNumberGenerator.new()
	rng.seed = 45678
	for i in range(300):
		var x: int = rng.randi_range(0, TILE_SIZE - 1)
		var y: int = rng.randi_range(0, TILE_SIZE - 1)
		var shade: float = rng.randf_range(-0.06, 0.06)
		_px(img, x, y, Color(0.75 + shade, 0.68 + shade, 0.5 + shade))
	# 沙纹
	for i in range(5):
		var y: int = rng.randi_range(5, TILE_SIZE - 5)
		for x in range(TILE_SIZE):
			if x % 3 == 0:
				_px(img, x, y, Color(0.7, 0.63, 0.45))


static func _draw_water_tile(img: Image) -> void:
	img.fill(Color(0.2, 0.4, 0.65))
	var rng := RandomNumberGenerator.new()
	rng.seed = 56789
	# 波纹
	for i in range(8):
		var y: int = rng.randi_range(2, TILE_SIZE - 2)
		for x in range(TILE_SIZE):
			var wave: float = sin(x * 0.3 + i) * 0.05
			_px(img, x, y, Color(0.25 + wave, 0.45 + wave, 0.7 + wave))
	# 高光
	for i in range(20):
		var x: int = rng.randi_range(0, TILE_SIZE - 3)
		var y: int = rng.randi_range(0, TILE_SIZE - 1)
		_px(img, x, y, Color(0.4, 0.6, 0.8, 0.5))
		_px(img, x + 1, y, Color(0.4, 0.6, 0.8, 0.3))
		_px(img, x + 2, y, Color(0.4, 0.6, 0.8, 0.2))


static func _draw_concrete_tile(img: Image) -> void:
	img.fill(Color(0.5, 0.5, 0.52))
	var rng := RandomNumberGenerator.new()
	rng.seed = 67890
	# 裂纹
	for i in range(12):
		var x: int = rng.randi_range(0, TILE_SIZE - 1)
		var y: int = rng.randi_range(0, TILE_SIZE - 1)
		var len: int = rng.randi_range(8, 25)
		var dir: int = rng.randi_range(0, 1)
		for j in range(len):
			if dir == 0 and x + j < TILE_SIZE:
				_px(img, x + j, y, Color(0.3, 0.3, 0.32))
			elif dir == 1 and y + j < TILE_SIZE:
				_px(img, x, y + j, Color(0.3, 0.3, 0.32))
	# 污渍
	for i in range(10):
		var x: int = rng.randi_range(0, TILE_SIZE - 4)
		var y: int = rng.randi_range(0, TILE_SIZE - 4)
		_rect(img, x, y, 4, 4, Color(0.35, 0.3, 0.25, 0.4))
	# 随机斑点
	for i in range(150):
		var x: int = rng.randi_range(0, TILE_SIZE - 1)
		var y: int = rng.randi_range(0, TILE_SIZE - 1)
		var shade: float = rng.randf_range(-0.08, 0.08)
		_px(img, x, y, Color(0.5 + shade, 0.5 + shade, 0.52 + shade))


static func _draw_snow_tile(img: Image) -> void:
	img.fill(Color(0.9, 0.92, 0.95))
	var rng := RandomNumberGenerator.new()
	rng.seed = 78901
	for i in range(200):
		var x: int = rng.randi_range(0, TILE_SIZE - 1)
		var y: int = rng.randi_range(0, TILE_SIZE - 1)
		var shade: float = rng.randf_range(-0.05, 0.03)
		_px(img, x, y, Color(0.9 + shade, 0.92 + shade, 0.95 + shade))
	# 一些露出的地面
	for i in range(8):
		var x: int = rng.randi_range(0, TILE_SIZE - 3)
		var y: int = rng.randi_range(0, TILE_SIZE - 3)
		_rect(img, x, y, 3, 2, Color(0.45, 0.4, 0.35, 0.6))
