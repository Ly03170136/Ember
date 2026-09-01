extends Node
## 音频管理器：统一管理音效和背景音乐播放

# 音效类型
enum SFX {
	UI_CLICK,      # UI点击
	UI_HOVER,      # UI悬停
	UI_OPEN,       # 打开菜单
	UI_CLOSE,      # 关闭菜单
	ATTACK,        # 攻击
	HIT,           # 命中
	GATHER,        # 采集
	BUILD,         # 建造
	PLAYER_HURT,   # 玩家受伤
	ZOMBIE_HIT,    # 僵尸受击
	ZOMBIE_DEATH,  # 僵尸死亡
	ITEM_PICKUP,   # 拾取物品
	DAY,           # 白天到来
	NIGHT,         # 夜晚到来
	ERROR,         # 错误提示
	SUCCESS        # 成功提示
}

var _sfx_players: Array = []
var _music_player: AudioStreamPlayer = null
var _current_music: String = ""
var _music_tween: Tween = null

# 音乐资源路径配置（名称 -> 路径）
const MUSIC_PATHS := {
	"main_menu": "res://assets/audio/bgm/main_menu.ogg",
	"game_day": "res://assets/audio/bgm/game_day.ogg",
	"game_night": "res://assets/audio/bgm/game_night.ogg",
	"base": "res://assets/audio/bgm/base.ogg",
	"combat": "res://assets/audio/bgm/combat.ogg",
}

# 音量设置
var master_volume: float = 0.8
var music_volume: float = 0.6
var sfx_volume: float = 0.8

const MAX_SFX_PLAYERS := 16
const MUSIC_FADE_DURATION := 1.5  # 音乐淡入淡出时长（秒）


func _ready() -> void:
	# 创建背景音乐播放器
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)
	# 创建音效播放器池
	for i in range(MAX_SFX_PLAYERS):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_sfx_players.append(player)
	# 应用初始音量
	_apply_volumes()
	print("[AudioManager] 音频系统初始化完成，%d个音效播放器" % _sfx_players.size())


func play_sfx(sfx_type: int, pitch: float = 1.0) -> void:
	# 查找空闲的播放器
	var player: AudioStreamPlayer = _get_free_sfx_player()
	if not player:
		return
	# 生成音效流
	var stream: AudioStream = _generate_sfx(sfx_type)
	if not stream:
		return
	player.stream = stream
	player.pitch_scale = pitch
	player.volume_db = linear_to_db(sfx_volume * master_volume)
	player.play()


func play_music(music_name: String, fade: bool = true) -> void:
	## 播放背景音乐（自动循环，支持淡入淡出切换）
	print("[AudioManager] play_music 被调用: ", music_name, " _music_player=", _music_player)
	if _current_music == music_name:
		print("[AudioManager] 同一首音乐，跳过")
		return
	# 检查资源路径是否配置
	if not MUSIC_PATHS.has(music_name):
		print("[AudioManager] 警告：未配置音乐资源: ", music_name)
		return
	var music_path: String = MUSIC_PATHS[music_name]
	print("[AudioManager] 音乐路径: ", music_path, " 文件存在=", ResourceLoader.exists(music_path))
	# 加载音乐文件
	var stream: AudioStream = load(music_path)
	print("[AudioManager] 加载结果: stream=", stream, " 类型=", typeof(stream))
	if stream == null:
		print("[AudioManager] 警告：无法加载音乐文件: ", music_path)
		return
	# 设置循环（不判断具体类型，检查是否有loop属性，兼容OGG/MP3等）
	if stream and stream.get("loop") != null:
		stream.loop = true
		if stream.get("loop_offset") != null:
			stream.loop_offset = 0.0
		print("[AudioManager] 循环已设置, loop=", stream.loop)
	else:
		print("[AudioManager] 警告：stream没有loop属性, get(loop)=", stream.get("loop"))
	_current_music = music_name
	# 淡入淡出切换
	if fade and _music_player.playing:
		print("[AudioManager] 淡入淡出切换")
		_fade_out_and_play(stream)
	else:
		print("[AudioManager] 直接播放, music_volume=", music_volume, " master_volume=", master_volume, " 计算音量=", linear_to_db(music_volume * master_volume))
		_music_player.stream = stream
		_music_player.volume_db = linear_to_db(music_volume * master_volume)
		_music_player.play()
		print("[AudioManager] 播放音乐: ", music_name, " playing=", _music_player.playing)


func stop_music(fade: bool = true) -> void:
	## 停止背景音乐（支持淡出）
	if not _music_player or not _music_player.playing:
		_current_music = ""
		return
	if fade:
		_fade_out_only()
	else:
		_music_player.stop()
		_current_music = ""


func _fade_out_and_play(new_stream: AudioStream) -> void:
	## 淡出当前音乐，然后淡入新音乐
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(_music_player, "volume_db", -80.0, MUSIC_FADE_DURATION)
	_music_tween.tween_callback(func():
		_music_player.stream = new_stream
		_music_player.play()
		_music_tween = create_tween()
		_music_tween.tween_property(_music_player, "volume_db", linear_to_db(music_volume * master_volume), MUSIC_FADE_DURATION)
	)


func _fade_out_only() -> void:
	## 仅淡出当前音乐
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(_music_player, "volume_db", -80.0, MUSIC_FADE_DURATION)
	_music_tween.tween_callback(func():
		_music_player.stop()
		_current_music = ""
	)


