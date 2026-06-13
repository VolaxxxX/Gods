extends Node
## Centralized, seeded, deterministic random number generator.
##
## All gameplay randomness MUST go through here so runs are reproducible from a
## single seed (daily challenges, seed sharing). Uses named "streams" so that
## consuming randomness in one system (e.g. loot) does not desync another
## (e.g. floor layout). Each stream is an independent RandomNumberGenerator
## derived deterministically from the master seed + a hash of its name.

var _master_seed: int = 0
var _streams: Dictionary = {}  # name -> RandomNumberGenerator

func _ready() -> void:
	# Default to a random seed until a run explicitly sets one.
	seed_from_int(randi())

## Set the master seed for the whole session/run. Resets all streams.
func seed_from_int(value: int) -> void:
	_master_seed = value
	_streams.clear()

## Derive a master seed from a human-typed string (for seed sharing UI).
func seed_from_string(text: String) -> void:
	seed_from_int(int(hash(text)))

func get_seed() -> int:
	return _master_seed

## Get (or lazily create) a named, deterministic stream.
func stream(stream_name: String) -> RandomNumberGenerator:
	if _streams.has(stream_name):
		return _streams[stream_name]
	var rng := RandomNumberGenerator.new()
	# Combine master seed and stream name so streams are independent yet
	# fully determined by the master seed.
	rng.seed = _master_seed ^ int(hash(stream_name))
	_streams[stream_name] = rng
	return rng

# --- Convenience wrappers (default stream "general") ---

func randi_range_in(stream_name: String, from: int, to: int) -> int:
	return stream(stream_name).randi_range(from, to)

func randf_in(stream_name: String) -> float:
	return stream(stream_name).randf()

func randf_range_in(stream_name: String, from: float, to: float) -> float:
	return stream(stream_name).randf_range(from, to)

## Pick one element from an array using a named stream. Returns null if empty.
func pick(stream_name: String, array: Array):
	if array.is_empty():
		return null
	return array[stream(stream_name).randi_range(0, array.size() - 1)]

## Weighted pick. `weights[i]` corresponds to `array[i]`. Returns null if empty.
func pick_weighted(stream_name: String, array: Array, weights: Array) -> Variant:
	if array.is_empty():
		return null
	var total: float = 0.0
	for w in weights:
		total += float(w)
	if total <= 0.0:
		return pick(stream_name, array)
	var roll: float = stream(stream_name).randf() * total
	var acc: float = 0.0
	for i in array.size():
		acc += float(weights[i])
		if roll <= acc:
			return array[i]
	return array[array.size() - 1]

## Fisher-Yates shuffle in place using a named stream (deterministic).
func shuffle(stream_name: String, array: Array) -> void:
	var rng := stream(stream_name)
	for i in range(array.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = array[i]
		array[i] = array[j]
		array[j] = tmp
