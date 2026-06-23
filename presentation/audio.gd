extends Node
## Audio manager: music per realm + event-driven SFX, with persisted volumes.
##
## SFX are SYNTHESIZED procedurally at runtime (no audio files needed) so the
## game is fully audible on the Web build out of the box; if the maintainer drops
## a real file at assets/audio/{sfx,music}/<key>.{ogg,wav,mp3} it overrides the
## synth. Each cue is voiced distinctly, and shots/hits/deaths are pitched per
## source (a heavy weapon or a big mob sounds lower) so weapons and mobs read
## apart by ear.
##
## Web note: browsers block audio until a user gesture; the boot screen's first
## tap unlocks it (see boot.gd).

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const EXTS := [".ogg", ".wav", ".mp3"]
const SFX_VOICES := 12
const RATE := 22050

# Logical SFX names. Each maps to a synthesizer in _synth() (or a same-named file).
const SFX_KEYS := ["shoot", "enemy_shoot", "melee", "dash", "hit", "death",
	"hurt", "pickup", "coin", "blessing", "boss", "door", "ui"]

var _music: AudioStreamPlayer
var _voices: Array[AudioStreamPlayer] = []
var _sfx_cache: Dictionary = {}   # key -> AudioStream
var _music_cache: Dictionary = {}
var _music_vol: float = 0.55      # music sits under the SFX so cues cut through
var _sfx_vol: float = 0.9
var _current_music: String = ""
var _last_hp: float = -1.0

# Procedural "voice" for dialogue: a short synth blip, pitched per speaker, played
# as each word is typed. A bespoke voice WAV (assets/audio/sfx/voice.*) overrides it.
var _voice_player: AudioStreamPlayer
var _voice_stream: AudioStream

func _ready() -> void:
	_music = AudioStreamPlayer.new()
	add_child(_music)
	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_voices.append(p)
	# A real file wins; otherwise synthesize the cue so it is never silent.
	for key in SFX_KEYS:
		var s = _find_stream(SFX_DIR, key)
		_sfx_cache[key] = s if s != null else _synth(key)

	_voice_player = AudioStreamPlayer.new()
	add_child(_voice_player)
	var bespoke = _find_stream(SFX_DIR, "voice")
	_voice_stream = bespoke if bespoke != null else _make_voice_blip()

	_connect_events()
	load_volumes()
	play_music("hub")  # silent until a hub track exists; harmless

func _connect_events() -> void:
	Events.entity_damaged.connect(_on_entity_damaged)
	Events.entity_died.connect(_on_entity_died)
	Events.item_picked_up.connect(func(_id): play_sfx("pickup"))
	Events.blessing_chosen.connect(func(_id): play_sfx("blessing"))
	Events.gold_changed.connect(_on_gold)
	Events.player_health_changed.connect(_on_player_hp)
	Events.biome_changed.connect(func(id): play_music(id))
	Events.boss_spawned.connect(func(_e, _k): play_sfx("boss"))
	Events.shot_fired.connect(func(by_p, pitch): play_sfx("shoot" if by_p else "enemy_shoot", pitch))
	Events.melee_swung.connect(func(): play_sfx("melee"))
	Events.player_dashed.connect(func(): play_sfx("dash"))
	Events.run_started.connect(func(_s): _last_hp = -1.0; play_music(RunManager.biome_id))
	Events.run_ended.connect(func(_v): play_music("hub"))

# --- Public API ---
func play_sfx(key: String, pitch: float = 1.0) -> void:
	var stream = _sfx_cache.get(key, null)
	if stream == null or _sfx_vol <= 0.001:
		return
	# A touch of random detune keeps repeated shots/hits from sounding robotic.
	var p: float = clampf(pitch * randf_range(0.96, 1.04), 0.4, 2.4)
	for v in _voices:
		if not v.playing:
			v.stream = stream
			v.pitch_scale = p
			v.volume_db = _to_db(_sfx_vol)
			v.play()
			return

## A short voice blip for the dialogue typewriter, pitched for `speaker` so each
## god sounds distinct (deterministic, no audio files needed). No-op if muted.
func play_voice(speaker: String) -> void:
	if _voice_stream == null or _voice_player == null or _sfx_vol <= 0.001:
		return
	_voice_player.stream = _voice_stream
	_voice_player.pitch_scale = voice_pitch(speaker)
	_voice_player.volume_db = _to_db(_sfx_vol * 0.45)  # softer than gameplay SFX
	_voice_player.play()

## A stable pitch per speaker: the Ferryman is low and grave, gods are spread
## across a tuneful range by a hash of their id (so each has its own timbre).
func voice_pitch(speaker: String) -> float:
	if speaker == "narrator":
		return 0.72
	if speaker == "shade":
		return 0.95
	var semis := [-5, -3, -2, 0, 2, 3, 5, 7]
	var st: int = semis[absi(hash(speaker)) % semis.size()]
	return pow(2.0, float(st) / 12.0)

