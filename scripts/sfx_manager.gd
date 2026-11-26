extends Node
class_name SfxManager

const SAMPLE_RATE := 11025
const BGM_PATH := "res://assets/audio/bgm_meadow.wav"
const BGM_PLAY_DB := -11.5
const BGM_IDLE_DB := -16.5

var _bgm_player: AudioStreamPlayer
var _bgm_target_db: float = BGM_IDLE_DB
var _engine_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_cursor := 0
var _streams: Dictionary = {}
var _muted := false
var _initialized := false
var _last_cut_time := 0.0

func _ready() -> void:
	# Defer audio stream creation until first user gesture (important for iOS Safari Web Audio!)
	pass

func _process(delta: float) -> void:
	if _bgm_player != null and _bgm_player.playing:
		_bgm_player.volume_db = lerpf(_bgm_player.volume_db, _bgm_target_db, minf(delta * 4.5, 1.0))

func _ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	_build_streams()

	_bgm_player = AudioStreamPlayer.new()
	var bgm_res: AudioStream = load(BGM_PATH)
	if bgm_res != null:
		_bgm_player.stream = bgm_res
	_bgm_player.volume_db = _bgm_target_db
	add_child(_bgm_player)

	_engine_player = AudioStreamPlayer.new()
	_engine_player.stream = _streams["engine"]
	_engine_player.volume_db = -24.0
	add_child(_engine_player)

	for i in range(6):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_players.append(p)

func start_bgm(is_playing_round: bool = true) -> void:
	_bgm_target_db = BGM_PLAY_DB if is_playing_round else BGM_IDLE_DB
	if _muted:
		return
	_ensure_initialized()
	if _bgm_player != null and _bgm_player.stream != null and not _bgm_player.playing:
		_bgm_player.volume_db = _bgm_target_db
		_bgm_player.play()

func set_bgm_ducked(ducked: bool) -> void:
	_bgm_target_db = BGM_IDLE_DB if ducked else BGM_PLAY_DB

func is_muted() -> bool:
	return _muted

func toggle_mute() -> bool:
	_muted = not _muted
	if _muted:
		if _bgm_player != null and _bgm_player.playing:
			_bgm_player.stop()
		if _engine_player != null and _engine_player.playing:
			_engine_player.stop()
	else:
		_ensure_initialized()
		if _bgm_player != null and _bgm_player.stream != null and not _bgm_player.playing:
			_bgm_player.volume_db = _bgm_target_db
			_bgm_player.play()
	return _muted

func start_engine() -> void:
	if _muted:
		return
	_ensure_initialized()
	if not _engine_player.playing:
		_engine_player.play()

func stop_engine() -> void:
	if _engine_player != null and _engine_player.playing:
		_engine_player.stop()

func update_engine(speed_ratio: float, boosting: bool, active: bool) -> void:
	if _muted or not active:
		if _engine_player != null and _engine_player.playing:
			_engine_player.stop()
		return
	_ensure_initialized()
	if not _engine_player.playing:
		_engine_player.play()
	var target_pitch := 0.78 + clampf(speed_ratio, 0.0, 1.4) * 0.48 + (0.22 if boosting else 0.0)
	_engine_player.pitch_scale = lerpf(_engine_player.pitch_scale, target_pitch, 0.15)
	var target_vol := -25.0 + clampf(speed_ratio, 0.0, 1.0) * 6.5 + (2.5 if boosting else 0.0)
	_engine_player.volume_db = lerpf(_engine_player.volume_db, target_vol, 0.15)

func play_cut(is_special: bool) -> void:
	if _muted:
		return
	var now := Time.get_ticks_msec() * 0.001
	var min_interval := 0.045 if is_special else 0.065
	if now - _last_cut_time < min_interval:
		return
	_last_cut_time = now
	if is_special:
		_play("special_cut", randf_range(0.95, 1.18), -8.0)
	else:
		_play("cut", randf_range(0.88, 1.16), -14.0)

func play_flower() -> void:
	_play("flower", randf_range(0.98, 1.06), -6.0)

func play_rock() -> void:
	_play("rock", randf_range(0.9, 1.08), -7.0)

func play_sheep() -> void:
	_play("sheep", randf_range(0.95, 1.1), -8.0)

func play_dog() -> void:
	_play("dog", randf_range(0.95, 1.12), -8.0)

func play_mud() -> void:
	_play("mud", randf_range(0.9, 1.1), -9.0)

func play_boost() -> void:
	_play("boost", 1.0, -10.0)

func play_tick(urgent: bool = false) -> void:
	_play("tick", 1.25 if urgent else 1.0, -10.0)

func play_finish() -> void:
	_play("finish", 1.0, -6.0)

func play_star(star_idx: int) -> void:
	var pitch := 1.0 + float(star_idx) * 0.18
	_play("star_ding", pitch, -5.5)

func _play(key: String, pitch: float = 1.0, vol_db: float = -8.0) -> void:
	if _muted:
		return
	_ensure_initialized()
	if not _streams.has(key):
		return
	var p := _sfx_players[_sfx_cursor]
	_sfx_cursor = (_sfx_cursor + 1) % _sfx_players.size()
	p.stop()
	p.stream = _streams[key]
	p.pitch_scale = pitch
	p.volume_db = vol_db
	p.play()

