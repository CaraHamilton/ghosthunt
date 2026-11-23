class_name DecorSnap
extends RefCounted
## Snapping small decor to the tile it's dropped on - standing on the floor,
## or up on a table's top if a table covers the tile - the same way a placed
## tool goes down (see House.get_place_spot). Shared by Decor (still-life:
## a plate, a vase) and Switchable (decor the ghost or player can use: a
## book stack, candles), which both have a `snap_to_tile` setting.

## The footprint of snapped decor: one whole tile, whatever size its art is.
const TILE_FOOTPRINT := Vector2(16, 16)


## The House `node` is in, or null.
static func house_of(node: Node) -> House:
	var parent := node.get_parent()
	while parent and not parent is House:
		parent = parent.get_parent()
	return parent as House


## Where `node` snaps to: a House.get_place_spot dictionary (ok, position,
## elevation, cell, rect...). On a table if one covers its tile, else
## standing on the floor with its origin at the bottom-centre of the tile.
## Empty if it isn't in a house. Works in the editor too.
static func spot_for(node: Node2D) -> Dictionary:
	var house := house_of(node)
	if house == null or house.floor_layer == null:
		return {}
	# 2px up: an origin on a tile's bottom edge (like furniture's), or just
	# below it, means that tile, not the one below.
	var cell := house.tile_at(node.global_position - Vector2(0, 2))
	# The house's furniture, straight from the scene (furniture only
	# registers itself as an obstacle once the game runs). Snapped decor
	# isn't furniture - it takes its tile instead (House.PLACED_GROUP).
	var obstacles := []
	for prop: Prop in house.find_children("*", "Prop", true, false):
		if prop.solid and not prop.flat and not (prop is Decor and prop.snap_to_tile):
			obstacles.append(prop)
	# ...and hand-placed Switchables (a sink, a fireplace).
	for other: Switchable in house.find_children("*", "Switchable", true, false):
		if other != node and other.solid and not other.snap_to_tile and other.raise == 0.0:
			obstacles.append(other)
	return house.get_place_spot(cell, true, obstacles)


## Editor: the box showing where snapped decor will go, drawn on `canvas`.
## White on the floor (what it blocks), blue up on a table (where it rests),
## red if it can't go there. `shift` is from the node to where it will
## snap; `lift` is how far up the table's top is.
static func draw_preview(canvas: CanvasItem, size: Vector2, shift: Vector2, lift: float, ok: bool) -> void:
	var r := Rect2(shift + Vector2(-size.x / 2.0, -size.y), size)
	if not ok:
		canvas.draw_rect(r, Color(1, 0.2, 0.2, 0.9), false, 1.0)
	elif lift == 0.0:
		canvas.draw_rect(r, Color(1, 1, 1, 0.4), false, 1.0)
	else:
		canvas.draw_rect(Rect2(r.position - Vector2(0, lift), r.size), Color(0.4, 0.8, 1, 0.7), false, 1.0)
		canvas.draw_line(shift, shift - Vector2(0, lift), Color(0.4, 0.8, 1, 0.4), 1.0)