func play_music(id: String) -> void:
	if id == _current_music:
		return
	_current_music = id
	var stream = _music_cache.get(id, null)
	if not _music_cache.has(id):
		stream = _find_stream(MUSIC_DIR, id)
		_music_cache[id] = stream
	if stream == null:
		_music.stop()
		return
	# Seamless looping. WAV uses loop_mode (no `.loop`); Ogg uses `.loop`.
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = stream.data.size() / 2  # 16-bit mono -> 2 bytes/frame
	elif stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = true
	_music.stream = stream
	_music.volume_db = _to_db(_music_vol)
	_music.play()

# --- Volume settings (persisted in SaveManager.meta.options) ---
func load_volumes() -> void:
	var o: Dictionary = SaveManager.meta.get("options", {})
	_music_vol = float(o.get("music", 0.55))
	_sfx_vol = float(o.get("sfx", 0.9))
	_music.volume_db = _to_db(_music_vol)

func set_music_volume(v: float) -> void:
	_music_vol = clampf(v, 0.0, 1.0)
	_music.volume_db = _to_db(_music_vol)
	_save()

func set_sfx_volume(v: float) -> void:
	_sfx_vol = clampf(v, 0.0, 1.0)
	_save()
	play_sfx("ui")  # audible feedback while dragging the slider

func music_volume() -> float:
	return _music_vol

func sfx_volume() -> float:
	return _sfx_vol

