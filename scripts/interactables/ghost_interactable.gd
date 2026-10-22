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
## How close (px) the ghost must be to the footprint to interact.
@export var ghost_reach := 20.0
## Chance (0-1) per ghost check that the ghost interacts while in reach.
@export_range(0.0, 1.0) var ghost_interaction_chance := 0.35
## Seconds after an interaction before the ghost can trigger this again.
@export var cooldown := 6.0

@export_group("Player")
## If true, the player can also use this object with E when standing next to it.
@export var player_can_use := false
## How close (px) the player must be to the footprint to use it.
@export var player_reach := 14.0
## How far above the origin the "[E] ..." prompt floats.
@export var prompt_height := 36.0

## Where the UV residue glow is centred, relative to the origin (e.g. on top
## of a sink's counter). Set by each interactable.
var residue_offset := Vector2(0, -8)
## True once a residue-leaving ghost has touched this. Only visible under UV.
var has_residue := false
## Set by the UV light each frame while its beam is on this object.
var uv_lit := false:
	set(value):
		uv_lit = value
		if _residue_glow:
			_residue_glow.visible = has_residue and uv_lit

var _last_interaction_time := -INF
var _prompt: Label
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
	if player_can_use:
		_build_player_zone()
	_residue_glow = ResidueGlow.new()
	_residue_glow.position = residue_offset
	_residue_glow.visible = false
	add_child(_residue_glow)


## The solid area on the floor, in global coordinates.
func get_footprint() -> Rect2:
	return Rect2(global_position + Vector2(-footprint.x / 2.0, -footprint.y), footprint)


func is_in_ghost_reach(point: Vector2) -> bool:
	return get_footprint().grow(ghost_reach).has_point(point)


func can_ghost_interact() -> bool:
	return _game_time() - _last_interaction_time >= cooldown


## Whether this kind of ghost will ever touch this object (e.g. only some
## ghost types play with the tennis ball). Override per interactable.
func ghost_can_use(_ghost: Ghost) -> bool:
	return true


## Called by the ghost. Don't override this - override _on_ghost_interact.
func ghost_interact(ghost: Ghost) -> void:
	_last_interaction_time = _game_time()
	if ghost.behavior.leaves_uv_residue():
		has_residue = true
	_on_ghost_interact(ghost)


## Seconds since the ghost last touched this (INF if never). Used by the EMF
## reader to pick up the ghost's traces.
func seconds_since_ghost_interaction() -> float:
	return _game_time() - _last_interaction_time


## A spot on the floor in front of this object where the ghost can stand
## to reach it.
func get_ghost_stand_point() -> Vector2:
	return global_position + Vector2(0, ghost_reach * 0.5)


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

## Called by the player pressing E. Don't override - override _on_player_interact.
func player_interact(player: Player) -> void:
	_on_player_interact(player)
	_refresh_prompt()


## What happens when the player uses this. Override in each interactable.
func _on_player_interact(_player: Player) -> void:
	pass


## Prompt text shown above the object, e.g. "[E] Turn on".
func get_player_prompt() -> String:
	return "[E] Use"


## The player shows the prompt only on the closest thing they can use.
func set_prompt_visible(value: bool) -> void:
	if _prompt:
		_refresh_prompt()
		_prompt.visible = value


func _refresh_prompt() -> void:
	if _prompt:
		_prompt.text = get_player_prompt()


func _build_player_zone() -> void:
	var zone := Area2D.new()
	zone.collision_layer = 0
	zone.collision_mask = 2  # player
	var zone_shape := CollisionShape2D.new()
	var zone_rect := RectangleShape2D.new()
	zone_rect.size = footprint + Vector2.ONE * player_reach * 2.0
	zone_shape.shape = zone_rect
	zone_shape.position = Vector2(0, -footprint.y / 2.0)
	zone.add_child(zone_shape)
	add_child(zone)
	zone.body_entered.connect(func(body):
		if body is Player: body.register_interactable(self))
	zone.body_exited.connect(func(body):
		if body is Player: body.unregister_interactable(self))

	_prompt = Label.new()
	_prompt.add_theme_font_size_override("font_size", 8)
	_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	_prompt.add_theme_constant_override("outline_size", 3)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.size = Vector2(70, 12)
	_prompt.position = Vector2(-35, -prompt_height)
	_prompt.z_index = 20
	_prompt.visible = false
	add_child(_prompt)
	_refresh_prompt()
