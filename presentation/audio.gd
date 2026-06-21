extends Node
## Audio manager: music per realm + event-driven SFX, with persisted volumes.
## Asset-agnostic: it looks for files under assets/audio/ and plays them if
## present, staying silent otherwise — so the wiring is done now and sounds
## "just work" once the maintainer drops the files in (see ASSETS.md).
##
## Web note: browsers block audio until a user gesture; the boot screen's first
## tap unlocks it (see boot.gd).

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const EXTS := [".ogg", ".wav", ".mp3"]
const SFX_VOICES := 8

# Logical SFX names mapped from gameplay events.
const SFX_KEYS := ["shoot", "hit", "death", "hurt", "pickup", "coin",
	"blessing", "boss", "door", "ui"]

var _music: AudioStreamPlayer
var _voices: Array[AudioStreamPlayer] = []
var _sfx_cache: Dictionary = {}   # key -> AudioStream (or null if missing)
var _music_cache: Dictionary = {}
var _music_vol: float = 0.8
var _sfx_vol: float = 0.9
var _current_music: String = ""
var _last_hp: float = -1.0

func _ready() -> void:
	_music = AudioStreamPlayer.new()
	add_child(_music)
	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_voices.append(p)
	for key in SFX_KEYS:
		_sfx_cache[key] = _find_stream(SFX_DIR, key)

	_connect_events()
	load_volumes()
	play_music("hub")  # silent until a hub track exists; harmless

func _connect_events() -> void:
	Events.entity_died.connect(_on_entity_died)
	Events.item_picked_up.connect(func(_id): play_sfx("pickup"))
	Events.blessing_chosen.connect(func(_id): play_sfx("blessing"))
	Events.gold_changed.connect(_on_gold)
	Events.player_health_changed.connect(_on_player_hp)
	Events.biome_changed.connect(func(id): play_music(id))
	Events.run_started.connect(func(_s): _last_hp = -1.0; play_music(RunManager.biome_id))
	Events.run_ended.connect(func(_v): play_music("hub"))

# --- Public API ---
func play_sfx(key: String) -> void:
	var stream = _sfx_cache.get(key, null)
	if stream == null:
		return
	for v in _voices:
		if not v.playing:
			v.stream = stream
			v.volume_db = _to_db(_sfx_vol)
			v.play()
			return

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
	if stream is AudioStreamOggVorbis or stream is AudioStreamWAV:
		stream.loop = true
	_music.stream = stream
	_music.volume_db = _to_db(_music_vol)
	_music.play()

# --- Volume settings (persisted in SaveManager.meta.options) ---
func load_volumes() -> void:
	var o: Dictionary = SaveManager.meta.get("options", {})
	_music_vol = float(o.get("music", 0.8))
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

# --- Internals ---
func _on_entity_died(entity) -> void:
	if entity != null and is_instance_valid(entity) and entity.is_in_group("player"):
		play_sfx("death")
	else:
		play_sfx("hit")

func _on_gold(_total: int) -> void:
	play_sfx("coin")

func _on_player_hp(current: float, _maximum: float) -> void:
	if _last_hp >= 0.0 and current < _last_hp:
		play_sfx("hurt")
	_last_hp = current

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
