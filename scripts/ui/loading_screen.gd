extends Control
## 加载界面：显示加载进度，加载完成后进入游戏

@onready var progress_bar: ProgressBar = $VBox/ProgressBar
@onready var progress_label: Label = $VBox/ProgressLabel
@onready var tip_label: Label = $VBox/TipLabel
@onready var stage_label: Label = $VBox/StageLabel

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

const LOAD_STAGES := [
	{"name": "初始化游戏引擎...", "progress": 8},
	{"name": "生成随机世界地图...", "progress": 25},
	{"name": "分布地形（城市/森林/湖泊/山区）...", "progress": 40},
	{"name": "生成资源节点（树木/石头/浆果）...", "progress": 55},
	{"name": "生成人类NPC和废弃载具...", "progress": 70},
	{"name": "放置实验室和病毒源头...", "progress": 80},
	{"name": "初始化玩家和职业系统...", "progress": 90},
	{"name": "连接联机网络...", "progress": 96},
	{"name": "准备就绪，幸存者加油！", "progress": 100},
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
