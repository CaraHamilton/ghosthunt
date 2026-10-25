@tool
class_name Prop
extends StaticBody2D
## A simple piece of decor placed in the editor: rug, couch, table, bed,
## bathtub... Solid props block the player, the ghost and its line of sight;
## flat ones (rugs) are walked over and always drawn under everything else.
##
## The node's origin is the bottom-centre of its footprint (for Y-sorting).
## Placeholder art is a coloured box; give it a Sprite2D child and set
## `draw_placeholder` off once you have art.

## Area on the floor (width, depth) in px.
@export var footprint := Vector2(32, 16):
	set(value):
		footprint = value
		queue_redraw()
@export var color := Color("8a5a3b"):
	set(value):
		color = value
		queue_redraw()
## Solid props block movement and the ghost's pathfinding and sight.
@export var solid := true
## Flat props (rugs) are walked over and drawn underneath everything.
@export var flat := false:
	set(value):
		flat = value
		z_index = -1 if flat else 0
		queue_redraw()
## Turn off once the prop has a real sprite.
@export var draw_placeholder := true:
	set(value):
		draw_placeholder = value
		queue_redraw()


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	collision_mask = 0
	collision_layer = 0
	if solid and not flat:
		add_to_group("nav_obstacles")
		collision_layer = 1
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = footprint
		shape.shape = rect
		shape.position = Vector2(0, -footprint.y / 2.0)
		add_child(shape)


## The prop's area on the floor, in global coordinates.
func get_footprint() -> Rect2:
	return Rect2(global_position + Vector2(-footprint.x / 2.0, -footprint.y), footprint)


# --- Placeholder art ------------------------------------------------------

func _draw() -> void:
	if not draw_placeholder:
		return
	var r := Rect2(-footprint.x / 2.0, -footprint.y, footprint.x, footprint.y)
	if flat:
		draw_rect(r, color)
		draw_rect(r.grow(-4), color.lightened(0.15), false, 2.0)
	else:
		draw_rect(Rect2(r.position + Vector2(2, 3), r.size), Color(0, 0, 0, 0.25))
		draw_rect(r, color)
		draw_rect(Rect2(r.position, Vector2(r.size.x, 4)), color.lightened(0.2))
		draw_rect(r, color.darkened(0.4), false, 1.0)
