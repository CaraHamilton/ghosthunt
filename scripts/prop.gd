@tool
class_name Prop
extends StaticBody2D
## A piece of furniture placed in the editor: bed, dresser, closet, rug,
## bookcase... Solid props block the player, the ghost and its line of sight
## (useful cover to break away behind during a hunt); flat ones (rugs) are
## walked over and always drawn under everything else.
##
## The node's origin is the bottom-centre of its footprint (for Y-sorting).
## `art` is drawn with its bottom-centre on the origin, so anything standing
## up off the floor (a headboard, the front of a bookcase) sticks up above
## the footprint. Until it has art, a prop shows a coloured placeholder box.

## The prop's picture (1x art). Leave empty for a placeholder box.
@export var art: Texture2D:
	set(value):
		art = value
		queue_redraw()
## Area on the floor (width, depth) in px. Blocks movement and the ghost.
@export var footprint := Vector2(32, 16):
	set(value):
		footprint = value
		queue_redraw()
## Colour of the placeholder box (unused once the prop has art).
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


func _draw() -> void:
	if art:
		draw_texture(art, Vector2(-floorf(art.get_width() / 2.0), -art.get_height()))
		return

	# Placeholder box
	var r := Rect2(-footprint.x / 2.0, -footprint.y, footprint.x, footprint.y)
	if flat:
		draw_rect(r, color)
		draw_rect(r.grow(-4), color.lightened(0.15), false, 2.0)
	else:
		draw_rect(Rect2(r.position + Vector2(2, 3), r.size), Color(0, 0, 0, 0.25))
		draw_rect(r, color)
		draw_rect(Rect2(r.position, Vector2(r.size.x, 4)), color.lightened(0.2))
		draw_rect(r, color.darkened(0.4), false, 1.0)
