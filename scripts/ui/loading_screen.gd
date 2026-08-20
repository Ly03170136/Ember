extends Control
## 加载界面：显示加载进度，加载完成后进入游戏

@onready var progress_bar: ProgressBar = $VBox/ProgressBar
@onready var progress_label: Label = $VBox/ProgressLabel
@onready var tip_label: Label = $VBox/TipLabel
@onready var stage_label: Label = $VBox/StageLabel

const TIPS := [
	"提示：按B打开建造菜单，按E打开制作菜单",
	"提示：按TAB打开背包，按F采集资源",
	"提示：夜晚僵尸更危险，尽量待在有光的地方",
	"提示：建造围墙可以保护你的基地",
	"提示：不同职业有不同的能力，合理分工",
	"提示：倒地后需要医生来救，全队倒地游戏结束",
	"提示：按M打开大地图，查看你的位置",
	"提示：按I打开人物属性面板，升级属性",
	"提示：按T打开科技树，学习新技能",
	"提示：载具可以快速移动，注意油耗",
]

const LOAD_STAGES := [
	{"name": "初始化游戏引擎...", "progress": 10},
	{"name": "生成世界地图...", "progress": 30},
	{"name": "生成资源节点...", "progress": 50},
	{"name": "生成NPC和载具...", "progress": 70},
	{"name": "初始化玩家...", "progress": 85},
	{"name": "准备就绪...", "progress": 100},
]

var _progress: float = 0.0
var _loading: bool = false
var _current_stage: int = 0


func _ready() -> void:
	# 随机显示一个提示
	tip_label.text = TIPS[randi() % TIPS.size()]
	stage_label.text = ""


func start_loading() -> void:
	visible = true
	_loading = true
	_progress = 0.0
	_current_stage = 0
	progress_bar.value = 0
	progress_label.text = "0%"
	stage_label.text = LOAD_STAGES[0].name
	# 模拟加载过程（分阶段）
	for stage in LOAD_STAGES:
		stage_label.text = stage.name
		var target_progress: float = stage.progress
		while _progress < target_progress:
			await get_tree().process_frame
			_progress = min(target_progress, _progress + 0.8)
			progress_bar.value = _progress
			progress_label.text = "%d%%" % int(_progress)
		# 每个阶段短暂停留
		await get_tree().create_timer(0.15).timeout
	# 确保达到100%
	_progress = 100.0
	progress_bar.value = 100
	progress_label.text = "100%"
	stage_label.text = "加载完成！"
	await get_tree().create_timer(0.3).timeout
	_loading = false
	# 加载完成，隐藏加载界面
	visible = false
	print("[Loading] 加载完成，进入游戏")


func is_loading() -> bool:
	return _loading


func set_progress(value: float, stage_text: String = "") -> void:
	## 外部设置加载进度
	_progress = clamp(value, 0, 100)
	progress_bar.value = _progress
	progress_label.text = "%d%%" % int(_progress)
	if stage_text != "":
		stage_label.text = stage_text
