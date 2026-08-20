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

# 音量设置
var master_volume: float = 0.8
var music_volume: float = 0.6
var sfx_volume: float = 0.8

const MAX_SFX_PLAYERS := 16


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


func play_music(music_name: String) -> void:
	if _current_music == music_name:
		return
	_current_music = music_name
	# 目前没有音乐资源，先预留接口
	print("[AudioManager] 播放音乐: %s (暂无资源)" % music_name)


func stop_music() -> void:
	if _music_player:
		_music_player.stop()
	_current_music = ""


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
