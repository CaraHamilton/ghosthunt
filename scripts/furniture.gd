@tool
class_name Furniture
extends StaticBody2D
## A solid piece of furniture (dresser, closet or cupboard). It blocks the
## player, the ghost's path, and the ghost's line of sight - useful cover to
## break away behind during a hunt. The node's origin is the bottom-centre of
## the furniture's footprint (so Y-sorting works). Collision is built from
## `kind` at runtime.

enum Kind { DRESSER, CLOSET, CUPBOARD }

@export var kind: Kind = Kind.DRESSER:
	set(value):
		kind = value
		queue_redraw()

const SIZES := {
	Kind.DRESSER: Vector2(28, 14),   # footprint (width, depth)
	Kind.CLOSET: Vector2(30, 12),
	Kind.CUPBOARD: Vector2(22, 12),
}
const HEIGHTS := {
	Kind.DRESSER: 14.0,   # how tall it is drawn above the footprint
	Kind.CLOSET: 30.0,
	Kind.CUPBOARD: 22.0,
}


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("nav_obstacles")
	collision_layer = 1
	collision_mask = 0

	var size: Vector2 = SIZES[kind]
	var body_shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	body_shape.shape = rect
	body_shape.position = Vector2(0, -size.y / 2.0)
	add_child(body_shape)


## The furniture's solid area on the floor, in global coordinates.
func get_footprint() -> Rect2:
	var size: Vector2 = SIZES[kind]
	return Rect2(global_position + Vector2(-size.x / 2.0, -size.y), size)


# --- Placeholder art ------------------------------------------------------

func _draw() -> void:
	var size: Vector2 = SIZES[kind]
	var h: float = HEIGHTS[kind]
	var w := size.x
	var top := -size.y - h
	var wood := Color("8a5a3b")
	var wood_dark := Color("5e3a25")
	var wood_light := Color("a8724d")

	# Shadow on the floor
	draw_rect(Rect2(-w / 2.0 + 1, -2, w, 3), Color(0, 0, 0, 0.25))
	# Top surface (seen from above at a 3/4 angle)
	draw_rect(Rect2(-w / 2.0, top, w, size.y * 0.6), wood_light)
	# Front face
	var front := Rect2(-w / 2.0, top + size.y * 0.6, w, h + size.y * 0.4)
	draw_rect(front, wood)
	draw_rect(front, wood_dark, false, 1.0)

	match kind:
		Kind.DRESSER:
			# Three rows of drawers with knobs
			var rows := 3
			var row_h := front.size.y / rows
			for i in rows:
				var r := Rect2(front.position.x + 2, front.position.y + i * row_h + 1, w - 4, row_h - 2)
				draw_rect(r, wood_dark, false, 1.0)
				draw_rect(Rect2(r.get_center() - Vector2(1, 0.5), Vector2(2, 1)), Color("e0c070"))
		Kind.CLOSET, Kind.CUPBOARD:
			# Two doors with handles
			var door_l := Rect2(front.position.x + 2, front.position.y + 2, w / 2.0 - 3, front.size.y - 3)
			var door_r := Rect2(1, front.position.y + 2, w / 2.0 - 3, front.size.y - 3)
			draw_rect(door_l, wood_dark, false, 1.0)
			draw_rect(door_r, wood_dark, false, 1.0)
			draw_rect(Rect2(-3, front.get_center().y, 1, 3), Color("e0c070"))
			draw_rect(Rect2(2, front.get_center().y, 1, 3), Color("e0c070"))
