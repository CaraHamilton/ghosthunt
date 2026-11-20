class_name RitualCutscene
extends Node2D
## The ritual cutscene (scenes/ritual_cutscene.tscn). Game puts one where
## the ghost will appear, a little in front of the player, when they answer
## Yes to "Use the X Potion?", and plays its animations:
##   build   - always first: the circle draws itself, and the ghost is
##             pulled in by the summon_ghost key (until then it carries on
##             as normal - even hunting). Its length is how long the ritual
##             takes.
##   success - the right potion: the ghost is calmed. The win screen shows
##             when it ends.
##   fail    - the wrong potion: the ghost attacks (game over when it
##             reaches the player).
##   fizzle  - not in the ghost's favourite room (or outside, like the
##             trailer): plays instead of build, and the player can move
##             again when it ends.
##
## Edit them in the Animation panel: select the AnimationPlayer node. The
## node's origin is the ghost's feet (fizzle: where they would be). Floor art
## goes a little above the origin (y below 0) so it's drawn behind the ghost
## - see the Circle node.
##
## The animations can also call the functions below with a Call Method
## track on this node (summon the ghost, calm it, play sounds...), and key
## camera_zoom and camera_shake to move the camera.

## The camera's zoom while the cutscene plays, times this: 1 = normal, 1.25
## = a quarter closer. (Steps of 1/3 - 1.333, 1.667, 2 - keep the pixels
## crisp; anything in between shimmers a little while moving.)
@export var camera_zoom := 1.0
## How far (px) the camera shakes: 0 = still.
@export var camera_shake := 0.0

var _camera: Camera2D
var _camera_zoom := Vector2.ONE
var _camera_offset := Vector2.ZERO

@onready var animation_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	_camera = get_viewport().get_camera_2d()
	if _camera:
		_camera_zoom = _camera.zoom
		_camera_offset = _camera.offset


func _process(_delta: float) -> void:
	if _camera == null:
		return
	_camera.zoom = _camera_zoom * camera_zoom
	var shake := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * camera_shake
	_camera.offset = _camera_offset + shake.round()


func _exit_tree() -> void:
	if is_instance_valid(_camera):
		_camera.zoom = _camera_zoom
		_camera.offset = _camera_offset


## Plays `animation`; await it to wait until it's finished.
func play(animation: StringName) -> void:
	animation_player.play(animation)
	await animation_player.animation_finished


# --- Called from the animations (Call Method tracks) ---------------------------

## Plays a sound effect by name, e.g. "ritual/start" (see audio/sfx/README.md).
func play_sound(sound: String) -> void:
	Sfx.play(sound, global_position)


## The ghost is pulled into the ritual: whatever it was doing stops (a hunt
## too), and it fades in here (in the middle of the circle), facing the
## player. Until this key, it carries on as normal.
func summon_ghost() -> void:
	var game := Game.current
	if game.is_game_over:
		return
	game.ghost.begin_ritual()
	game.ghost.appear_for_ritual(global_position, game.player.global_position)


## The ghost flares white and turns into its calmed form over `time` seconds.
func calm_ghost(time: float) -> void:
	Game.current.ghost.calm(time)


## The ghost flies at the player (game over when it reaches them).
func ghost_attack() -> void:
	Game.current.ghost.ritual_attack(Game.current.player.global_position)
