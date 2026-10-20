@tool
class_name House
extends Node2D
## Draws the house (floors, walls, decor) and builds wall collision at runtime.
## Everything is placeholder art built from rectangles; replace it with a
## TileMapLayer once you have a tileset.
##
## Layout (pixels, 16px tiles):
##   +-------------------+-------------------+
##   |                   |     Bedroom       |
##   |   Living room     =                   |
##   |                   +-------- ---------+
##   +------- ----------+                    |
##   |    Bathroom       =     Kitchen       |
##   +-------------------+-------------------+
## ("=" and gaps are doorways)

const SIZE := Vector2(640, 400)
const WALL_TOP_HEIGHT := 16.0  # height of the visible "front face" of a wall

## Solid wall rectangles.
const WALLS: Array[Rect2] = [
	# Outer walls
	Rect2(0, 0, 640, 32),
	Rect2(0, 384, 640, 16),
	Rect2(0, 0, 16, 400),
	Rect2(624, 0, 16, 400),
	# Vertical wall between left and right halves (doors at y 96-144 and 288-336)
	Rect2(304, 32, 16, 64),
	Rect2(304, 144, 16, 144),
	Rect2(304, 336, 16, 48),
	# Bedroom / kitchen wall (door at x 448-496)
	Rect2(320, 176, 128, 32),
	Rect2(496, 176, 128, 32),
	# Living room / bathroom wall (door at x 128-176)
	Rect2(16, 224, 112, 32),
	Rect2(176, 224, 128, 32),
]

## Floors: [rect, base colour, pattern]
const FLOORS := [
	[Rect2(16, 32, 288, 192), Color("b07a4f"), "planks"],   # living room
	[Rect2(320, 32, 304, 144), Color("7d5b8c"), "carpet"],  # bedroom
	[Rect2(320, 208, 304, 176), Color("d9cfb8"), "tiles"],  # kitchen
	[Rect2(16, 256, 288, 128), Color("8fb3b8"), "tiles"],   # bathroom
	# doorway floors
	[Rect2(304, 96, 16, 48), Color("b07a4f"), "planks"],
	[Rect2(304, 288, 16, 48), Color("d9cfb8"), "tiles"],
	[Rect2(448, 176, 48, 32), Color("7d5b8c"), "carpet"],
	[Rect2(128, 224, 48, 32), Color("b07a4f"), "planks"],
]

## Decor: [rect, colour, solid?]
const DECOR := [
	[Rect2(96, 110, 112, 64), Color("a8463c"), false],  # living room rug
	[Rect2(110, 180, 84, 18), Color("4f6b3a"), true],   # couch
	[Rect2(130, 120, 44, 22), Color("6e4a2f"), true],   # coffee table
	[Rect2(540, 60, 44, 60), Color("e8e0d0"), true],    # bed
	[Rect2(400, 280, 72, 40), Color("8a5a3b"), true],   # kitchen table
	[Rect2(212, 300, 60, 32), Color("f2f2f2"), true],   # bathtub
]

## Where the player starts.
const PLAYER_START := Vector2(160, 100)

## Pathfinding grid used by ghosts so they walk around walls and furniture.
const NAV_CELL := 8
## How far (px) paths keep away from solids, so the ghost's body fits.
const NAV_MARGIN := 5.0

var _grid: AStarGrid2D


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	for r in _solid_rects():
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = r.size
		shape.shape = rect
		shape.position = r.get_center()
		body.add_child(shape)


func _solid_rects() -> Array[Rect2]:
	var solids: Array[Rect2] = []
	solids.append_array(WALLS)
	for d in DECOR:
		if d[2]:
			solids.append(d[0])
	return solids


