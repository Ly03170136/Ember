extends Control
## 过场动画：前2秒穿越时空，后5秒生成世界，7秒后进入游戏

@onready var bg: ColorRect = $Background
@onready var title_label: Label = $VBox/TitleLabel
@onready var subtitle_label: Label = $VBox/SubtitleLabel
@onready var progress_bar: ProgressBar = $VBox/ProgressBar
@onready var hint_label: Label = $VBox/HintLabel

var _elapsed: float = 0.0
var _total_duration: float = 7.0  # 7秒
var _started: bool = false


func _ready() -> void:
	# 初始化：所有元素透明
	title_label.modulate.a = 0.0
	subtitle_label.modulate.a = 0.0
	progress_bar.modulate.a = 0.0
	hint_label.modulate.a = 0.0
	bg.color = Color(0, 0, 0, 1)
	progress_bar.value = 0.0
	_started = true
	print("[Cutscene] 过场动画开始：正在穿越时空...")


func _process(delta: float) -> void:
	if not _started:
		return
	
	_elapsed += delta
	var t: float = clamp(_elapsed / _total_duration, 0.0, 1.0)
	
	# 背景颜色：黑色→深蓝（前半段），后半段保持深蓝
	if t < 0.5:
		var bg_t: float = t * 2.0
		bg.color = Color(0, 0, 0).lerp(Color(0.05, 0.05, 0.15), bg_t)
	else:
		bg.color = Color(0.05, 0.05, 0.15)
	
	# 标题：0.1-0.25秒淡入，之后保持显示
	if t < 0.1:
		title_label.modulate.a = 0.0
	elif t < 0.25:
		title_label.modulate.a = (t - 0.1) / 0.15
		title_label.modulate = Color(1, 0.85, 0.5, title_label.modulate.a)
	else:
		title_label.modulate.a = 1.0
		title_label.modulate = Color(1, 0.85, 0.5, 1.0)
	
	# 副标题：0.2-0.35秒淡入，之后保持显示
	if t < 0.2:
		subtitle_label.modulate.a = 0.0
	elif t < 0.35:
		subtitle_label.modulate.a = (t - 0.2) / 0.15
	else:
		subtitle_label.modulate.a = 1.0
	
	# 进度条：0.3-0.4秒淡入
	if t < 0.3:
		progress_bar.modulate.a = 0.0
	elif t < 0.4:
		progress_bar.modulate.a = (t - 0.3) / 0.1
	else:
		progress_bar.modulate.a = 1.0
	
	# 进度条逻辑：前2秒穿越时空（0-30%），后5秒生成世界（30-93%）
	if _elapsed < 2.0:
		# 前2秒：穿越时空，进度0-30%
		var phase1_t: float = _elapsed / 2.0
		progress_bar.value = phase1_t * 30.0
		hint_label.text = "正在穿越时空..."
	else:
		# 后5秒：生成世界，进度30-93%
		var phase2_t: float = (_elapsed - 2.0) / 5.0
		progress_bar.value = 30.0 + phase2_t * 63.0
		hint_label.text = "正在生成世界..."
	
	# 提示文字：0.45-0.55秒淡入，之后保持显示
	if t < 0.45:
		hint_label.modulate.a = 0.0
	elif t < 0.55:
		hint_label.modulate.a = (t - 0.45) / 0.1
	else:
		hint_label.modulate.a = 1.0
	
	# 动画结束，进入游戏
	if _elapsed >= _total_duration:
		_started = false
		print("[Cutscene] 过场动画结束，进入游戏...")
		get_tree().change_scene_to_file("res://scenes/main.tscn")
