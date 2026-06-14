extends Node
## Sprite resolver: loads textures by naming convention and caches them. Accepts
## .png AND .svg (Godot rasterizes SVG on import), so vector art works too.
## Returns null when a file is absent → greybox fallback. Drop a file with the
## right name and it appears, no code/JSON changes (see ASSETS.md / the guide).
##
## Conventions (under res://assets/sprites/), .png or .svg:
##   entities/<entity_id>      e.g. greece_shade, bali_rangda
##   entities/enemy            generic monster (tinted by enemy colour)
##   entities/player[_<char>]  player (per-class override optional)
##   tiles/<pantheon>_<kind>   kind = floor|wall|obstacle (used as-is)
##   tiles/<kind>              generic tile (tinted per realm palette)
##   fx/projectile_player | projectile_enemy | projectile

const ENT := "res://assets/sprites/entities/"
const TILES := "res://assets/sprites/tiles/"
const FX := "res://assets/sprites/fx/"
const EXTS := [".png", ".svg"]

var _cache: Dictionary = {}

## Resolve `dir + name + (ext)` trying each extension; cache the result (or null).
func _resolve(dir: String, name: String) -> Texture2D:
	var key := dir + name
	if _cache.has(key):
		return _cache[key]
	var tex: Texture2D = null
	for ext in EXTS:
		var path := key + ext
		if ResourceLoader.exists(path):
			tex = load(path)
			break
	_cache[key] = tex
	return tex

func entity(id: String) -> Texture2D:
	return _resolve(ENT, id)

func entity_generic() -> Texture2D:
	return _resolve(ENT, "enemy")

func player(character_id: String) -> Texture2D:
	var t := _resolve(ENT, "player_" + character_id)
	return t if t != null else _resolve(ENT, "player")

## kind: "floor" | "wall" | "obstacle"
func tile(pantheon: String, kind: String) -> Texture2D:
	return _resolve(TILES, pantheon + "_" + kind)

func tile_generic(kind: String) -> Texture2D:
	return _resolve(TILES, kind)

func fx(name: String) -> Texture2D:
	var t := _resolve(FX, name)
	return t if t != null else _resolve(FX, "projectile")