func set_master_volume(value: float) -> void:
	master_volume = clamp(value, 0.0, 1.0)
	_apply_volumes()


func set_music_volume(value: float) -> void:
	music_volume = clamp(value, 0.0, 1.0)
	_apply_volumes()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clamp(value, 0.0, 1.0)
	_apply_volumes()


func _apply_volumes() -> void:
	# 应用到AudioServer总线
	if AudioServer.bus_count > 0:
		AudioServer.set_bus_volume_db(0, linear_to_db(master_volume))
	# 实时更新正在播放的音乐音量
	if _music_player and _music_player.playing:
		var target_db: float = linear_to_db(music_volume * master_volume)
		if _music_tween and _music_tween.is_valid():
			_music_tween.kill()
		_music_player.volume_db = target_db
	# 音乐和音效总线在项目设置里配置，这里先预留
	print("[AudioManager] 音量已更新: 主音量=%.2f, 音乐=%.2f, 音效=%.2f" % [master_volume, music_volume, sfx_volume])


func _get_free_sfx_player() -> AudioStreamPlayer:
	for player in _sfx_players:
		if not player.playing:
			return player
	# 所有播放器都在使用，返回第一个（会打断正在播放的音效）
	return _sfx_players[0]


func _generate_sfx(sfx_type: int) -> AudioStream:
	# 用程序生成简单的音效
	match sfx_type:
		SFX.UI_CLICK:
			return _make_tone(800.0, 0.05, 0.3)
		SFX.UI_HOVER:
			return _make_tone(600.0, 0.03, 0.15)
		SFX.UI_OPEN:
			return _make_sweep(400.0, 800.0, 0.1, 0.25)
		SFX.UI_CLOSE:
			return _make_sweep(800.0, 400.0, 0.1, 0.25)
		SFX.ATTACK:
			return _make_noise(0.1, 0.4)
		SFX.HIT:
			return _make_tone(200.0, 0.08, 0.5)
		SFX.GATHER:
			return _make_tone(500.0, 0.06, 0.25)
		SFX.BUILD:
			return _make_tone(300.0, 0.15, 0.35)
		SFX.PLAYER_HURT:
			return _make_tone(150.0, 0.2, 0.6)
		SFX.ZOMBIE_HIT:
			return _make_noise(0.08, 0.3)
		SFX.ZOMBIE_DEATH:
			return _make_sweep(300.0, 50.0, 0.3, 0.4)
		SFX.ITEM_PICKUP:
			return _make_sweep(600.0, 1200.0, 0.08, 0.3)
		SFX.DAY:
			return _make_sweep(300.0, 600.0, 0.5, 0.2)
		SFX.NIGHT:
			return _make_sweep(600.0, 200.0, 0.5, 0.2)
		SFX.ERROR:
			return _make_tone(150.0, 0.15, 0.4)
		SFX.SUCCESS:
			return _make_sweep(500.0, 1000.0, 0.15, 0.3)
		_:
			return null


func _make_tone(freq: float, duration: float, volume: float) -> AudioStreamWAV:
	# 生成简单的正弦波音效
	var sample_rate: int = 22050
	var sample_count: int = int(sample_rate * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)  # 16-bit mono
	for i in range(sample_count):
		var t: float = float(i) / sample_rate
		# 简单的ADSR包络
		var envelope: float = 1.0
		var attack: float = 0.01
		var release: float = duration * 0.3
		if t < attack:
			envelope = t / attack
		elif t > duration - release:
			envelope = (duration - t) / release
		var sample: float = sin(2.0 * PI * freq * t) * volume * envelope
		var sample_int: int = int(sample * 32767.0)
		data[i * 2] = sample_int & 0xFF
		data[i * 2 + 1] = (sample_int >> 8) & 0xFF
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream


func _make_sweep(start_freq: float, end_freq: float, duration: float, volume: float) -> AudioStreamWAV:
	# 生成扫频音效
	var sample_rate: int = 22050
	var sample_count: int = int(sample_rate * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	var phase: float = 0.0
	for i in range(sample_count):
		var t: float = float(i) / sample_rate
		var freq: float = start_freq + (end_freq - start_freq) * (t / duration)
		phase += 2.0 * PI * freq / sample_rate
		# 包络
		var envelope: float = 1.0
		var attack: float = 0.01
		var release: float = duration * 0.3
		if t < attack:
			envelope = t / attack
		elif t > duration - release:
			envelope = (duration - t) / release
		var sample: float = sin(phase) * volume * envelope
		var sample_int: int = int(sample * 32767.0)
		data[i * 2] = sample_int & 0xFF
		data[i * 2 + 1] = (sample_int >> 8) & 0xFF
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream


func _make_noise(duration: float, volume: float) -> AudioStreamWAV:
	# 生成噪声音效
	var sample_rate: int = 22050
	var sample_count: int = int(sample_rate * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for i in range(sample_count):
		var t: float = float(i) / sample_rate
		# 包络
		var envelope: float = 1.0
		var attack: float = 0.005
		var release: float = duration * 0.5
		if t < attack:
			envelope = t / attack
		elif t > duration - release:
			envelope = (duration - t) / release
		var sample: float = rng.randf_range(-1.0, 1.0) * volume * envelope
		var sample_int: int = int(sample * 32767.0)
		data[i * 2] = sample_int & 0xFF
		data[i * 2 + 1] = (sample_int >> 8) & 0xFF
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream
