class_name DamageArea
extends Area2D
## Carries a Damage payload. It does NOT apply damage itself — a HurtboxComponent
## detects it and pulls the payload (see hurtbox_component.gd). This keeps the
## "who can be hurt" decision on the receiver side and supports both one-shot
## projectiles and ticking contact damage.

signal hit(hurtbox: HurtboxComponent)

var damage: Damage
var pierce: bool = false
## 0 = single hit per receiver (projectiles, which despawn on hit);
## > 0 = re-applies every this-many seconds while overlapping (contact damage).
var retrigger_interval: float = 0.0

func setup(p_damage: Damage, pierce_through: bool = false, p_retrigger: float = 0.0) -> void:
	damage = p_damage
	pierce = pierce_through
	retrigger_interval = p_retrigger

func report_hit(hurtbox: HurtboxComponent) -> void:
	hit.emit(hurtbox)
