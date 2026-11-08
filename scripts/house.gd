@tool
class_name House
extends Node2D
## The house map. Everything about the layout lives in the scene, not here -
## paint and arrange it in the editor:
##
##   House
##   ├─ Floor        TileMapLayer: floor tiles (no collision)
##   ├─ Walls        TileMapLayer: wall tiles. Tiles with a collision shape
##   │               (TileSet → Paint → Physics Layer 0) block the player,
##   │               the ghost, and the ghost's line of sight.
##   ├─ WallDecor    TileMapLayer drawn over Walls: windows and other wall
##   │               decorations (no collision - the wall underneath blocks).
##   │               Window tiles get a moonlight glow in game.
##   ├─ Rooms        a Room (resizable box) per room: names the areas used for
##   │               temperatures, the ghost's favourite room, the EMF reader...
##   └─ PlayerStart  Marker2D where the player begins
##
## Props (furniture) and Switchables (sinks, books...) are scenes placed in the Furniture node; they add
## their own collision and tell the ghost's pathfinding about themselves.
## This script also draws the dark "outside" behind the map and builds the
## ghost's pathfinding grid from the wall tiles.

## Pathfinding grid used by ghosts so they walk around walls and furniture.
## Small cells so the grid matches the real collision shapes closely: any gap
## the player's body fits through, the ghost's same-sized body can path into.
const NAV_CELL := 4
## How far (px) paths keep away from solids - the ghost's collision radius.
const NAV_MARGIN := 4.0
## Colour of the night outside the house (drawn behind the map).
const OUTSIDE_COLOR := Color("1d2236")
## The light put on each window (see _add_window_lights).
const WINDOW_LIGHT := preload("res://scenes/window_light.tscn")

@onready var floor_layer: TileMapLayer = $Floor
@onready var walls_layer: TileMapLayer = $Walls

var _rooms: Array[Room] = []
var _bounds := Rect2()
var _grid: AStarGrid2D


func _ready() -> void:
	_bounds = _compute_bounds()
	queue_redraw()
	if Engine.is_editor_hint():
		return
	for child in get_node("Rooms").get_children():
		if child is Room:
			_rooms.append(child)
	if _rooms.is_empty():
		push_warning("House has no Room nodes under House/Rooms.")
	_add_window_lights()


## Puts a WindowLight (res://scenes/window_light.tscn - tweak it there) on
## every WallDecor tile whose "window_light" custom data is ticked (TileSet >
## Paint > Custom Data). It sits on that tile's bottom edge, so tick the top
## tile of a two-tile-tall window to light it from the middle.
func _add_window_lights() -> void:
	var decor := get_node_or_null("WallDecor") as TileMapLayer
	if decor == null or decor.tile_set.get_custom_data_layer_by_name("window_light") == -1:
		return
	for cell in decor.get_used_cells():
		var data := decor.get_cell_tile_data(cell)
		if data and data.get_custom_data("window_light"):
			var light: Node2D = WINDOW_LIGHT.instantiate()
			light.position = decor.map_to_local(cell) + Vector2(0, 8)
			decor.add_child(light)


# --- Layout queries -----------------------------------------------------------

## The area covered by the painted map (floors and walls), in world space.
func get_bounds() -> Rect2:
	return _bounds


## Where the player starts (the PlayerStart marker).
func get_player_start() -> Vector2:
	var marker := get_node_or_null("PlayerStart") as Node2D
	return marker.global_position if marker else _bounds.get_center()


## True if `point` is inside the house (any room, doorway or wall), false
## if it's outside. Used e.g. to stop the player's sanity draining outdoors.
## (Paint any future outdoor ground on its own layer, not Floor/Walls.)
func is_inside(point: Vector2) -> bool:
	return _bounds.has_point(point)


## Every room's name, once each (a room made of several boxes counts once).
func get_room_names() -> Array[String]:
	var names: Array[String] = []
	for room in _rooms:
		if room.get_room_name() not in names:
			names.append(room.get_room_name())
	return names


## Name of the room containing `point`, or "" if it's in a doorway/wall.
func room_at(point: Vector2) -> String:
	for room in _rooms:
		if room.get_world_rect().has_point(point):
			return room.get_room_name()
	return ""


