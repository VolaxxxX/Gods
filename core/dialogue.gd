extends Node
## Picks and shows dialogue. Lines EVOLVE: selection is gated by how many times
## you've met the speaker, the story stage, and flags (Hades-style). State lives
## in SaveManager. A boon line plays automatically when a blessing is chosen.

func _ready() -> void:
	Events.blessing_chosen.connect(_on_blessing_chosen)

## Speak the best-matching line for (speaker, trigger). Returns true if something
## was shown. `speaker` is a deity id or "narrator".
func speak(speaker: String, trigger: String) -> bool:
	var cands: Array = []
	for d in GameData.dialogues.values():
		if d.speaker == speaker and d.trigger == trigger and _ok(d):
			cands.append(d)
	if cands.is_empty():
		return false
	# Prefer the most advanced unlocked variant (highest min_meet), then weighted.
	var best := -1
	for d in cands:
		best = maxi(best, d.min_meet)
	var top: Array = cands.filter(func(d): return d.min_meet == best)
	_present(_weighted(top))
	return true

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

func _present(d) -> void:
	SaveManager.meet(d.speaker)
	if d.once:
		SaveManager.mark_line_seen(d.id)
	for f in d.set_flags:
		SaveManager.set_flag(f)
	var box := DialogueBox.new()
	box.setup(_speaker_name(d.speaker), Sprites.portrait(d.speaker), d.lines, d.modal)
	var host := get_tree().current_scene
	if host != null:
		host.add_child(box)

func _speaker_name(speaker: String) -> String:
	if speaker == "narrator":
		return Loc.t("speaker.narrator")
	var dd = GameData.deities.get(speaker, null)
	return Loc.t(dd.name_key) if dd != null else speaker

func _on_blessing_chosen(blessing_id: String) -> void:
	var b = GameData.blessings.get(blessing_id, null)
	if b != null and b.deity_id != "":
		speak(b.deity_id, "boon")
