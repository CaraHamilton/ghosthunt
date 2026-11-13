@tool
class_name GhostInteractable
extends StaticBody2D
## Base class for objects around the house the ghost can mess with (sinks
## now; lights, doors, radios... later). While the ghost is invisible and not
## hunting, it checks nearby interactables and may trigger one at random.
##
## To make a new one: extend this, set `footprint`, override
## `_on_ghost_interact()` and `_draw()`, and drop it in the World node.
## The node's origin is the bottom-centre of its footprint (for Y-sorting).

## Area on the floor (width, depth). If `solid`, it blocks movement and
## ghost pathfinding.
@export var footprint := Vector2(24, 12):
	set(value):
		footprint = value
		queue_redraw()
## Solid furniture blocks the player and ghost. Turn off for small loose
## objects (like a ball) that should be walked over and can move around.
@export var solid := true
## How close (px) the ghost must be to the footprint (for decor up on a
## table, the tile it sits on) to interact. The same 12 px for everything.
@export var ghost_reach := 12.0
## Chance (0-1) per ghost check that the ghost interacts while in reach.
@export_range(0.0, 1.0) var ghost_interaction_chance := 0.35
## Seconds after an interaction before the ghost can trigger this again.
@export var cooldown := 6.0

@export_group("Player")
## If true, the player can also use this object - left click or E, within
## Player.USE_REACH of it.
@export var player_can_use := false

## Chance (0-1) that a residue-leaving ghost leaves UV residue each time it
## touches something.
const RESIDUE_CHANCE := 0.5

## Whether residue-leaving ghosts leave UV residue on this (false for the
## doll). Set by each interactable, in _init.
var can_have_residue := true
## Where the UV residue glow is centred, relative to the origin (e.g. on top
## of a sink's counter). Set by each interactable.
var residue_offset := Vector2(0, -8)
## The residue picture and whether it's mirrored (null = the default art).
## Set by each interactable, before _ready.
var residue_texture: Texture2D
var residue_flip_h := false
## True once a residue-leaving ghost has touched this. Only visible where the
## UV light shines on it (see ResidueGlow).
var has_residue := false:
	set(value):
		has_residue = value and can_have_residue
		if _residue_glow:
			_residue_glow.visible = has_residue

var _last_interaction_time := -INF
var _residue_glow: ResidueGlow


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("ghost_interactables")
	collision_mask = 0
	collision_layer = 0
	if solid:
		add_to_group("nav_obstacles")
		collision_layer = 1
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = footprint
		shape.shape = rect
		shape.position = Vector2(0, -footprint.y / 2.0)
		add_child(shape)
	if can_have_residue:
		_residue_glow = ResidueGlow.new()
		_residue_glow.position = residue_offset
		_residue_glow.texture = residue_texture
		_residue_glow.flip_h = residue_flip_h
		_residue_glow.visible = has_residue
		add_child(_residue_glow)


## The solid area on the floor, in global coordinates.
func get_footprint() -> Rect2:
	return Rect2(global_position + Vector2(-footprint.x / 2.0, -footprint.y), footprint)


## The area the ghost has to get close to, to touch this: its footprint -
## or, for something up on a table, the tile it sits on (see Switchable).
func get_reach_area() -> Rect2:
	return get_footprint()


## How close (px) the ghost must be to get_reach_area() to touch this.
func get_ghost_reach() -> float:
	return ghost_reach


func is_in_ghost_reach(point: Vector2) -> bool:
	return get_reach_area().grow(get_ghost_reach()).has_point(point)


func can_ghost_interact() -> bool:
	return _game_time() - _last_interaction_time >= cooldown


## Whether this kind of ghost will ever touch this object (e.g. only some
## ghost types possess the doll). Override per interactable.
func ghost_can_use(_ghost: Ghost) -> bool:
	return true


## Called by the ghost. Don't override this - override _on_ghost_interact.
func ghost_interact(ghost: Ghost) -> void:
	_last_interaction_time = _game_time()
	# Residue-leaving ghosts only leave it some of the time. Once there, it
	# stays.
	if ghost.behavior.leaves_uv_residue() and can_have_residue and randf() < RESIDUE_CHANCE:
		if OS.is_debug_build() and not has_residue:
			print("[debug] The ghost left UV residue on %s" % name)
		has_residue = true
	_on_ghost_interact(ghost)
	if Game.current:
		var levels := emf_levels()
		Game.current.add_emf_source(self, levels.x, levels.y, emf_5_chance())


## The EMF this gives off after the ghost touches it (min, max): 1-2 for
## something switched on (a sink). Switchables the ghost knocks over give 2-3.
func emf_levels() -> Vector2i:
	return Vector2i(1, 2)


## Chance (0-1) the EMF is a 5 instead, for ghost types that show EMF 5.
func emf_5_chance() -> float:
	return 0.1


## Seconds since the ghost last touched this (INF if never).
func seconds_since_ghost_interaction() -> float:
	return _game_time() - _last_interaction_time


## A spot on the floor next to this object where the ghost can stand to
## reach it: in front of it (the way it faces) if that's open floor, else the
## first open side of the others. If no side is open, the front anyway.
func get_ghost_stand_point() -> Vector2:
	var fp := get_reach_area()
	var gap := get_ghost_reach() * 0.5
	var front := get_front_direction()
	var sides: Array[Vector2] = [front, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2.UP]
	var house: House = Game.current.house if Game.current else null
	var first := Vector2.INF
	for dir in sides:
		# The middle of that side of the footprint, `gap` px out.
		var spot := fp.get_center() + dir * (fp.size / 2.0 + Vector2.ONE * gap)
		if first == Vector2.INF:
			first = spot
		if house == null or house.is_walkable(spot):
			return spot
	return first


## Which way this object faces (where the ghost prefers to stand to use it).
## Down unless overridden (see Switchable).
func get_front_direction() -> Vector2:
	return Vector2.DOWN


## Seconds of game time (stops while paused, follows Engine.time_scale).
func _game_time() -> float:
	return Engine.get_physics_frames() / float(Engine.physics_ticks_per_second)


## What happens when the ghost interacts. Override in each interactable.
func _on_ghost_interact(_ghost: Ghost) -> void:
	pass


## Short description for debug output, e.g. "turned on Kitchen sink".
func describe_last_interaction() -> String:
	return "interacted with %s" % name


# --- Player use -------------------------------------------------------------

## Where right-clicking counts as clicking on it, in global coordinates.
## Override to match the art (see Switchable); this is the footprint.
func get_click_rect() -> Rect2:
	return get_footprint()


## True if clicking at `point` (global) counts as clicking on it. Override to
## match the art exactly (see Switchable); this is inside get_click_rect.
func is_clicked_at(point: Vector2) -> bool:
	return get_click_rect().has_point(point)


## Called by the player pressing E. Don't override - override _on_player_interact.
func player_interact(player: Player) -> void:
	_on_player_interact(player)


## What happens when the player uses this. Override in each interactable.
func _on_player_interact(_player: Player) -> void:
	pass
