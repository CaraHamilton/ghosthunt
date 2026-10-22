class_name UVBeam
extends Node2D
## The purple cone of the UV light, drawn in front of the player. Unshaded
## so it shows up in the dark. Rotated by the UV tool to match facing.

var beam_range := 50.0
var beam_half_angle := 28.0

var _t := 0.0


func _ready() -> void:
	position = Vector2(0, -6)  # roughly hand height
	z_index = 5
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat


func _process(delta: float) -> void:
	if visible:
		_t += delta
		queue_redraw()


func _draw() -> void:
	var flicker := 0.92 + 0.08 * sin(_t * 23.0)
	var core := Color(0.55, 0.25, 1.0, 0.32 * flicker)
	var edge := Color(0.55, 0.25, 1.0, 0.0)
	var half := deg_to_rad(beam_half_angle)
	var steps := 10
	var points := PackedVector2Array([Vector2.ZERO])
	var colors := PackedColorArray([core])
	for i in steps + 1:
		var a := -half + 2.0 * half * i / steps
		points.append(Vector2.from_angle(a) * beam_range)
		colors.append(edge)
	draw_polygon(points, colors)
	# Brighter inner cone
	var inner := PackedVector2Array([Vector2.ZERO,
		Vector2.from_angle(-half * 0.45) * beam_range * 0.8,
		Vector2.from_angle(half * 0.45) * beam_range * 0.8])
	draw_polygon(inner, PackedColorArray([Color(0.7, 0.45, 1.0, 0.25 * flicker), edge, edge]))
