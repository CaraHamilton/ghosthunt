@tool
class_name Doll
extends GhostInteractable
## A doll sitting on the floor - the world version of a DollItem. Spawned
## when the player puts the doll down; E picks it back up. Only some ghost
## types (see GhostBehavior.possesses_doll) bother with it: when one is close
## by, it (invisibly) goes and stands on the doll and possesses it. The doll
## walks 1-3 tiles (see the Walking settings) and spends the rest of the
## possession sitting and blinking (sit_and_blink) - some before the walk,
## the rest after, split at random. The ghost moves along with it. On a
## table, or with no free floor tile next to it, it just sits and blinks.
## When the possession ends the doll goes still (sit). The ghost's last touch is kept on `item` so it survives being
## picked up. Ghosts never leave UV residue on the doll.

## The item this node represents (set before it's added to the scene).
var item: DollItem:
	set(value):
		item = value
		_last_interaction_time = item.last_ghost_touch_time

## How far (px) above its position the doll is drawn, when it's placed on a
## table (see ItemPickup.elevation). Set before adding it to the scene.
var elevation := 0.0

## How long (seconds) a possession lasts, picked at random each time.
@export var min_possess_time := 5.0
@export var max_possess_time := 10.0

@export_group("Walking")
## While possessed, the doll walks this many tiles (picked at random each
## time, fewer if it runs out of free floor), and sits and blinks for the
## rest of the possession.
@export var min_walk_tiles := 1
@export var max_walk_tiles := 3
## How fast (px/s) it walks. 16 = one tile a second.
@export var walk_speed := 16.0
## How fast (frames/s) the walk animations play.
@export var walk_fps := 8.0
## How fast (frames/s) sit_and_blink plays.
@export var blink_fps := 6.0
@export_group("")

## Animations built from doll_overworld.png when the scene's SpriteFrames
## doesn't have them: name -> (row, frame count). Rows are 32px tall, frames
## 16px wide, top row 0 - the order of the Aseprite tags.
const SHEET_ANIMS := {
	&"down_walk": Vector2i(2, 4),
	&"left_walk": Vector2i(3, 4),
	&"right_walk": Vector2i(4, 4),
	&"up_walk": Vector2i(5, 4),
	&"sit_and_blink": Vector2i(6, 7),
}
const SHEET_FRAME_SIZE := Vector2(16, 32)

## The ghost possessing the doll right now (null when it's just a doll).
var possessed_by: Ghost = null
var is_possessed: bool:
	get:
		return possessed_by != null

## True while it's walking (part of a possession).
var is_walking: bool:
	get:
		return not _walk_path.is_empty()

@onready var sprite: AnimatedSprite2D = $Sprite

## The tiles still to walk to this possession: House.get_place_spot
## dictionaries, the one it's heading to first.
var _walk_path: Array[Dictionary] = []
## Seconds left sitting and blinking before it sets off walking.
var _blink_before := 0.0


## Note: the doll's exported settings (footprint, solid, ghost_reach,
## cooldown...) are set in scenes/doll.tscn, not here, so the
## editor never copies stale values into other scenes.
func _init() -> void:
	can_have_residue = false


func _ready() -> void:
	super()
	if not Engine.is_editor_hint():
		# Always put down sitting, whichever animation the scene was saved on.
		_add_sheet_animations()
		sprite.play(&"sit")
		sprite.position.y -= elevation


func ghost_can_use(ghost: Ghost) -> bool:
	return ghost.behavior.possesses_doll()


## Not while it's already possessed (the cooldown counts from when the ghost
## lets go).
func can_ghost_interact() -> bool:
	return not is_possessed and super()


## The ghost is about to possess it (see Ghost._after_using).
func _on_ghost_interact(_ghost: Ghost) -> void:
	_save_traces()


## How long (seconds) the next possession lasts: random, min_possess_time to
## max_possess_time.
func random_possess_time() -> float:
	return randf_range(min_possess_time, max_possess_time)


## Called by the ghost once it's standing on the doll. `duration` is how
## long the possession will last: the time the walk doesn't take is spent
## sitting and blinking, a random part of it before the walk.
func on_possessed(ghost: Ghost, duration := 0.0) -> void:
	possessed_by = ghost
	_walk_path = _plan_walk()
	var walk_time := _walk_path.size() * SHEET_FRAME_SIZE.x / maxf(walk_speed, 0.01)
	_blink_before = randf() * maxf(duration - walk_time, 0.0) if is_walking else 0.0
	if is_walking and _blink_before <= 0.0:
		_start_step()
	else:
		sprite.play(&"sit_and_blink")


