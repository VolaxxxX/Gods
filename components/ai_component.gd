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
		_:
			return (target.global_position - self_pos).normalized()
