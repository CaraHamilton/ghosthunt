class_name ResidueGlow
extends Node2D
## The green glow of ghost residue on an interactable. It's always there once
## a residue-leaving ghost has touched the object, but it's drawn "light
## only" on its own light mask layer (UVBeam.RESIDUE_LIGHT_LAYER), so it's
## invisible until the UV light's beam falls on it - and only the part of it
## inside the beam shows. Placeholder art: soft blob plus a few smudged prints.

var _t := 0.0


func _ready() -> void:
	z_index = 6  # over furniture
	light_mask = 1 << (UVBeam.RESIDUE_LIGHT_LAYER - 1)
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_LIGHT_ONLY
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
