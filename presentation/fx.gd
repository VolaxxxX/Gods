extends Node
## One-shot visual effects (muzzle flash, projectile impact, melee slash, …).
## Plays a spritesheet once at a world position, then frees itself. Asset-agnostic:
## looks for assets/sprites/fx/<name>.png (a horizontal strip of square frames)
## and is a no-op if absent. Frame count = width / height. (See ASSETS guide.)

const DIR := "res://assets/sprites/fx/"
const EXTS := [".png", ".svg"]
const FPS := 18.0

var _cache: Dictionary = {}

func _strip(name: String) -> Texture2D:
	if _cache.has(name):
		return _cache[name]
	var tex: Texture2D = null
	for ext in EXTS:
		var path := DIR + name + ext
		if ResourceLoader.exists(path):
			tex = load(path)
			break
	_cache[name] = tex
	return tex

## Play effect `name` centered at `world_pos`. `target_px` is the on-screen size.
func play(name: String, world_pos: Vector2, target_px: float = 48.0) -> void:
	var tex := _strip(name)
	if tex == null:
		return
	var fh := tex.get_height()
	if fh <= 0:
		return
	var host := get_tree().current_scene
	if host == null:
		return
	var count: int = maxi(1, int(round(float(tex.get_width()) / float(fh))))
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	sf.add_animation("e")
	sf.set_animation_loop("e", false)
	sf.set_animation_speed("e", FPS)
	for i in count:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * fh, 0, fh, fh)
		sf.add_frame("e", at)
	var a := AnimatedSprite2D.new()
	a.sprite_frames = sf
	a.scale = Vector2.ONE * (target_px / float(fh))
	a.z_index = 18
	host.add_child(a)
	a.global_position = world_pos
	a.animation_finished.connect(a.queue_free)
	a.play("e")
