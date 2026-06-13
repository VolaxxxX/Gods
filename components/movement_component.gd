class_name MovementComponent
extends Node
## Reusable top-down movement math. Smooths a desired direction into a velocity
## with acceleration/friction. The owning CharacterBody2D applies the result via
## move_and_slide(). Keeps movement feel consistent across player and enemies.

@export var max_speed: float = 120.0
@export var acceleration: float = 1400.0  # px/s^2
@export var friction: float = 1600.0      # px/s^2 when no input

## Returns the new velocity given current velocity and a (possibly unnormalized,
## magnitude<=1) input direction.
func compute(velocity: Vector2, input_dir: Vector2, delta: float) -> Vector2:
	if input_dir.length() > 0.01:
		var target := input_dir.limit_length(1.0) * max_speed
		return velocity.move_toward(target, acceleration * delta)
	return velocity.move_toward(Vector2.ZERO, friction * delta)
