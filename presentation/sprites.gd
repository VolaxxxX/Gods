extends Node
## Sprite resolver: loads textures by naming convention and caches them. Returns
## null when a file is absent, so every visual falls back to greybox until art
## is dropped in. Drop a PNG with the right name and it appears — no code/JSON
## changes needed (see ASSETS.md / the sprite guide).
##
## Conventions (all under res://assets/sprites/):
##   entities/<entity_id>.png        e.g. greece_shade.png, bali_rangda.png
##   entities/player.png             (or player_<character_id>.png to override)
##   tiles/<pantheon>_floor.png      e.g. greece_floor.png
##   tiles/<pantheon>_wall.png
##   tiles/<pantheon>_obstacle.png
##   fx/projectile_player.png        fx/projectile_enemy.png

const ENT := "res://assets/sprites/entities/"
const TILES := "res://assets/sprites/tiles/"
const FX := "res://assets/sprites/fx/"

var _cache: Dictionary = {}

func _get(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_cache[path] = t
	return t

func entity(id: String) -> Texture2D:
	return _get(ENT + id + ".png")

## Generic fallback monster sprite (tinted by the enemy's colour by the caller).
func entity_generic() -> Texture2D:
	return _get(ENT + "enemy.png")

## Player texture: per-character override, else a generic player.png.
func player(character_id: String) -> Texture2D:
	var t := _get(ENT + "player_" + character_id + ".png")
	return t if t != null else _get(ENT + "player.png")

## kind: "floor" | "wall" | "obstacle"
func tile(pantheon: String, kind: String) -> Texture2D:
	return _get(TILES + pantheon + "_" + kind + ".png")

## Generic tile (tinted per realm palette by the caller) — one set fits all realms.
func tile_generic(kind: String) -> Texture2D:
	return _get(TILES + kind + ".png")

func fx(name: String) -> Texture2D:
	var t := _get(FX + name + ".png")
	return t if t != null else _get(FX + "projectile.png")
