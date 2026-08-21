extends Control
## 加载界面：显示真实加载进度，监听LoadManager信号
## 功能：
## 1. 监听LoadManager.progress_changed更新进度条
## 2. 显示加载阶段提示文字
## 3. 显示游戏小提示
## 4. 加载完成/失败时自动处理

@onready var progress_bar: ProgressBar = $VBox/ProgressBar
@onready var progress_label: Label = $VBox/ProgressLabel
@onready var tip_label: Label = $VBox/TipLabel
@onready var stage_label: Label = $VBox/StageLabel
@onready var subtitle_label: Label = $VBox/Subtitle
@onready var title_label: Label = $VBox/Title

# 游戏小提示
const TIPS := [
	"提示：按B打开建造菜单，建造围墙保护你的基地",
	"提示：按E打开制作菜单，靠近工作台可解锁更多配方",
	"提示：按TAB打开背包，按F采集资源和交互",
	"提示：夜晚僵尸更敏锐危险，尽量待在有光的地方",
	"提示：不同职业有不同能力，团队协作才能生存",
	"提示：倒地后只有医生能救起，全队倒地游戏结束",
	"提示：按M打开大地图，查看位置和队友标记",
	"提示：按I打开人物属性，升级力量、敏捷、体质、潜行",
	"提示：按T打开科技树，学习书籍解锁新技能",
	"提示：载具可以快速移动，注意油耗和损坏",
	"提示：冬天需要保暖，夏天注意防暑和食物腐烂",
	"提示：尸潮每年爆发一次，提前做好防御准备",
	"提示：实验室是病毒源头，摧毁后可通关游戏",
	"提示：警察会攻击丧尸，但你攻击平民会被警察追捕",
	"提示：书籍可以在建筑物中搜寻到，小概率生成",
]

var _display_progress: float = 0.0  # 显示用的平滑进度
var _target_progress: float = 0.0   # 目标进度
var _title_anim_time: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	# 随机显示一个提示
	tip_label.text = TIPS[randi() % TIPS.size()]
	stage_label.text = ""
	subtitle_label.text = "正在加载世界..."
	
	# 连接LoadManager信号
	if LoadManager:
		LoadManager.progress_changed.connect(_on_progress_changed)
		LoadManager.load_completed.connect(_on_load_completed)
		LoadManager.load_failed.connect(_on_load_failed)
		LoadManager.state_changed.connect(_on_state_changed)
		print("[LoadingScreen] 已连接LoadManager信号")
	else:
		print("[LoadingScreen] 警告：LoadManager未找到")


func _process(delta: float) -> void:
	if not visible:
		return
	
	# 平滑进度条动画
	if abs(_display_progress - _target_progress) > 0.001:
		_display_progress = lerp(_display_progress, _target_progress, delta * 4.0)
		var percent: float = _display_progress * 100.0
		progress_bar.value = percent
		progress_label.text = "%d%%" % int(percent)
	
	# 标题呼吸动画
	_title_anim_time += delta
	var breath: float = 0.85 + 0.15 * sin(_title_anim_time * 2.0)
	title_label.modulate = Color(breath, breath * 0.75, breath * 0.35, 1.0)


# ==================== LoadManager信号处理 ====================

func _on_progress_changed(progress: float, message: String) -> void:
	## 加载进度变化
	if not visible:
		_show_loading()
	_target_progress = clamp(progress, 0.0, 1.0)
	if not message.is_empty():
		stage_label.text = message
		# 根据进度更新副标题
		if progress < 0.3:
			subtitle_label.text = "正在加载资源..."
		elif progress < 0.6:
			subtitle_label.text = "正在初始化世界..."
		elif progress < 0.85:
			subtitle_label.text = "正在恢复数据..."
		else:
			subtitle_label.text = "即将完成..."


func _on_load_completed(scene_path: String, data: Dictionary) -> void:
	## 加载完成
	_target_progress = 1.0
	stage_label.text = "加载完成！"
	subtitle_label.text = "准备进入游戏..."
	# 延迟隐藏（检查场景树是否可用）
	if is_inside_tree() and get_tree():
		await get_tree().create_timer(0.5).timeout
	_hide_loading()


func _on_load_failed(scene_path: String, error: String) -> void:
	## 加载失败
	stage_label.text = "加载失败：%s" % error
	subtitle_label.text = "即将返回主菜单..."
	progress_bar.modulate = Color(1, 0.3, 0.3, 1)
	if is_inside_tree() and get_tree():
		await get_tree().create_timer(2.0).timeout
	_hide_loading()
	progress_bar.modulate = Color.WHITE


func _on_state_changed(new_state: int) -> void:
	## 加载状态变化
	match new_state:
		0: # IDLE
			# 不自动隐藏，等加载完成后隐藏
			pass
		1: # LOADING
			_show_loading()
		2: # INITIALIZING
			stage_label.text = "正在初始化..."
		3: # COMPLETED
			pass
		4: # FAILED
			pass


# ==================== 显示/隐藏 ====================

func _show_loading() -> void:
	## 显示加载界面
	if visible:
		return
	visible = true
	_display_progress = 0.0
	_target_progress = 0.0
	progress_bar.value = 0
	progress_label.text = "0%"
	stage_label.text = "正在准备..."
	# 每次显示随机一个提示
	tip_label.text = TIPS[randi() % TIPS.size()]
	print("[LoadingScreen] 显示加载界面")


func _hide_loading() -> void:
	## 隐藏加载界面
	visible = false
	print("[LoadingScreen] 隐藏加载界面")


# ==================== 手动控制（备用） ====================

func show_loading() -> void:
	## 手动显示加载界面
	_show_loading()


func hide_loading() -> void:
	## 手动隐藏加载界面
	_hide_loading()


func set_progress(value: float, stage_text: String = "") -> void:
	## 手动设置进度（0.0-1.0）
	_target_progress = clamp(value, 0.0, 1.0)
	if not stage_text.is_empty():
		stage_label.text = stage_text


func is_loading() -> bool:
	return visible
