extends Node
## Picks and shows dialogue, EVOLVING via meeting count / story stage / flags
## (Hades-style). State lives in SaveManager. Requests are queued so several lines
## (e.g. narrator then the realm's god) play one after another, never stacked.

signal queue_empty

var _pending := ""        # "death"/"victory" to show at the hub
var _active := false
var _queue: Array = []    # DialogueData waiting to show

func _ready() -> void:
	Events.blessing_chosen.connect(_on_blessing_chosen)
	Events.run_ended.connect(func(victory): _pending = "victory" if victory else "death")

## Called by the hub on entry: death/victory beat if a run just ended, else an
## ambient line from the Ferryman or a fellow shade.
func on_enter_hub() -> void:
	var spoke := false
	if _pending != "":
		var t := _pending
		_pending = ""
		spoke = speak("narrator", t)
	# The true ending: all six realms conquered, shown once.
	if SaveManager.has_flag("all_six") and not SaveManager.line_seen("narr_ending"):
		if speak("narrator", "ending"):
			return
	# A story-reveal beat for the current stage (each shown once) — the slow
	# unveiling of why the soul is bound. Queues after a victory line if present.
	if speak("narrator", "reveal"):
		return
	if spoke:
		return
	var who := "shade" if randf() < 0.4 else "narrator"
	if not speak(who, "hub"):
		speak("narrator", "hub")

## Queue the best matching line for (speaker, trigger). Returns true if one was
## found (and will be shown when its turn comes).
func speak(speaker: String, trigger: String) -> bool:
	var pick = _select(speaker, trigger)
	if pick == null:
		return false
	_queue.append(pick)
	_pump()
	return true

func _select(speaker: String, trigger: String):
	var cands: Array = []
	for d in GameData.dialogues.values():
		if d.speaker == speaker and d.trigger == trigger and _ok(d):
			cands.append(d)
	if cands.is_empty():
		return null
	var best := -1
	for d in cands:
		best = maxi(best, d.min_meet)
	return _weighted(cands.filter(func(d): return d.min_meet == best))

func _ok(d) -> bool:
	var m := SaveManager.meetings(d.speaker)
	if m < d.min_meet:
		return false
	if d.max_meet >= 0 and m > d.max_meet:
		return false
	var st := SaveManager.story_stage()
	if st < d.min_stage or (d.max_stage >= 0 and st > d.max_stage):
		return false
	for f in d.requires_flags:
		if not SaveManager.has_flag(f):
			return false
	if d.once and SaveManager.line_seen(d.id):
		return false
	return true

func _weighted(arr: Array):
	var total := 0.0
	for d in arr:
		total += d.weight
	var r := randf() * total
	var acc := 0.0
	for d in arr:
		acc += d.weight
		if r <= acc:
			return d
	return arr[0]

func _pump() -> void:
	if _active or _queue.is_empty():
		return
	var d = _queue.pop_front()
	_active = true
	SaveManager.meet(d.speaker)
	if d.once:
		SaveManager.mark_line_seen(d.id)
	for f in d.set_flags:
		SaveManager.set_flag(f)
	var box := DialogueBox.new()
	box.setup(_speaker_name(d.speaker), Sprites.portrait(d.speaker), d.lines, d.modal, d.speaker)
	box.finished.connect(_on_finished, CONNECT_ONE_SHOT)
	var host := get_tree().current_scene
	if host != null:
		host.add_child(box)
	else:
		_on_finished()

func _on_finished() -> void:
	_active = false
	if _queue.is_empty():
		queue_empty.emit()
	else:
		_pump()

func _speaker_name(speaker: String) -> String:
	if speaker == "narrator":
		return Loc.t("speaker.narrator")
	if speaker == "shade":
		return Loc.t("speaker.shade")
	if speaker == "hell_cthulhu":
		return "Cthulhu"
	var dd = GameData.deities.get(speaker, null)
	return Loc.t(dd.name_key) if dd != null else speaker

func _on_blessing_chosen(blessing_id: String) -> void:
	var b = GameData.blessings.get(blessing_id, null)
	if b == null or b.deity_id == "":
		return
	var rival := RunManager.owned_rival_of(b.deity_id)
	if rival != "" and speak(rival, "rival"):
		return
	speak(b.deity_id, "boon")
