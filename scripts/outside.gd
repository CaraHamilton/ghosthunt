@tool
class_name Outside
extends Node2D
## An area outside the house the player can go to, like the yard or the
## trailer. It sits in the
## same scene as the house, far off to one side, and a Door links the two
## (see Door) - so the house keeps running while the player is out here:
## sanity stops draining, no hunts start, and the ghost carries on inside.
##
## The node's origin is the area's top-left corner and `size` its extent.
## Invisible walls around the edge keep the player in. Until there's real
## art (paint tiles on a TileMapLayer child named "Ground"), it draws a
## placeholder: grass, and a path down from the door.

## The area (width, height) in px, from the node's origin.
@export var size := Vector2(400, 288):
	set(value):
		size = value
		queue_redraw()
## How dark the night is out here (Game swaps the Darkness to this while the
## player is outside). Lighter than indoors: moonlight.
@export var darkness := Color(0.22, 0.24, 0.36)
## The temperature (°C) a thermometer reads out here.
@export var temperature := 9.0

@export_group("Placeholder")
## The placeholder ground (a checker of these two colours), drawn until the
## Ground layer has tiles.
@export var ground_color := Color("2d3f2c"):
	set(value):
		ground_color = value
		queue_redraw()
@export var ground_color_dark := Color("263726"):
	set(value):
		ground_color_dark = value
		queue_redraw()
## Draw a placeholder path leading down from each door.
@export var door_paths := true:
	set(value):
		door_paths = value
		queue_redraw()

## The placeholder path colour.
const PATH := Color("5a5141")
## The night beyond the edges (the same as around the house).
const BEYOND := House.OUTSIDE_COLOR
## How thick (px) the invisible edge walls are.
const EDGE := 16.0


func _ready() -> void:
	queue_redraw()
	if Engine.is_editor_hint():
		return
	add_to_group("outside_areas")
	_build_edges()


## The area, in global coordinates.
func get_bounds() -> Rect2:
	return Rect2(global_position, size)


func _build_edges() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1  # the world: blocks the player
	body.collision_mask = 0
	var r := Rect2(Vector2.ZERO, size)
	for edge: Rect2 in [
			Rect2(r.position.x - EDGE, r.position.y - EDGE, r.size.x + EDGE * 2.0, EDGE),  # top
			Rect2(r.position.x - EDGE, r.end.y, r.size.x + EDGE * 2.0, EDGE),  # bottom
			Rect2(r.position.x - EDGE, r.position.y, EDGE, r.size.y),  # left
			Rect2(r.end.x, r.position.y, EDGE, r.size.y)]:  # right
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = edge.size
		shape.shape = rect
		shape.position = edge.get_center()
		body.add_child(shape)
	add_child(body)


func _has_ground_art() -> bool:
	var ground := get_node_or_null("Ground") as TileMapLayer
	return ground != null and ground.get_used_cells().size() > 0


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size).grow(400.0), BEYOND)
	if _has_ground_art():
		return
	# Placeholder ground with a little checker texture, and a path down from
	# each door.
	draw_rect(Rect2(Vector2.ZERO, size), ground_color)
	for y in range(0, int(size.y), 16):
		for x in range(0, int(size.x), 16):
			if (x / 16 + y / 16) % 2 == 0:
				draw_rect(Rect2(x, y, 16, 16), ground_color_dark)
	if not door_paths:
		return
	for door in get_children():
		if door is Door:
			var top: float = door.position.y
			draw_rect(Rect2(door.position.x - 12.0, top, 24.0, size.y - top), PATH)
