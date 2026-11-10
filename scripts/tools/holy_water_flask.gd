class_name HolyWaterFlask
extends Node2D
## A thrown flask of holy water (see HolyWaterItem). It flies in an arc from
## `start` to `target`, then shatters: anything in the SPLASH_SIZE square
## around `target` is splashed. If that includes the ghost while it's
## visible, Ghost.hit_with_holy_water() decides whether it reacts.
##
## Art (optional - simple shapes are drawn until it's set):
##   flask_art  - 16x16 frames, looped while it flies (centred on the flask).
##                A single frame is spun in quarter turns instead.
##   splash_art - 32x32 frames, played once where it lands (centred on it)

## Throw speed (px per second along the ground).
const SPEED := 260.0
## How high (px) the arc rises at its middle, per 100px thrown.
const ARC_HEIGHT := 14.0
const FLASK_FRAME := Vector2(16, 16)
const SPLASH_FRAME := Vector2(32, 32)

@export var flask_art: Texture2D
@export var splash_art: Texture2D
## Seconds per frame of the flask's spin.
@export var flask_frame_time := 0.08
## Turns per second when flask_art is a single frame (0 = no spin).
@export var flask_spin := 2.0
## Seconds per frame of the splash (also how long the placeholder lasts:
## 5 frames' worth).
@export var splash_frame_time := 0.08

## Where it's thrown from and lands, in world space. Set before adding it.
var start := Vector2.ZERO
var target := Vector2.ZERO

var _flight_time := 0.0
var _time := 0.0
var _landed := false
var _height := 0.0   # px above the ground right now


func _ready() -> void:
	_flight_time = maxf(start.distance_to(target) / SPEED, 0.12)
	global_position = start
	# Above everything while it's in the air; Y-sorted once it lands.
	z_index = 1


func _process(delta: float) -> void:
	_time += delta
	if not _landed:
		var t := minf(_time / _flight_time, 1.0)
		# The node follows the ground under the flask (for Y-sorting); the
		# flask itself is drawn `_height` above it.
		var ground_start := start - HolyWaterItem.HAND_OFFSET
		var ground := ground_start.lerp(target, t)
		var arc := ARC_HEIGHT * start.distance_to(target) / 100.0
		_height = lerpf(-HolyWaterItem.HAND_OFFSET.y, 0.0, t) + 4.0 * arc * t * (1.0 - t)
		global_position = ground
		if t >= 1.0:
			_land()
	elif _time >= _splash_length():
		queue_free()
	queue_redraw()


func _land() -> void:
	_landed = true
	_time = 0.0
	_height = 0.0
	z_index = 0
	global_position = target
	var splash := Rect2(target - HolyWaterItem.SPLASH_SIZE / 2.0, HolyWaterItem.SPLASH_SIZE)
	var ghost := Game.current.ghost if Game.current else null
	if is_instance_valid(ghost):
		# Its feet or the middle of its body counts.
		var feet := ghost.global_position
		if splash.has_point(feet) or splash.has_point(feet + Vector2(0, -12)):
			ghost.hit_with_holy_water()


func _splash_length() -> float:
	var frames := 5
	if splash_art:
		frames = maxi(int(splash_art.get_width() / SPLASH_FRAME.x), 1)
	return frames * splash_frame_time


func _draw() -> void:
	if not _landed:
		var at := Vector2(0, -_height).round()
		if flask_art:
			var frames := maxi(int(flask_art.get_width() / FLASK_FRAME.x), 1)
			var f := int(_time / flask_frame_time) % frames
			if frames == 1 and flask_spin > 0.0:
				# Quarter turns keep the pixels crisp.
				var quarter := int(_time * flask_spin * 4.0) % 4
				draw_set_transform(at, quarter * PI / 2.0)
				at = Vector2.ZERO
			draw_texture_rect_region(flask_art, Rect2(at - FLASK_FRAME / 2.0, FLASK_FRAME),
				Rect2(Vector2(f * FLASK_FRAME.x, 0), FLASK_FRAME))
			draw_set_transform(Vector2.ZERO)
		else:
			# Placeholder: a little spinning bottle.
			draw_set_transform(at, _time * 14.0)
			draw_rect(Rect2(-2, -3, 4, 6), Color(0.75, 0.9, 1.0))
			draw_rect(Rect2(-1, -5, 2, 2), Color(0.55, 0.45, 0.35))
			draw_set_transform(Vector2.ZERO)
		# Shadow on the ground under it.
		draw_circle(Vector2.ZERO, 2.0, Color(0, 0, 0, 0.3))
		return
	if splash_art:
		var frames := maxi(int(splash_art.get_width() / SPLASH_FRAME.x), 1)
		var f := mini(int(_time / splash_frame_time), frames - 1)
		draw_texture_rect_region(splash_art, Rect2(-SPLASH_FRAME / 2.0, SPLASH_FRAME),
			Rect2(Vector2(f * SPLASH_FRAME.x, 0), SPLASH_FRAME))
	else:
		# Placeholder: droplets bursting out to the edge of the splash.
		var k := clampf(_time / _splash_length(), 0.0, 1.0)
		var col := Color(0.7, 0.9, 1.0, 1.0 - k)
		for i in 8:
			var dir := Vector2.RIGHT.rotated(TAU * i / 8.0)
			draw_circle((dir * 15.0 * k * Vector2(1, 0.6)).round(), 1.5, col)
		draw_circle(Vector2.ZERO, 3.0 * (1.0 - k), col)
