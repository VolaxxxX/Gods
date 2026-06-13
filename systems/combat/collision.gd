class_name Collision
extends RefCounted
## Central definition of physics layers as bit values. Set layer/mask in code
## from these so collision wiring lives in one documented place.
## Layer N has value 1 << (N-1).

const WORLD        := 1 << 0  # walls, obstacles (StaticBody2D)
const PLAYER_BODY  := 1 << 1  # player CharacterBody2D
const ENEMY_BODY   := 1 << 2  # enemy CharacterBody2D
const PLAYER_HURT  := 1 << 3  # player's hurtbox (takes damage)
const ENEMY_HURT   := 1 << 4  # enemy's hurtbox (takes damage)
const PLAYER_DMG   := 1 << 5  # player's damage areas (projectiles/melee)
const ENEMY_DMG    := 1 << 6  # enemy's damage areas (contact/projectiles)
