class_name FogMachine
extends ItemPickup
## The fog machine on the floor - the world version of the fog machine item.
## It's on as soon as it's put down: it faces the way the player was facing
## and fills the next FOG_TILES tiles that way with fog (stopping early at a
## wall or solid furniture). E picks it back up.
##
## Nothing here is solid: the player and the ghost walk straight through the
## machine and the fog. Each frame it just checks whether the ghost's feet are
## inside the fog. If they are, and the ghost type shows in fog (see
## GhostBehavior.shows_in_fog), the figure outline fades in where the ghost
## is, and follows it until it leaves the fog. Not while the ghost is
## visible (hunting or appearing) - you can already see it then.
##
## Art (all exported from Aseprite, see the defaults below):
##   machine - 16x16 frames, one per facing: left, right, up, down
##   fog     - 32x40 frames, 3 per facing: right, left, up, down
##   figure  - 16x24 frames, looped

## How many tiles in front of the machine the fog fills.
const FOG_TILES := 2
const MACHINE_FRAME := {Vector2i.LEFT: 0, Vector2i.RIGHT: 1, Vector2i.UP: 2, Vector2i.DOWN: 3}
const FOG_FIRST_FRAME := {Vector2i.RIGHT: 0, Vector2i.LEFT: 3, Vector2i.UP: 6, Vector2i.DOWN: 9}
const FOG_FRAMES_PER_FACING := 3
const FOG_FRAME_SIZE := Vector2(32, 40)
const FIGURE_FRAME_SIZE := Vector2(16, 24)

@export var machine_art: Texture2D = preload("res://art/overworld/fog_machine_overworld.png")
@export var fog_art: Texture2D = preload("res://art/overworld/fog_overworld.png")
@export var figure_art: Texture2D = preload("res://art/overworld/ghost_in_fog.png")
## How solid the fog looks: 1 = fully solid, 0 = invisible.
@export_range(0.0, 1.0) var fog_opacity := 0.7
## Seconds per frame of the fog loop.
@export var fog_frame_time := 0.1
## Seconds per frame of the figure loop.
@export var figure_frame_time := 0.15
## Seconds for the figure to fade fully in or out.
@export var figure_fade_time := 0.4

@export_group("Fog position")
## Where the top-left corner of a fog frame goes, relative to the machine's
## origin (the bottom-centre of its tile), for each facing. The defaults put
## the fog in the 2 tiles next to the machine: right/left frames sit with
## their bottom on the tile's bottom, the up frame's bottom on the tile's
## top, the down frame's top on the tile's bottom.
@export var fog_offset_right := Vector2(8, -40)
@export var fog_offset_left := Vector2(-40, -40)
@export var fog_offset_up := Vector2(-8, -56)
@export var fog_offset_down := Vector2(-8, 0)

## The way the machine (and its fog) faces.
var facing := Vector2i.DOWN
## How many tiles the fog actually fills (fewer than FOG_TILES if a wall or
## furniture is in the way).
var fog_length := FOG_TILES

var _fog_rects: Array[Rect2] = []   # the fog's tiles, in world space
var _time := 0.0
var _figure_alpha := 0.0
var _figure_spot := Vector2.ZERO   # bottom-centre of the figure, local
var _ghost_in_fog := false


func _ready() -> void:
	super()
	var game := Game.current
	if game == null or game.house == null:
		return
	var house := game.house
	if game.player:
		var f := game.player.facing
		facing = Vector2i(signi(roundi(f.x)), 0) if absf(f.x) > absf(f.y) \
			else Vector2i(0, 1 if f.y > 0.0 else -1)
	# Sit exactly on a tile (it may have been dropped off the grid).
	var cell := house.tile_at(global_position + Vector2(0, -1))
	var tile := house.tile_rect(cell)
	global_position = Vector2(tile.get_center().x, tile.end.y)
	fog_length = 0
	for i in range(1, FOG_TILES + 1):
		var next := cell + facing * i
		if not house.is_tile_open(next):
			break
		_fog_rects.append(house.tile_rect(next))
		fog_length = i


func _process(delta: float) -> void:
	_time += delta
	var ghost := Game.current.ghost if Game.current else null
	var inside := false
	if is_instance_valid(ghost):
		for r in _fog_rects:
			if r.has_point(ghost.global_position):
				inside = true
				break
	# No figure while the ghost is visible anyway (hunting or appearing).
	var shows := inside and ghost.behavior.shows_in_fog() and not ghost.is_manifested
	if inside != _ghost_in_fog:
		_ghost_in_fog = inside
		if inside and OS.is_debug_build():
			print("[debug] The ghost walked into the fog%s" % ("" if shows else " (no figure)"))
	if shows:
		_figure_spot = (ghost.global_position - global_position).round()
	var step := delta / maxf(figure_fade_time, 0.01)
	_figure_alpha = clampf(_figure_alpha + (step if shows else -step), 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	# Machine
	var m := Rect2(MACHINE_FRAME[facing] * 16, 0, 16, 16)
	draw_texture_rect_region(machine_art, Rect2(-8, -16, 16, 16), m)
	# Fog, cut short if it doesn't fill both tiles
	if fog_length > 0:
		var frame: int = FOG_FIRST_FRAME[facing] + int(_time / fog_frame_time) % FOG_FRAMES_PER_FACING
		var src := Rect2(Vector2(frame * FOG_FRAME_SIZE.x, 0), FOG_FRAME_SIZE)
		var at := _fog_offset()
		if fog_length < FOG_TILES:
			var keep := 16.0 * fog_length
			match facing:
				Vector2i.RIGHT:
					src.size.x = keep
				Vector2i.LEFT:
					src.position.x += src.size.x - keep
					at.x += src.size.x - keep
					src.size.x = keep
				Vector2i.UP:
					var cut := maxf(src.size.y - keep - 8.0, 0.0)
					src.position.y += cut
					at.y += cut
					src.size.y -= cut
				Vector2i.DOWN:
					src.size.y = minf(keep + 8.0, src.size.y)
		draw_texture_rect_region(fog_art, Rect2(at, src.size), src, Color(1, 1, 1, fog_opacity))
	# Figure in the fog
	if _figure_alpha > 0.0:
		var frames := maxi(int(figure_art.get_width() / FIGURE_FRAME_SIZE.x), 1)
		var f := int(_time / figure_frame_time) % frames
		var fsrc := Rect2(Vector2(f * FIGURE_FRAME_SIZE.x, 0), FIGURE_FRAME_SIZE)
		var fat := _figure_spot - Vector2(FIGURE_FRAME_SIZE.x / 2.0, FIGURE_FRAME_SIZE.y)
		draw_texture_rect_region(figure_art, Rect2(fat, FIGURE_FRAME_SIZE), fsrc,
			Color(1, 1, 1, _figure_alpha))


func _fog_offset() -> Vector2:
	match facing:
		Vector2i.RIGHT:
			return fog_offset_right
		Vector2i.LEFT:
			return fog_offset_left
		Vector2i.UP:
			return fog_offset_up
	return fog_offset_down


## The tiles the fog fills, in world space (for tests and debugging).
func get_fog_rects() -> Array[Rect2]:
	return _fog_rects