## Builds the pathfinding grid. `extra_solids` are other obstacles placed in
## the scene (e.g. hiding-spot furniture footprints).
func build_navigation(extra_solids: Array[Rect2]) -> void:
	_grid = AStarGrid2D.new()
	_grid.region = Rect2i(0, 0, ceili(SIZE.x / NAV_CELL), ceili(SIZE.y / NAV_CELL))
	_grid.cell_size = Vector2(NAV_CELL, NAV_CELL)
	_grid.offset = Vector2(NAV_CELL, NAV_CELL) / 2.0  # path points at cell centres
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.update()

	var solids := _solid_rects()
	solids.append_array(extra_solids)
	for r in solids:
		var grown := r.grow(NAV_MARGIN)
		var from := Vector2i((grown.position / NAV_CELL).floor())
		var to := Vector2i((grown.end / NAV_CELL).ceil())
		_grid.fill_solid_region(Rect2i(from, to - from).intersection(_grid.region))


## Path of points from `from` towards `to`. If `to` can't be reached exactly
## (e.g. the player is hugging a wall), the path ends as close as possible.
func get_nav_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	return _grid.get_point_path(_to_cell(from), _to_cell(to), true)


func is_walkable(point: Vector2) -> bool:
	var cell := Vector2i((point / NAV_CELL).floor())
	return _grid.is_in_boundsv(cell) and not _grid.is_point_solid(cell)


func _to_cell(point: Vector2) -> Vector2i:
	var cell := Vector2i((point / NAV_CELL).floor())
	return cell.clamp(_grid.region.position, _grid.region.end - Vector2i.ONE)


func _draw() -> void:
	# Night outside
	draw_rect(Rect2(-200, -200, SIZE.x + 400, SIZE.y + 400), Color("1d2236"))

	for f in FLOORS:
		_draw_floor(f[0], f[1], f[2])

	for d in DECOR:
		var r: Rect2 = d[0]
		var c: Color = d[1]
		if d[2]:
			draw_rect(Rect2(r.position + Vector2(2, 3), r.size), Color(0, 0, 0, 0.25))
			draw_rect(r, c)
			draw_rect(Rect2(r.position, Vector2(r.size.x, 4)), c.lightened(0.2))
			draw_rect(r, c.darkened(0.4), false, 1.0)
		else:
			draw_rect(r, c)
			draw_rect(r.grow(-4), c.lightened(0.15), false, 2.0)

	for w in WALLS:
		_draw_wall(w)


func _draw_floor(r: Rect2, base: Color, pattern: String) -> void:
	draw_rect(r, base)
	match pattern:
		"planks":
			var y := r.position.y
			var row := 0
			while y < r.end.y:
				draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), base.darkened(0.2), 1.0)
				var x := r.position.x + (row % 2) * 24.0
				while x < r.end.x:
					draw_line(Vector2(x, y), Vector2(x, minf(y + 8, r.end.y)), base.darkened(0.2), 1.0)
					x += 48.0
				y += 8.0
				row += 1
		"tiles":
			var ts := 16.0
			var yy := r.position.y
			while yy < r.end.y:
				var xx := r.position.x
				while xx < r.end.x:
					if int((xx - r.position.x) / ts + (yy - r.position.y) / ts) % 2 == 0:
						draw_rect(Rect2(xx, yy, minf(ts, r.end.x - xx), minf(ts, r.end.y - yy)), base.darkened(0.08))
					xx += ts
				yy += ts
		"carpet":
			draw_rect(r.grow(-6), base.lightened(0.08), false, 2.0)


func _draw_wall(r: Rect2) -> void:
	var top_col := Color("4a3b52")
	var face_col := Color("c9b48f")  # wallpaper
	var trim := Color("6e4a2f")
	# Wall tops
	draw_rect(r, top_col)
	# Horizontal walls show a wallpapered front face along their bottom edge
	if r.size.x > r.size.y and r.size.y >= 32.0:
		var face := Rect2(r.position.x, r.end.y - WALL_TOP_HEIGHT, r.size.x, WALL_TOP_HEIGHT)
		draw_rect(face, face_col)
		var x := face.position.x + 4
		while x < face.end.x:
			draw_line(Vector2(x, face.position.y), Vector2(x, face.end.y - 3), face_col.darkened(0.08), 1.0)
			x += 8.0
		draw_rect(Rect2(face.position.x, face.end.y - 3, face.size.x, 3), trim)
	draw_rect(r, top_col.darkened(0.3), false, 1.0)
