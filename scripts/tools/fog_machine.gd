class_name FogMachine
extends ItemPickup
## The fog machine on the floor - the world version of the fog machine item.
## It's on as soon as it's put down, and fills the 4 tiles next to it (left,
## right, up and down) with fog, whichever way the player was facing. A side
## blocked by a wall or solid furniture gets no fog. E picks it back up.
##
## Nothing here is solid: the player and the ghost walk straight through the
## machine and the fog. Each frame it just checks whether the ghost's feet are
## inside a fog tile. If they are, the ghost is invisible, and its type shows
## in fog (see GhostBehavior.shows_in_fog), the figure outline fades in where
## the ghost is, and follows it until it leaves the fog. Not while the ghost
## is visible (hunting or appearing) - you can already see it then.
##
## Each fog tile is its own Y-sorted sprite, so the player and furniture sort
## in front of or behind each tile properly.
##
## Art (all exported from Aseprite, see the defaults below):
##   machine - 16x16 frames; `machine_frame` picks which one is drawn
##   fog     - 16x24 frames, 3 per side: right, up, left, down (see the
##             Fog position settings for where each sits on its tile)
##   figure  - 16x24 frames, looped

const FOG_FIRST_FRAME := {Vector2i.RIGHT: 0, Vector2i.UP: 3, Vector2i.LEFT: 6, Vector2i.DOWN: 9}
const FOG_FRAMES_PER_SIDE := 3
const FOG_FRAME_SIZE := Vector2(16, 24)
const FIGURE_FRAME_SIZE := Vector2(16, 24)
const SIDES: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.UP, Vector2i.LEFT, Vector2i.DOWN]

@export var machine_art: Texture2D = preload("res://art/overworld/fog_machine_overworld.png")
## Which 16x16 frame of `machine_art` is the machine (counting from 0).
@export var machine_frame := 0
@export var fog_art: Texture2D = preload("res://art/overworld/fog_overworld.png")
@export var figure_art: Texture2D = preload("res://art/overworld/ghost_in_fog.png")
## How solid the fog looks: 1 = fully solid, 0 = invisible.
@export_range(0.0, 1.0) var fog_opacity := 0.7
@export_group("Fog position")
## Where each side's fog frame's top-left corner goes, relative to the
## bottom-centre of its tile. Right, up and left: the frame's bottom on the
## tile's bottom (billowing 8px above it). Down: the frame's top on the
## tile's top, so it doesn't cover the machine.
@export var fog_offset_right := Vector2(-8, -24)
@export var fog_offset_up := Vector2(-8, -24)
@export var fog_offset_left := Vector2(-8, -24)
@export var fog_offset_down := Vector2(-8, -16)
@export_group("")
## Seconds per frame of the fog loop.
@export var fog_frame_time := 0.1
## Seconds per frame of the figure loop.
@export var figure_frame_time := 0.15
## Seconds for the figure to fade fully in or out.
@export var figure_fade_time := 0.4

var _fog_rects: Array[Rect2] = []   # the fog's tiles, in world space
var _fog_sprites := {}   # side (Vector2i) -> Sprite2D
var _figure: Sprite2D
var _time := 0.0
var _figure_alpha := 0.0
var _ghost_in_fog := false


func _ready() -> void:
	super()
	# Lets each fog tile (a child) Y-sort with the rest of the world.
	y_sort_enabled = true
	var game := Game.current
	if game == null or game.house == null:
		return
	var house := game.house
	# Sit exactly on a tile (it may have been dropped off the grid).
	var cell := house.tile_at(global_position + Vector2(0, -1))
	var tile := house.tile_rect(cell)
	global_position = Vector2(tile.get_center().x, tile.end.y)
	for side in SIDES:
		if not house.is_tile_open(cell + side):
			continue
		var rect := house.tile_rect(cell + side)
		_fog_rects.append(rect)
		var fog := Sprite2D.new()
		fog.texture = fog_art
		fog.region_enabled = true
		fog.centered = false
		fog.offset = _fog_offset(side)
		fog.position = Vector2(side) * 16.0  # the tile's bottom-centre
		fog.modulate.a = fog_opacity
		add_child(fog)
		_fog_sprites[side] = fog
	_figure = Sprite2D.new()
	_figure.texture = figure_art
	_figure.region_enabled = true
	_figure.centered = false
	_figure.visible = false
	add_child(_figure)
	_update_fog_frames()


func _process(delta: float) -> void:
	_time += delta
	_update_fog_frames()
	var ghost := Game.current.ghost if Game.current else null
	var in_rect := Rect2()
	var inside := false
	if is_instance_valid(ghost):
		for r in _fog_rects:
			if r.has_point(ghost.global_position):
				inside = true
				in_rect = r
				break
	# No figure while the ghost is visible anyway (hunting or appearing).
	var shows := inside and ghost.behavior.shows_in_fog() and not ghost.is_manifested
	if inside != _ghost_in_fog:
		_ghost_in_fog = inside
		if inside and OS.is_debug_build():
			print("[debug] The ghost walked into the fog%s" % ("" if shows else " (no figure)"))
	if shows:
		# Sort just in front of the fog tile the ghost is in, but draw the
		# figure with its feet where the ghost's feet are.
		var feet := (ghost.global_position - global_position).round()
		_figure.position = Vector2(feet.x, in_rect.end.y - global_position.y + 0.1)
		_figure.offset = Vector2(-FIGURE_FRAME_SIZE.x / 2.0, feet.y - _figure.position.y - FIGURE_FRAME_SIZE.y)
	var step := delta / maxf(figure_fade_time, 0.01)
	_figure_alpha = clampf(_figure_alpha + (step if shows else -step), 0.0, 1.0)
	if _figure:
		_figure.visible = _figure_alpha > 0.0
		_figure.modulate.a = _figure_alpha
		var frames := maxi(int(figure_art.get_width() / FIGURE_FRAME_SIZE.x), 1)
		var f := int(_time / figure_frame_time) % frames
		_figure.region_rect = Rect2(Vector2(f * FIGURE_FRAME_SIZE.x, 0), FIGURE_FRAME_SIZE)


func _update_fog_frames() -> void:
	var step := int(_time / fog_frame_time) % FOG_FRAMES_PER_SIDE
	for side: Vector2i in _fog_sprites:
		var frame: int = FOG_FIRST_FRAME[side] + step
		_fog_sprites[side].region_rect = Rect2(Vector2(frame * FOG_FRAME_SIZE.x, 0), FOG_FRAME_SIZE)


func _draw() -> void:
	# Past the end of the sheet (e.g. frames deleted): use the last frame.
	var last := maxi(int(machine_art.get_width() / 16.0) - 1, 0)
	var m := Rect2(clampi(machine_frame, 0, last) * 16, 0, 16, 16)
	draw_texture_rect_region(machine_art, Rect2(-8, -16, 16, 16), m)


func _fog_offset(side: Vector2i) -> Vector2:
	match side:
		Vector2i.RIGHT:
			return fog_offset_right
		Vector2i.UP:
			return fog_offset_up
		Vector2i.LEFT:
			return fog_offset_left
	return fog_offset_down


## The tiles the fog fills, in world space (for tests and debugging).
func get_fog_rects() -> Array[Rect2]:
	return _fog_rects
