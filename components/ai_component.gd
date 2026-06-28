class_name AIComponent
extends Node
## Minimal enemy brain. Behavior is data-driven (EntityData.ai). Returns a desired
## movement direction toward a target; combat-specific behaviors can be added as
## new behavior ids without touching the enemy entity.

@export var behavior: String = "chase"

var target: Node2D  # usually the player

## Desired movement direction (unnormalized magnitude<=1) for this frame.
func desired_direction(self_pos: Vector2) -> Vector2:
	if target == null or not is_instance_valid(target):
		return Vector2.ZERO
	match behavior:
		"chase":
			return (target.global_position - self_pos).normalized()
		"keep_distance":
			var to_target := target.global_position - self_pos
			var dist := to_target.length()
			if dist < 160.0:
				return -to_target.normalized()      # back off
			elif dist > 240.0:
				return to_target.normalized()        # close in
			return Vector2.ZERO
		"orbit":
			# Ranged casters strafe a ring around the player while shooting: hard to
			# corner, keeps line of sight. Spiral in when far, push out when close.
			var o_to: Vector2 = target.global_position - self_pos
			var o_dist: float = o_to.length()
			var o_rad: Vector2 = o_to.normalized()
			var o_tan := Vector2(-o_rad.y, o_rad.x)
			if o_dist > 250.0:
				return (o_rad + o_tan * 0.5).normalized()
			elif o_dist < 150.0:
				return (o_tan - o_rad * 0.6).normalized()
			return o_tan
		"zigzag":
			# Erratic skirmisher: weaves side-to-side as it closes, so it's evasive
			# and awkward to hit while still reaching the player fast.
			var z_to: Vector2 = target.global_position - self_pos
			var z_rad: Vector2 = z_to.normalized()
			var z_tan := Vector2(-z_rad.y, z_rad.x)
			var phase: float = sin(float(Time.get_ticks_msec()) * 0.006 + self_pos.x * 0.05)
			return (z_rad + z_tan * phase * 0.9).normalized()
		_:
			return (target.global_position - self_pos).normalized()