## Called by the ghost when the possession ends (or the doll is picked up).
func on_released() -> void:
	possessed_by = null
	if is_walking and _blink_before <= 0.0:
		# Cut short mid-step: finish on the tile it was heading to.
		global_position = _walk_path[0].position
	_walk_path.clear()
	_blink_before = 0.0
	sprite.play(&"sit")
	# The ghost was touching it until now: the cooldown counts from here.
	_last_interaction_time = Game.game_time()
	_save_traces()


func describe_last_interaction() -> String:
	return "possessed the doll"


func _on_player_interact(player: Player) -> void:
	if not player.pick_up(item):
		return
	if possessed_by:
		possessed_by.end_possession()
	queue_free()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if item:
		item.process_always(delta)
	if is_possessed and is_walking and _blink_before > 0.0:
		# Sitting and blinking for a while first.
		_blink_before -= delta
		if _blink_before <= 0.0:
			_start_step()
	elif is_possessed and is_walking:
		var target: Vector2 = _walk_path[0].position
		global_position = global_position.move_toward(target, walk_speed * delta)
		if global_position.distance_to(target) < 0.01:
			global_position = target
			_walk_path.pop_front()
			if is_walking:
				_start_step()
			else:
				sprite.play(&"sit_and_blink")


## Picks 1-3 free floor tiles to walk through, each next to the last (no
## diagonals, no going back). Stops early when there's nowhere left to go;
## empty on a table or when boxed in.
func _plan_walk() -> Array[Dictionary]:
	var path: Array[Dictionary] = []
	var house := Game.current.house if Game.current else null
	if house == null or elevation > 0.0:
		return path
	var cell: Vector2i = get_meta("place_tile", house.tile_at(global_position - Vector2(0, 2)))
	var visited := [cell]
	for i in randi_range(min_walk_tiles, max_walk_tiles):
		var next := {}
		var sides: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
		sides.shuffle()
		for side in sides:
			var c := cell + side
			if c in visited:
				continue
			var spot := house.get_place_spot(c, false)
			if spot.ok and not _player_on(spot.rect):
				next = spot
				break
		if next.is_empty():
			break
		path.append(next)
		visited.append(next.cell)
		cell = next.cell
	return path


## Heads for the next tile: it takes that tile now (so nothing else can be
## put there) and faces the way it's going.
func _start_step() -> void:
	var spot: Dictionary = _walk_path[0]
	set_meta("place_tile", spot.cell)
	set_meta("place_rect", spot.rect)
	var dir: Vector2 = spot.position - global_position
	var anim: StringName
	if absf(dir.x) > absf(dir.y):
		anim = &"right_walk" if dir.x > 0.0 else &"left_walk"
	else:
		anim = &"down_walk" if dir.y > 0.0 else &"up_walk"
	if sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)


func _player_on(rect: Rect2) -> bool:
	var player := Game.current.player if Game.current else null
	return player != null and rect.grow(2.0).has_point(player.global_position)


## Builds the walk and blink animations from doll_overworld.png (see
## SHEET_ANIMS) - unless the scene's SpriteFrames already has them, e.g. made
## in the editor.
func _add_sheet_animations() -> void:
	var frames := sprite.sprite_frames
	if frames == null or not frames.has_animation(&"sit") or frames.get_frame_count(&"sit") == 0:
		return
	var sit_frame := frames.get_frame_texture(&"sit", 0) as AtlasTexture
	if sit_frame == null:
		return
	frames = frames.duplicate()
	for anim: StringName in SHEET_ANIMS:
		if frames.has_animation(anim):
			continue
		var row_and_count: Vector2i = SHEET_ANIMS[anim]
		frames.add_animation(anim)
		frames.set_animation_speed(anim, blink_fps if anim == &"sit_and_blink" else walk_fps)
		frames.set_animation_loop(anim, true)
		for f in row_and_count.y:
			var tex := AtlasTexture.new()
			tex.atlas = sit_frame.atlas
			tex.region = Rect2(Vector2(f, row_and_count.x) * SHEET_FRAME_SIZE, SHEET_FRAME_SIZE)
			frames.add_frame(anim, tex)
	sprite.sprite_frames = frames


func _save_traces() -> void:
	if item:
		item.last_ghost_touch_time = _last_interaction_time