# --- Combat audio ---
func _on_entity_damaged(target, _amount: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	if target.is_in_group("player"):
		return  # the player's feedback is the "hurt" cue (see _on_player_hp)
	play_sfx("hit", _entity_pitch(target))

func _on_entity_died(entity) -> void:
	if entity == null or not is_instance_valid(entity):
		return
	if entity.is_in_group("player"):
		play_sfx("death", 0.8)
	else:
		play_sfx("death", _entity_pitch(entity))

## Bigger / tougher entities sound lower, so a brute and a swarm read apart.
func _entity_pitch(e) -> float:
	var h = e.get("health")
	var mh: float = h.max_health if h != null else 4.0
	return clampf(1.35 - mh * 0.012, 0.72, 1.35)

func _on_gold(_total: int) -> void:
	play_sfx("coin")

func _on_player_hp(current: float, _maximum: float) -> void:
	if _last_hp >= 0.0 and current < _last_hp:
		play_sfx("hurt")
	_last_hp = current

# --- Procedural synthesis ---
## Build the cue for a logical SFX key. Returns a 16-bit mono WAV; pitch is set
## per-play, so one stream serves every variation of a sound.
func _synth(key: String) -> AudioStreamWAV:
	var b: PackedFloat32Array
	match key:
		"shoot":  # bright player "pew", descending
			b = _buf(0.13)
			_tone(b, 0.0, 900.0, 320.0, 0.12, 0.45, "square", 26.0, 0.06)
			_tone(b, 0.0, 1500.0, 600.0, 0.05, 0.18, "sine", 42.0)
		"enemy_shoot":  # darker, lower enemy pulse
			b = _buf(0.18)
			_tone(b, 0.0, 360.0, 150.0, 0.16, 0.5, "saw", 16.0, 0.05)
		"melee":  # an air "whoosh" (filtered noise sweep)
			b = _buf(0.16)
			_tone(b, 0.0, 720.0, 200.0, 0.14, 0.4, "sine", 16.0, 0.85)
		"dash":  # quick upward whoosh
			b = _buf(0.18)
			_tone(b, 0.0, 280.0, 820.0, 0.16, 0.35, "sine", 12.0, 0.4)
		"hit":  # punchy thwack: low body + noise transient
			b = _buf(0.12)
			_tone(b, 0.0, 220.0, 80.0, 0.10, 0.5, "square", 34.0)
			_tone(b, 0.0, 900.0, 300.0, 0.05, 0.35, "sine", 50.0, 1.0)
		"hurt":  # harsher, alarming player damage
			b = _buf(0.22)
			_tone(b, 0.0, 320.0, 110.0, 0.20, 0.5, "saw", 14.0, 0.35)
			_tone(b, 0.0, 200.0, 90.0, 0.12, 0.3, "square", 22.0)
		"death":  # downward sweep + noise tail
			b = _buf(0.38)
			_tone(b, 0.0, 420.0, 60.0, 0.36, 0.5, "saw", 6.0)
			_tone(b, 0.0, 300.0, 70.0, 0.30, 0.28, "sine", 5.0, 0.6)
		"pickup":  # two-note rise
			b = _buf(0.20)
			_tone(b, 0.0, 660.0, 660.0, 0.10, 0.4, "sine", 18.0)
			_tone(b, 0.06, 990.0, 990.0, 0.12, 0.4, "sine", 16.0)
		"coin":  # bright two-tone ding
			b = _buf(0.24)
			_tone(b, 0.0, 988.0, 988.0, 0.08, 0.4, "square", 16.0)
			_tone(b, 0.05, 1319.0, 1319.0, 0.16, 0.36, "square", 12.0)
		"blessing":  # shimmering C-E-G-C arpeggio
			b = _buf(0.7)
			_tone(b, 0.0, 523.0, 523.0, 0.50, 0.26, "sine", 4.0)
			_tone(b, 0.10, 659.0, 659.0, 0.45, 0.24, "sine", 4.0)
			_tone(b, 0.20, 784.0, 784.0, 0.45, 0.24, "sine", 4.0)
			_tone(b, 0.30, 1047.0, 1047.0, 0.40, 0.22, "sine", 3.5)
		"boss":  # ominous low swell
			b = _buf(0.8)
			_tone(b, 0.0, 70.0, 110.0, 0.80, 0.5, "saw", 2.2)
			_tone(b, 0.0, 140.0, 165.0, 0.70, 0.25, "sine", 2.5)
			_tone(b, 0.0, 60.0, 60.0, 0.60, 0.2, "sine", 1.5, 0.5)
		"door":  # heavy stone slide
			b = _buf(0.26)
			_tone(b, 0.0, 220.0, 110.0, 0.24, 0.4, "saw", 8.0, 0.85)
			_tone(b, 0.0, 90.0, 70.0, 0.20, 0.3, "sine", 6.0)
		"ui":  # soft click
			b = _buf(0.06)
			_tone(b, 0.0, 1200.0, 900.0, 0.05, 0.35, "square", 45.0)
		_:
			b = _buf(0.08)
			_tone(b, 0.0, 600.0, 400.0, 0.07, 0.3, "sine", 30.0)
	return _render(b)

func _buf(dur: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(dur * RATE))
	return b

## Mix a pitch-swept tone into `buf` starting at `start` seconds, with an
## exponential decay envelope and an optional noise blend.
func _tone(buf: PackedFloat32Array, start: float, f0: float, f1: float, dur: float,
		amp: float, wave: String = "sine", decay: float = 8.0, noise_mix: float = 0.0) -> void:
	var s0: int = int(start * RATE)
	var frames: int = int(dur * RATE)
	var phase := 0.0
	for i in frames:
		var idx: int = s0 + i
		if idx < 0 or idx >= buf.size():
			continue
		var u: float = float(i) / float(maxi(1, frames))
		var f: float = lerpf(f0, f1, u)
		phase += TAU * f / float(RATE)
		var w := 0.0
		match wave:
			"square": w = 1.0 if sin(phase) >= 0.0 else -1.0
			"saw": w = fposmod(phase, TAU) / PI - 1.0
			"tri": w = absf(fposmod(phase, TAU) / PI - 1.0) * 2.0 - 1.0
			_: w = sin(phase)
		if noise_mix > 0.0:
			w = lerpf(w, randf() * 2.0 - 1.0, noise_mix)
		var t: float = float(i) / float(RATE)
		var env: float = exp(-t * decay)
		var atk: float = clampf(t / 0.003, 0.0, 1.0)  # tiny attack to avoid clicks
		buf[idx] += w * amp * env * atk

func _render(buf: PackedFloat32Array) -> AudioStreamWAV:
	var n := buf.size()
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		var s: int = int(clampf(buf[i], -1.0, 1.0) * 30000.0)
		bytes[i * 2] = s & 0xFF
		bytes[i * 2 + 1] = (s >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	return wav

## A ~55ms decaying two-tone blip for dialogue (pitched per speaker at play time).
func _make_voice_blip() -> AudioStreamWAV:
	var frames := int(0.055 * RATE)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	var f0 := 330.0
	for i in frames:
		var t := float(i) / float(RATE)
		var env: float = exp(-t * 42.0)
		var w := sin(TAU * f0 * t) * 0.7 + sin(TAU * f0 * 2.0 * t) * 0.3
		var s: int = int(clampf(w * env, -1.0, 1.0) * 14000.0)
		bytes[i * 2] = s & 0xFF
		bytes[i * 2 + 1] = (s >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	return wav

# --- Internals ---
func _to_db(linear: float) -> float:
	return -80.0 if linear <= 0.001 else linear_to_db(linear)

func _save() -> void:
	if not SaveManager.meta.has("options"):
		SaveManager.meta["options"] = {}
	SaveManager.meta["options"]["music"] = _music_vol
	SaveManager.meta["options"]["sfx"] = _sfx_vol
	SaveManager.save_meta()

func _find_stream(dir: String, key: String):
	for ext in EXTS:
		var path: String = dir + key + ext
		if ResourceLoader.exists(path):
			return load(path)
	return null
