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
const PROPS := "res://assets/sprites/props/"
const PORTRAITS := "res://assets/sprites/portraits/"
const ICONS := "res://assets/sprites/icons/"
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

## Decorative prop (non-colliding), e.g. greece_column, egypt_urn.
func prop(id: String) -> Texture2D:
	return _resolve(PROPS, id)

## Speaker portrait for dialogue (deity id or "narrator").
func portrait(speaker: String) -> Texture2D:
	return _resolve(PORTRAITS, speaker)

## Boon/blessing icon (by blessing id).
func icon(id: String) -> Texture2D:
	return _resolve(ICONS, id)

func fx(name: String) -> Texture2D:
	var t := _resolve(FX, name)
	return t if t != null else _resolve(FX, "projectile")

## True if a specific FX texture exists (vs falling back to a generic one).
func has_fx(name: String) -> bool:
	return _resolve(FX, name) != null

# --- Animations ---
const ANIMS := ["idle", "walk", "attack", "death"]
const ANIM_FPS := {"idle": 6.0, "walk": 10.0, "attack": 12.0, "death": 10.0}

## A per-animation spritesheet: entities/<id>_<anim>.png (horizontal strip of
## square frames).
func sheet(id: String, anim: String) -> Texture2D:
	return _resolve(ENT, id + "_" + anim)

func has_anim(id: String) -> bool:
	for a in ANIMS:
		if sheet(id, a) != null:
			return true
	return false

## Square frame size (= sheet height) of the first available animation, else 0.
func anim_frame_size(id: String) -> int:
	for a in ANIMS:
		var t := sheet(id, a)
		if t != null:
			return t.get_height()
	return 0

# --- Content sizing (ignore transparent padding so on-screen size is consistent
# regardless of how much empty space the art tool pads around the character) ---
var _content_cache: Dictionary = {}

## Max dimension of the opaque bounding box of a texture (falls back to full size).
func content_size(tex: Texture2D) -> float:
	if tex == null:
		return 1.0
	var key := tex.resource_path + "#full"
	if _content_cache.has(key):
		return _content_cache[key]
	var v := float(maxi(tex.get_width(), tex.get_height()))
	var img := tex.get_image()
	if img != null:
		var r := img.get_used_rect()
		if r.size.x > 0 and r.size.y > 0:
			v = float(maxi(r.size.x, r.size.y))
	_content_cache[key] = v
	return v

## Opaque content max-dim of the FIRST frame (fs×fs) of the first animation strip.
func anim_content_size(id: String) -> float:
	for a in ANIMS:
		var t := sheet(id, a)
		if t == null:
			continue
		var fs := t.get_height()
		if fs <= 0:
			return 0.0
		var key := t.resource_path + "#f0"
		if _content_cache.has(key):
			return _content_cache[key]
		var v := float(fs)
		var img := t.get_image()
		if img != null:
			var frame := img.get_region(Rect2i(0, 0, fs, fs))
			var r := frame.get_used_rect()
			if r.size.x > 0 and r.size.y > 0:
				v = float(maxi(r.size.x, r.size.y))
		_content_cache[key] = v
		return v
	return 0.0

## Build a SpriteFrames from the per-animation strips (frames = width / height).
## idle/walk loop; attack/death play once. Returns null if no sheets exist.
func build_sprite_frames(id: String) -> SpriteFrames:
	if not has_anim(id):
		return null
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	for a in ANIMS:
		var tex := sheet(id, a)
		if tex == null:
			continue
		var fh := tex.get_height()
		if fh <= 0:
			continue
		var count: int = maxi(1, int(round(float(tex.get_width()) / float(fh))))
		sf.add_animation(a)
		sf.set_animation_speed(a, ANIM_FPS.get(a, 8.0))
		sf.set_animation_loop(a, a == "idle" or a == "walk")
		for i in count:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * fh, 0, fh, fh)
			sf.add_frame(a, at)
	return sf