## A random walkable point inside the named room. For a room made of several
## boxes, bigger boxes are picked more often so points spread evenly.
func random_point_in_room(room_name: String) -> Vector2:
	var rects := _get_room_rects(room_name)
	if rects.is_empty():
		push_error("No room called '%s'" % room_name)
		return get_player_start()
	var total_area := 0.0
	for r in rects:
		total_area += r.get_area()
	for i in 100:
		var pick := randf() * total_area
		var r: Rect2 = rects[0]
		for candidate in rects:
			r = candidate
			pick -= candidate.get_area()
			if pick <= 0.0:
				break
		var p := Vector2(randf_range(r.position.x, r.end.x), randf_range(r.position.y, r.end.y))
		if is_walkable(p):
			return p
	return rects[0].get_center()


## The boxes that make up a room (usually one; L-shaped rooms have several).
func _get_room_rects(room_name: String) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for room in _rooms:
		if room.get_room_name() == room_name:
			rects.append(room.get_world_rect())
	return rects


# --- Placing items ------------------------------------------------------------

## Items are placed on the floor tiles' grid, one per tile.
const PLACED_GROUP := &"placed_items"
## How far (px) up from a tile's centre an item's bottom sits.
const PLACE_OFFSET := Vector2(0, 4)


## The floor tile containing `point`.
func tile_at(point: Vector2) -> Vector2i:
	return floor_layer.local_to_map(floor_layer.to_local(point))


## A floor tile's square, in world space.
func tile_rect(cell: Vector2i) -> Rect2:
	var size := Vector2(floor_layer.tile_set.tile_size)
	var center := floor_layer.to_global(floor_layer.map_to_local(cell))
	return Rect2(center - size / 2.0, size)


## Where an item placed on `cell` would go:
##   ok        - false if the tile is a wall, under furniture, off the floor
##               or already has an item on it
##   position  - the item's node position (its spot on the floor; for an
##               item on a table, the table's front edge, so it Y-sorts in
##               front of the table)
##   elevation - how far (px) above `position` the item is drawn (0 on the floor)
##   rect      - the tile's square as it looks (raised onto a table's top)
##   surface   - the Prop it sits on, or null on the floor
## With `on_surfaces` false (an item that only goes on the floor), a tile on
## a table counts as blocked.
func get_place_spot(cell: Vector2i, on_surfaces := true) -> Dictionary:
	var rect := tile_rect(cell)
	var spot := {ok = false, cell = cell, position = rect.get_center() + PLACE_OFFSET,
		elevation = 0.0, rect = rect, surface = null}
	if floor_layer.get_cell_source_id(cell) == -1 or _is_solid_wall(cell) or is_tile_taken(cell):
		return spot
	# A table here takes the item (even with a chair tucked under it);
	# otherwise any furniture overlapping the tile is in the way.
	var surface: Prop = null
	var blocked := false
	for obstacle in get_tree().get_nodes_in_group("nav_obstacles"):
		var fp: Rect2 = obstacle.get_footprint()
		if obstacle is Prop and obstacle.surface and fp.has_point(rect.get_center()):
			surface = obstacle
		elif fp.intersects(rect.grow(-3.0)):
			blocked = true
	if (blocked and surface == null) or (surface and not on_surfaces):
		return spot
	spot.ok = true
	if surface:
		# Rest it on the table's top, kept a little in from its edges.
		var top := surface.get_footprint().grow(-5.0)
		var rest: Vector2 = spot.position
		rest = rest.clamp(top.position, top.end)
		var front := surface.get_footprint().end.y + 0.5
		spot.surface = surface
		spot.position = Vector2(rest.x, front)
		spot.elevation = front - rest.y + surface.surface_height
		spot.rect = Rect2(rect.position - Vector2(0, surface.surface_height), rect.size)
	return spot


## True if an item has been placed on `cell`.
func is_tile_taken(cell: Vector2i) -> bool:
	for node in get_tree().get_nodes_in_group(PLACED_GROUP):
		if not node.is_queued_for_deletion() and node.get_meta("place_tile", null) == cell:
			return true
	return false


