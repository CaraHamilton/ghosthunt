@tool
class_name Prop
extends StaticBody2D
## A piece of furniture placed in the editor: bed, dresser, closet, rug,
## bookcase... Solid props block the player, the ghost and its line of sight
## (useful cover to break away behind during a hunt); flat ones (rugs) are
## walked over and always drawn under everything else.
##
## Each piece of furniture has its own scene in res://scenes/furniture/ with
## its art and footprints set; houses place instances of those and pick
## which way each one faces.
##
## The node's origin is the bottom-centre of its footprint (for Y-sorting).
## The art is drawn with its bottom-centre on the origin, so anything standing
## up off the floor (a headboard, the front of a bookcase) sticks up above
## the footprint. Until it has art, a prop shows a coloured placeholder box.
##
## Art can be a single picture, or an Aseprite sheet with one frame per
## direction: export it with File > Export Sprite Sheet, with JSON Data
## (Meta: Tags) saved next to the PNG under the same name (bed.png +
## bed.json), and tag the frames "down", "right", "up" and "left". Every
## frame's floor area should sit at the bottom-centre of the canvas. Not
## every direction needs a frame: a missing "left" shows the "right" frame
## (and vice versa), and a missing "up" shows "down", as does anything else
## missing.

enum Facing { DOWN, RIGHT, UP, LEFT }

## Frame tags to look for for each facing, in order: its own, then the
## frames shown instead when the sheet doesn't have one for that way.
const FALLBACK_TAGS := [
	["down"],
	["right", "left", "down"],
	["up", "down"],
	["left", "right", "down"],
]

## The prop's picture or sheet (1x art). Leave empty for a placeholder box.
@export var art: Texture2D:
	set(value):
		art = value
		queue_redraw()
## Which way the furniture faces (which frame of the sheet is shown, and
## which footprint is used).
@export var facing := Facing.DOWN:
	set(value):
		facing = value
		queue_redraw()
## Area on the floor (width, depth) in px when facing down or up. Blocks
## movement and the ghost.
@export var footprint := Vector2(32, 16):
	set(value):
		footprint = value
		queue_redraw()
## Area on the floor when facing right or left. Leave at (0, 0) to use
## `footprint`.
@export var side_footprint := Vector2.ZERO:
	set(value):
		side_footprint = value
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
		var size := current_footprint()
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = size
		shape.shape = rect
		shape.position = Vector2(0, -size.y / 2.0)
		add_child(shape)


## The footprint for the way the prop is facing.
func current_footprint() -> Vector2:
	if (facing == Facing.RIGHT or facing == Facing.LEFT) and side_footprint != Vector2.ZERO:
		return side_footprint
	return footprint


## The prop's area on the floor, in global coordinates.
func get_footprint() -> Rect2:
	var size := current_footprint()
	return Rect2(global_position + Vector2(-size.x / 2.0, -size.y), size)


func _draw() -> void:
	var size := current_footprint()
	var r := Rect2(-size.x / 2.0, -size.y, size.x, size.y)
	if art:
		_draw_art()
		# Show the footprint in the editor, to help line it up with the art.
		if Engine.is_editor_hint():
			draw_rect(r, Color(1, 1, 1, 0.4), false, 1.0)
		return

	# Placeholder box
	if flat:
		draw_rect(r, color)
		draw_rect(r.grow(-4), color.lightened(0.15), false, 2.0)
	else:
		draw_rect(Rect2(r.position + Vector2(2, 3), r.size), Color(0, 0, 0, 0.25))
		draw_rect(r, color)
		draw_rect(Rect2(r.position, Vector2(r.size.x, 4)), color.lightened(0.2))
		draw_rect(r, color.darkened(0.4), false, 1.0)


# --- Art and sheets -------------------------------------------------------

func _draw_art() -> void:
	var frames := _sheet_frames()
	if frames.is_empty():
		# A single picture.
		draw_texture(art, Vector2(-floorf(art.get_width() / 2.0), -art.get_height()))
		return

	var f: Dictionary = frames[""]
	for tag: String in FALLBACK_TAGS[facing]:
		if frames.has(tag):
			f = frames[tag]
			break
	var canvas: Vector2 = f.canvas
	var region: Rect2 = f.region
	# Place the frame's canvas bottom-centre on the origin (`offset` is where
	# the frame sits on its canvas, if Aseprite trimmed it).
	var pos: Vector2 = Vector2(-floorf(canvas.x / 2.0), -canvas.y) + f.offset
	draw_texture_rect_region(art, Rect2(pos, region.size), region)


## The frames of `art`'s sheet by tag ("" = the first frame), each as
## {region, canvas, offset}, read from the Aseprite JSON next to it. Empty if
## `art` is a single picture.
func _sheet_frames() -> Dictionary:
	var json_path := art.resource_path.get_basename() + ".json"
	if not ResourceLoader.exists(json_path):
		return {}
	# In the editor, re-read it each time so a re-exported sheet shows up.
	var mode := ResourceLoader.CACHE_MODE_REPLACE if Engine.is_editor_hint() else ResourceLoader.CACHE_MODE_REUSE
	var json := ResourceLoader.load(json_path, "JSON", mode) as JSON
	if json == null or not json.data is Dictionary:
		return {}
	var data: Dictionary = json.data
	# Aseprite saves frames as a list or as a dictionary (Hash), in order.
	var raw: Variant = data.get("frames", [])
	var list: Array = (raw as Dictionary).values() if raw is Dictionary else raw
	if list.is_empty():
		return {}

	var frames := {}
	for i in list.size():
		var f: Dictionary = list[i]
		var info := {
			region = _rect(f.frame),
			canvas = Vector2(f.sourceSize.w, f.sourceSize.h),
			offset = _rect(f.spriteSourceSize).position,
		}
		if i == 0:
			frames[""] = info
		for t in data.get("meta", {}).get("frameTags", []):
			if t.from == i:
				frames[(t.name as String).to_lower()] = info
	return frames


func _rect(r: Dictionary) -> Rect2:
	return Rect2(r.x, r.y, r.w, r.h)
