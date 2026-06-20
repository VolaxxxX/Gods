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
## Accepts a horizontal strip (frames = width/height) OR a square 4x4 grid
## (16 frames, row-major) — PixelLab exports VFX as a 4x4 sheet.
func play(name: String, world_pos: Vector2, target_px: float = 48.0) -> void:
	var tex := _strip(name)
	if tex == null:
		return
	var w := tex.get_width()
	var h := tex.get_height()
	if w <= 0 or h <= 0:
		return
	var host := get_tree().current_scene
	if host == null:
		return

	var regions: Array = []
	var fs: int
	if w == h:
		# Square sheet → 4x4 grid (16 frames), read left-to-right, top-to-bottom.
		fs = int(w / 4)
		for r in 4:
			for c in 4:
				regions.append(Rect2(c * fs, r * fs, fs, fs))
	else:
		# Horizontal strip of square frames.
		fs = h
		var count: int = maxi(1, int(round(float(w) / float(h))))
		for i in count:
			regions.append(Rect2(i * fs, 0, fs, fs))

	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	sf.add_animation("e")
	sf.set_animation_loop("e", false)
	sf.set_animation_speed("e", FPS)
	for reg in regions:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = reg
		sf.add_frame("e", at)

	var a := AnimatedSprite2D.new()
	a.sprite_frames = sf
	a.scale = Vector2.ONE * (target_px / float(fs))
	a.z_index = 18
	host.add_child(a)
	a.global_position = world_pos
	a.animation_finished.connect(a.queue_free)
	a.play("e")
