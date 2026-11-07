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
##
## A sheet can also hold animations: tag a run of frames (e.g. "lit") and set
## `animation` to that tag's name to loop it, with each frame shown for as
## long as its duration in Aseprite. The animation replaces the facing frame.

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
## Name of a tag in the sheet whose frames loop as an animation (e.g. "lit").
## Leave empty to show the facing frame instead.
@export var animation := "":
	set(value):
		animation = value
		set_process(animation != "")
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
## Tables, desks, counters...: the player can place items on top (one per
## floor tile the footprint covers), instead of the prop blocking them.
@export var surface := false:
	set(value):
		surface = value
		queue_redraw()
## How far (px) the top of the surface is above the floor in the art: items
## on it are drawn this much higher (and a lantern lights from up there). In
## the editor, the blue box shows where the top is - line it up with the art.
@export var surface_height := 12.0:
	set(value):
		surface_height = value
		queue_redraw()


## Cached sheet (see _sheet), and when it was read.
var _sheet_cache := {}
var _sheet_path := ""
var _sheet_time := 0


func _ready() -> void:
	set_process(animation != "")
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
			if surface:
				draw_rect(Rect2(r.position - Vector2(0, surface_height), r.size),
					Color(0.4, 0.8, 1, 0.7), false, 1.0)
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

func _process(_delta: float) -> void:
	# Redraw while animating, so the frame advances.
	if art and _frames_to_show().size() > 1:
		queue_redraw()


func _draw_art() -> void:
	var frames := _frames_to_show()
	if frames.is_empty():
		# A single picture.
		draw_texture(art, Vector2(-floorf(art.get_width() / 2.0), -art.get_height()))
		return

	var f: Dictionary = frames[0]
	if frames.size() > 1:
		# Pick the animation frame for now: all props share one clock.
		var total := 0
		for fr: Dictionary in frames:
			total += fr.duration
		var t := Time.get_ticks_msec() % maxi(total, 1)
		for fr: Dictionary in frames:
			if t < fr.duration:
				f = fr
				break
			t -= fr.duration
	var canvas: Vector2 = f.canvas
	var region: Rect2 = f.region
	# Place the frame's canvas bottom-centre on the origin (`offset` is where
	# the frame sits on its canvas, if Aseprite trimmed it).
	var pos: Vector2 = Vector2(-floorf(canvas.x / 2.0), -canvas.y) + f.offset
	draw_texture_rect_region(art, Rect2(pos, region.size), region)


## The frames to draw: the `animation` tag's frames if it has one, else the
## single frame for `facing` (or the sheet's first frame). Empty if `art` is a
## single picture.
func _frames_to_show() -> Array:
	var sheet := _sheet()
	if sheet.is_empty():
		return []
	var frames: Array = sheet.frames
	var tags: Dictionary = sheet.tags
	var key := animation.to_lower()
	if key != "" and tags.has(key):
		var span: Vector2i = tags[key]
		return frames.slice(span.x, span.y + 1)
	var tag := facing_tag()
	if tag != "":
		return [frames[(tags[tag] as Vector2i).x]]
	return [frames[0]]


## True if `art`'s sheet has a tag called `tag` (any case).
func has_tag(tag: String) -> bool:
	return art != null and _sheet().get("tags", {}).has(tag.to_lower())


## The tag of the frame shown for `facing` ("right" for a "left"-facing prop
## with no "left" frame...), or "" if the sheet has none of them.
func facing_tag() -> String:
	for tag: String in FALLBACK_TAGS[facing]:
		if has_tag(tag):
			return tag
	return ""


## `art`'s sheet, read from the Aseprite JSON next to it: {frames, tags}.
## frames: each {region, canvas, offset, duration (ms)}, in order.
## tags: tag name (lower case) -> Vector2i(first frame, last frame).
## Empty if `art` is a single picture.
func _sheet() -> Dictionary:
	var json_path := art.resource_path.get_basename() + ".json"
	# Read it once; in the editor, again whenever it's re-exported.
	var time := FileAccess.get_modified_time(json_path) if Engine.is_editor_hint() else 0
	if json_path == _sheet_path and time == _sheet_time:
		return _sheet_cache
	_sheet_path = json_path
	_sheet_time = time
	_sheet_cache = _read_sheet(json_path)
	return _sheet_cache


func _read_sheet(json_path: String) -> Dictionary:
	if not ResourceLoader.exists(json_path):
		return {}
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

	var frames := []
	for f: Dictionary in list:
		frames.append({
			region = _rect(f.frame),
			canvas = Vector2(f.sourceSize.w, f.sourceSize.h),
			offset = _rect(f.spriteSourceSize).position,
			duration = int(f.get("duration", 100)),
		})
	var tags := {}
	for t: Dictionary in data.get("meta", {}).get("frameTags", []):
		var first := clampi(int(t.from), 0, frames.size() - 1)
		var last := clampi(int(t.to), first, frames.size() - 1)
		tags[(t.name as String).to_lower()] = Vector2i(first, last)
	return {frames = frames, tags = tags}


func _rect(r: Dictionary) -> Rect2:
	return Rect2(r.x, r.y, r.w, r.h)
