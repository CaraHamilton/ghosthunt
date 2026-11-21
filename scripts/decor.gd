@tool
class_name Decor
extends Prop
## Still-life decor: a plate and fork, a vase, a bowl of fruit... Just
## something to look at - nobody can use it. (For decor the ghost can knock
## over or the player can switch, use Switchable instead.)
##
## Give it `art` like any Prop (a single picture, or an Aseprite sheet with
## facing tags). With `snap_to_tile` on (the default), just drop it on a
## tile, on the floor or on a table: when the game starts it snaps to that
## tile the same way a placed tool does - standing on the floor (bottom-centre
## of the tile, solid), or up on the table's top if a table covers the tile.
## The editor shows where it will be: a white box on the floor, blue on a
## table, red if it can't go there (a wall, solid furniture, off the floor) -
## then it stays where you put it. It takes its tile, so the player can't
## place a tool on top of it.
##
## With `snap_to_tile` off it's an ordinary Prop: place it by hand, and its
## `footprint` is used.

## Snap to the floor tile it's dropped on (or onto the table there). Turn off
## to place it by hand like furniture.
@export var snap_to_tile := true:
	set(value):
		snap_to_tile = value
		_preview_snap()

## How far (px) the art is drawn above the origin (up on a table's top).
var _lift := 0.0
## In the editor: from the node to where it will snap to (the node itself
## only moves there when the game starts).
var _shift := Vector2.ZERO
## In the editor: whether its tile can take it (red box if not).
var _snap_ok := true


func _ready() -> void:
	if Engine.is_editor_hint():
		set_notify_transform(true)
		_preview_snap()
	elif snap_to_tile:
		var spot := DecorSnap.spot_for(self)
		if spot.get("ok", false):
			global_position = spot.position
			_lift = spot.elevation
			# Its tile is taken: no tools placed on top of it.
			set_meta("place_tile", spot.cell)
			add_to_group(House.PLACED_GROUP)
		else:
			push_warning("%s can't snap to its tile (wall, furniture or no floor)" % name)
		# Up on a table it's out of the way; the table blocks instead.
		solid = solid and _lift == 0.0
	super()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_preview_snap()


## Snapped, it always takes exactly one tile (DecorSnap.TILE_FOOTPRINT).
func current_footprint() -> Vector2:
	return DecorSnap.TILE_FOOTPRINT if snap_to_tile else super()


func get_art_rect() -> Rect2:
	return super().grow_individual(0, _lift, 0, -_lift)


func is_art_at(point: Vector2) -> bool:
	return super(point + Vector2(0, _lift))


## Editor: works out where it will snap to, for drawing it there.
func _preview_snap() -> void:
	queue_redraw()
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	_shift = Vector2.ZERO
	_lift = 0.0
	_snap_ok = true
	if snap_to_tile:
		var spot := DecorSnap.spot_for(self)
		if not spot.is_empty():
			_snap_ok = spot.ok
			if spot.ok:
				_shift = spot.position - global_position
				_lift = spot.elevation
	# The node hasn't moved in front of the table yet, so lift the preview
	# over it to show it on top. (Straight on the canvas item, not z_index,
	# so it isn't saved in the scene.)
	RenderingServer.canvas_item_set_z_index(get_canvas_item(), 1 if _lift > 0.0 else 0)


func _draw() -> void:
	if not snap_to_tile:
		super()
		return
	var size := current_footprint()
	var art_at := _shift - Vector2(0, _lift)
	if art:
		draw_set_transform(art_at)
		_draw_art()
		draw_set_transform(Vector2.ZERO)
	else:
		draw_rect(Rect2(art_at + Vector2(-size.x / 2.0, -size.y - 8), size + Vector2(0, 8)), color)
	if Engine.is_editor_hint():
		DecorSnap.draw_preview(self, size, _shift, _lift, _snap_ok)
