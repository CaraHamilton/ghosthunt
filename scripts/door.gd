@tool
class_name Door
extends Area2D
## A way between two areas: the house's front door and the yard's, say.
## Walking onto it fades the screen out, moves the player to the other door
## with the same `door_id`, and fades back in (see Game.go_through). The
## house keeps running the whole time, so the ghost carries on while the
## player is outside.
##
## Place one in each area and give them the same `door_id`. In the editor the
## yellow box is the trigger (the player's feet walking into it) and the dot
## is where the player arrives when coming through from the other door - keep
## the dot outside the box, on open floor.

## Doors with the same id lead to each other.
@export var door_id := &"front"
## The trigger area (width, height), centred on the node.
@export var size := Vector2(16, 8):
	set(value):
		size = value
		_update_shape()
		queue_redraw()
## Where the player arrives, relative to the door, when coming through the
## other door.
@export var exit_offset := Vector2(0, 20):
	set(value):
		exit_offset = value
		queue_redraw()

## A locked door won't let the player through (Game locks the house's doors
## during a hunt - see Game.is_door_locked). A wall just past the trigger
## stops them walking out past it.
var locked := false:
	set(value):
		locked = value
		if _blocker:
			_blocker.set_deferred("disabled", not locked)

var _shape: CollisionShape2D
var _blocker: CollisionShape2D


func _ready() -> void:
	_update_shape()
	if Engine.is_editor_hint():
		return
	_build_blocker()
	add_to_group("doors")
	collision_layer = 0
	collision_mask = 2  # the player
	body_entered.connect(func(body: Node2D) -> void:
		if body is Player and Game.current:
			Game.current.go_through(self))


## The door this one leads to (same door_id), or null if there isn't one.
func get_partner() -> Door:
	for door: Door in get_tree().get_nodes_in_group("doors"):
		if door != self and door.door_id == door_id:
			return door
	return null


## Where the player arrives when coming through to this door.
func get_exit_point() -> Vector2:
	return global_position + exit_offset


## The wall used while locked: 8px thick, just beyond the trigger on the far
## side from where the player arrives (exit_offset points into the room).
func _build_blocker() -> void:
	var outward := -exit_offset.normalized()
	var rect := RectangleShape2D.new()
	var body := StaticBody2D.new()
	body.collision_layer = 1  # walls - the player bumps into it
	body.collision_mask = 0
	_blocker = CollisionShape2D.new()
	if absf(outward.y) >= absf(outward.x):
		rect.size = Vector2(size.x, 8.0)
		_blocker.position = Vector2(0, signf(outward.y) * (size.y / 2.0 + 4.0))
	else:
		rect.size = Vector2(8.0, size.y)
		_blocker.position = Vector2(signf(outward.x) * (size.x / 2.0 + 4.0), 0)
	_blocker.shape = rect
	_blocker.disabled = not locked
	body.add_child(_blocker)
	add_child(body, false, INTERNAL_MODE_BACK)


func _update_shape() -> void:
	if _shape == null:
		_shape = CollisionShape2D.new()
		add_child(_shape, false, INTERNAL_MODE_FRONT)
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var gold := Color(1.0, 0.8, 0.2)
	draw_rect(Rect2(-size / 2.0, size), Color(gold, 0.25))
	draw_rect(Rect2(-size / 2.0, size), gold, false, 1.0)
	draw_line(Vector2.ZERO, exit_offset, Color(gold, 0.6), 1.0)
	draw_circle(exit_offset, 2.0, gold)
