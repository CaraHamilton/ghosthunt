class_name ResidueGlow
extends Node2D
## The faint green glow of ghost residue, shown on an interactable only while
## the player's UV light is shining on it. Drawn unshaded so it glows even in
## the dark house. Placeholder art: soft blob plus a few smudged prints.

var _t := 0.0


func _ready() -> void:
	z_index = 6  # over the UV beam and furniture
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat


func _process(delta: float) -> void:
	if visible:
		_t += delta
		queue_redraw()


func _draw() -> void:
	var pulse := 0.85 + 0.15 * sin(_t * 4.0)
	var green := Color(0.35, 1.0, 0.45)
	# Soft glow
	for i in 4:
		var r := 7.0 - i * 1.5
		draw_circle(Vector2.ZERO, r, Color(green, 0.12 * pulse))
	# Smudged finger marks
	for p in [Vector2(-3, -1), Vector2(-1, -2.5), Vector2(1.5, -2.5), Vector2(3.5, -1), Vector2(0, 1.5)]:
		draw_circle(p, 0.9, Color(green, 0.75 * pulse))
