class_name RitualCircle
extends Node2D
## Placeholder art for the ritual (see Game.start_ritual): a glowing circle on
## the floor around the player that draws itself in over `build_time`
## seconds, pulsing faster as it goes, with runes turning around it.
##
## The node sits a little above the player's feet so it sorts behind them,
## and draws `FEET_OFFSET` lower to land on the floor under them.

const FEET_OFFSET := 12.0
const RADIUS := 22.0
const COLOR := Color(0.75, 0.55, 1.0)

## Seconds the circle takes to finish drawing itself.
var build_time := 5.0
var _time := 0.0
var _flash := 0.0
var _fading := false
## A purple glow so the circle (and the ghost) can be seen in the dark.
var _light: PointLight2D


func _ready() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 128
	texture.height = 128
	_light = PointLight2D.new()
	_light.texture = texture
	_light.color = COLOR
	_light.position = Vector2(0, FEET_OFFSET)
	add_child(_light)


func _process(delta: float) -> void:
	_time += delta
	_flash = maxf(0.0, _flash - delta * 2.0)
	var progress := clampf(_time / build_time, 0.0, 1.0)
	_light.energy = (lerpf(0.4, 1.2, progress) + _flash * 1.5) * modulate.a
	queue_redraw()


## A bright burst (the ritual's outcome).
func flash() -> void:
	_flash = 1.0


## Fades the circle away over `time` seconds, then frees it.
func fade_out(time: float) -> void:
	if _fading:
		return
	_fading = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, time)
	tween.tween_callback(queue_free)


func _draw() -> void:
	var progress := clampf(_time / build_time, 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(_time * lerpf(3.0, 14.0, progress))
	var glow := Color(COLOR, lerpf(0.35, 0.9, pulse) + _flash).lightened(_flash * 0.6)
	draw_set_transform(Vector2(0, FEET_OFFSET), 0.0, Vector2(1.0, 0.5))  # flat on the floor
	# Soft fill, the outer ring drawing itself in, and an inner ring.
	draw_circle(Vector2.ZERO, RADIUS, Color(COLOR, 0.12 + 0.25 * _flash))
	draw_arc(Vector2.ZERO, RADIUS, -PI / 2.0, -PI / 2.0 + TAU * progress, 48, glow, 2.0)
	draw_arc(Vector2.ZERO, RADIUS * 0.65, 0.0, TAU, 32, Color(glow, glow.a * progress), 1.0)
	# Runes (little diamonds) turning around the ring, appearing one by one.
	var runes := 6
	for i in runes:
		if float(i) / runes > progress:
			break
		var angle := _time * 0.8 + TAU * i / runes
		var p := Vector2.from_angle(angle) * RADIUS * 0.82
		draw_colored_polygon(PackedVector2Array([
			p + Vector2(0, -3), p + Vector2(2, 0), p + Vector2(0, 3), p + Vector2(-2, 0)]), glow)
	draw_set_transform(Vector2.ZERO)