func _is_solid_wall(cell: Vector2i) -> bool:
	var wall_cell := walls_layer.local_to_map(walls_layer.to_local(tile_rect(cell).get_center()))
	var data := walls_layer.get_cell_tile_data(wall_cell)
	return data != null and walls_layer.tile_set.get_physics_layers_count() > 0 \
		and data.get_collision_polygons_count(0) > 0


# --- Pathfinding ----------------------------------------------------------------

## Builds the pathfinding grid from the solid wall tiles plus `extra_solids`
## (prop and sink footprints).
func build_navigation(extra_solids: Array[Rect2]) -> void:
	var from := Vector2i((_bounds.position / NAV_CELL).floor())
	var to := Vector2i((_bounds.end / NAV_CELL).ceil())
	_grid = AStarGrid2D.new()
	_grid.region = Rect2i(from, to - from)
	_grid.cell_size = Vector2(NAV_CELL, NAV_CELL)
	_grid.offset = Vector2(NAV_CELL, NAV_CELL) / 2.0  # path points at cell centres
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.update()

	var solids := _solid_wall_rects()
	solids.append_array(extra_solids)
	for r in solids:
		# A cell is blocked only if the ghost's centre standing at the cell's
		# centre would overlap the solid (i.e. the centre is inside the solid
		# grown by the ghost's radius).
		var grown := r.grow(NAV_MARGIN)
		var half := NAV_CELL / 2.0
		var cell_from := Vector2i(((grown.position - Vector2(half, half)) / NAV_CELL).floor()) + Vector2i.ONE
		var cell_to := Vector2i(((grown.end - Vector2(half, half)) / NAV_CELL).ceil())
		_grid.fill_solid_region(Rect2i(cell_from, cell_to - cell_from).intersection(_grid.region))


## Path of points from `from` towards `to`. If `to` can't be reached exactly
## (e.g. the player is hugging a wall), the path ends as close as possible.
func get_nav_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	return _grid.get_point_path(_to_cell(from), _to_cell(to), true)


func is_walkable(point: Vector2) -> bool:
	var cell := Vector2i((point / NAV_CELL).floor())
	return _grid.is_in_boundsv(cell) and not _grid.is_point_solid(cell)


## World-space squares of every wall tile that has collision (so the ghost's
## map always matches what actually blocks movement).
func _solid_wall_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var tile_set := walls_layer.tile_set
	if tile_set == null or tile_set.get_physics_layers_count() == 0:
		push_warning("Walls TileSet has no physics layer - walls won't block anything.")
		return rects
	var size := Vector2(tile_set.tile_size)
	for cell in walls_layer.get_used_cells():
		var data := walls_layer.get_cell_tile_data(cell)
		if data and data.get_collision_polygons_count(0) > 0:
			var center := walls_layer.to_global(walls_layer.map_to_local(cell))
			rects.append(Rect2(center - size / 2.0, size))
	return rects


## The grid cell for a point. If that cell is blocked (e.g. the ghost is
## brushing right up against furniture, inside the pathfinding margin), uses
## the nearest open cell instead so a path can still be found.
func _to_cell(point: Vector2) -> Vector2i:
	var cell := Vector2i((point / NAV_CELL).floor())
	cell = cell.clamp(_grid.region.position, _grid.region.end - Vector2i.ONE)
	if not _grid.is_point_solid(cell):
		return cell
	for r in range(1, 6):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue  # only check the ring at distance r
				var c := cell + Vector2i(dx, dy)
				if _grid.is_in_boundsv(c) and not _grid.is_point_solid(c):
					return c
	return cell


# --- Map helpers --------------------------------------------------------------

func _compute_bounds() -> Rect2:
	var result := Rect2()
	var first := true
	for layer: TileMapLayer in [floor_layer, walls_layer]:
		if layer == null or layer.tile_set == null:
			continue
		var used := layer.get_used_rect()
		if used.size == Vector2i.ZERO:
			continue
		var size := Vector2(layer.tile_set.tile_size)
		var r := Rect2(layer.global_position + Vector2(used.position) * size, Vector2(used.size) * size)
		result = r if first else result.merge(r)
		first = false
	return result


func _draw() -> void:
	# The night outside, behind the map.
	if _bounds.size != Vector2.ZERO:
		draw_rect(Rect2(_bounds.position - global_position, _bounds.size).grow(400.0), OUTSIDE_COLOR)
