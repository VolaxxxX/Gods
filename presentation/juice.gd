extends Node
## "Juice" layer: screenshake (trauma-based), brief hit-stop, and death pops.
## Listens on the Events bus so it never couples to gameplay objects. This is
## what gives the Isaac/Hades-style impact feel. Web-safe (no native deps).

const SHAKE_MAX := 14.0       # px at full trauma
const TRAUMA_DECAY := 1.8     # per second

var _trauma: float = 0.0
var _last_hp: float = -1.0

func _ready() -> void:
	Events.entity_died.connect(_on_death)
	Events.player_health_changed.connect(_on_player_hp)
	Events.run_started.connect(func(_seed): _last_hp = -1.0)

func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	if _trauma > 0.0:
		var amt := _trauma * _trauma
		cam.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * SHAKE_MAX * amt
		_trauma = maxf(0.0, _trauma - delta * TRAUMA_DECAY)
	elif cam.offset != Vector2.ZERO:
		cam.offset = Vector2.ZERO

func add_trauma(amount: float) -> void:
	_trauma = minf(1.0, _trauma + amount)

func _on_player_hp(current: float, _maximum: float) -> void:
	if _last_hp >= 0.0 and current < _last_hp:
		add_trauma(0.5)
		_hitstop(0.05)
	_last_hp = current

func _on_death(entity) -> void:
	add_trauma(0.3)
	_hitstop(0.03)
	_spawn_pop(entity)

func _spawn_pop(entity) -> void:
	if entity == null or not is_instance_valid(entity) or not (entity is Node2D):
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var pop := DeathPop.new()
	scene.add_child(pop)
	pop.z_index = 15  # above the room floor
	var c := Color(1, 0.6, 0.3)
	if "_color" in entity:
		c = entity._color
	pop.start(entity.global_position, c)

func _hitstop(duration: float) -> void:
	Engine.time_scale = 0.05
	# Real-time timer (ignore_time_scale) so the freeze actually ends.
	var t := get_tree().create_timer(duration, true, false, true)
	await t.timeout
	Engine.time_scale = 1.0