func _build_streams() -> void:
	_streams["engine"] = _gen_engine_loop()
	_streams["cut"] = _gen_noise_snip(0.06, 0.35)
	_streams["special_cut"] = _gen_chime([659.25, 880.0], 0.14)
	_streams["flower"] = _gen_chime([523.25, 659.25, 783.99, 1046.5], 0.34)
	_streams["rock"] = _gen_clunk()
	_streams["sheep"] = _gen_bleat()
	_streams["dog"] = _gen_bark()
	_streams["mud"] = _gen_squish()
	_streams["boost"] = _gen_sweep(240.0, 580.0, 0.22)
	_streams["tick"] = _gen_beep(880.0, 0.065)
	_streams["finish"] = _gen_chime([523.25, 659.25, 783.99, 1046.5, 1318.5], 0.55)
	_streams["star_ding"] = _gen_chime([587.33, 880.0, 1174.66], 0.28)

func _make_wav(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in range(samples.size()):
		var v := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		bytes[i * 2] = v & 0xFF
		bytes[i * 2 + 1] = (v >> 8) & 0xFF
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav

func _gen_engine_loop() -> AudioStreamWAV:
	# Seamless 0.25s low mower purr
	var n := int(SAMPLE_RATE * 0.25)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in range(n):
		var t := float(i) / float(SAMPLE_RATE)
		# Frequencies multiples of 4 Hz for seamless 0.25s loop
		var s := sin(TAU * 52.0 * t) * 0.45 + sin(TAU * 104.0 * t) * 0.28 + sin(TAU * 156.0 * t) * 0.14
		var flutter := 0.85 + 0.15 * sin(TAU * 16.0 * t)
		buf[i] = s * flutter * 0.42
	return _make_wav(buf, true)

func _gen_noise_snip(dur: float, amp: float) -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var prev := 0.0
	for i in range(n):
		var env := sin(PI * float(i) / float(n))
		var white := randf_range(-1.0, 1.0)
		var high := white - prev * 0.65
		prev = white
		buf[i] = high * env * amp
	return _make_wav(buf)

func _gen_chime(notes: Array, dur: float) -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var step_len := dur / float(notes.size())
	for i in range(n):
		var t := float(i) / float(SAMPLE_RATE)
		var val := 0.0
		for idx in range(notes.size()):
			var start_t := float(idx) * step_len * 0.75
			if t >= start_t:
				var lt := t - start_t
				var env := exp(-lt * 10.5) * minf(lt * 80.0, 1.0)
				var f: float = notes[idx]
				val += (sin(TAU * f * lt) + 0.35 * sin(TAU * f * 2.0 * lt)) * env * 0.32
		buf[i] = val
	return _make_wav(buf)

func _gen_clunk() -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * 0.20)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in range(n):
		var t := float(i) / float(SAMPLE_RATE)
		var env := exp(-t * 18.0)
		var f := lerpf(190.0, 75.0, minf(t * 7.0, 1.0))
		var metal := sin(TAU * 420.0 * t) * exp(-t * 28.0) * 0.3
		buf[i] = (sin(TAU * f * t) * 0.65 + randf_range(-0.35, 0.35) * exp(-t * 32.0) + metal) * env
	return _make_wav(buf)

func _gen_bleat() -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * 0.32)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var phase := 0.0
	for i in range(n):
		var t := float(i) / float(SAMPLE_RATE)
		var env := sin(PI * float(i) / float(n))
		var vibrato := 1.0 + 0.08 * sin(TAU * 26.0 * t)
		var freq := (340.0 - t * 110.0) * vibrato
		phase += TAU * freq / float(SAMPLE_RATE)
		var s := sin(phase) * 0.55 + sin(phase * 2.0) * 0.25 + sin(phase * 3.0) * 0.12
		buf[i] = s * env * 0.55
	return _make_wav(buf)

func _gen_bark() -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * 0.24)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var phase := 0.0
	for i in range(n):
		var t := float(i) / float(SAMPLE_RATE)
		# Two quick playful yips
		var local_t := fmod(t, 0.12)
		var env := sin(PI * clampf(local_t / 0.10, 0.0, 1.0)) * (1.0 if local_t < 0.10 else 0.0)
		var freq := lerpf(460.0, 220.0, local_t / 0.10)
		phase += TAU * freq / float(SAMPLE_RATE)
		buf[i] = (sin(phase) * 0.6 + sin(phase * 2.0) * 0.25 + randf_range(-0.15, 0.15)) * env * 0.6
	return _make_wav(buf)

func _gen_squish() -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * 0.22)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var phase := 0.0
	for i in range(n):
		var t := float(i) / float(SAMPLE_RATE)
		var env := sin(PI * float(i) / float(n))
		var freq := 140.0 + 180.0 * sin(t * 24.0) * exp(-t * 5.0)
		phase += TAU * maxf(freq, 60.0) / float(SAMPLE_RATE)
		buf[i] = (sin(phase) * 0.55 + randf_range(-0.25, 0.25)) * env * 0.6
	return _make_wav(buf)

func _gen_sweep(f0: float, f1: float, dur: float) -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var phase := 0.0
	for i in range(n):
		var p := float(i) / float(n)
		var env := sin(PI * p)
		var freq := lerpf(f0, f1, p)
		phase += TAU * freq / float(SAMPLE_RATE)
		buf[i] = (sin(phase) * 0.5 + randf_range(-0.2, 0.2)) * env * 0.5
	return _make_wav(buf)

func _gen_beep(freq: float, dur: float) -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in range(n):
		var t := float(i) / float(SAMPLE_RATE)
		var env := exp(-t * 32.0) * minf(t * 150.0, 1.0)
		buf[i] = sin(TAU * freq * t) * env * 0.55
	return _make_wav(buf)
