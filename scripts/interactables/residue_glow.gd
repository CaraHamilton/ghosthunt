class_name ResidueGlow
extends Node2D
## The green glow of ghost residue on an interactable. It's always there once
## a residue-leaving ghost has touched the object, but it's drawn "light
## only" on its own light mask layer (UVBeam.RESIDUE_LIGHT_LAYER), so it's
## invisible until the UV light's beam falls on it - and only the part of it
## inside the beam shows.
##
## Draws `texture` centred on its position (the object's residue art, or the
## default DEFAULT_ART). The picture's own colours are what glows: draw it in
## bright greens on a transparent background. Dark pixels barely show (the
## glow is added on top of what's under it). Without any art it falls back to
## a placeholder blob of smudged prints.

## Used when an object has no residue art of its own (if the file exists).
const DEFAULT_ART := "res://art/uv_residue/handprint_default.png"

## The residue picture (null = the default art, or the placeholder).
var texture: Texture2D
## Mirror the picture left-right.
var flip_h := false

var _t := 0.0


func _ready() -> void:
	z_index = 6  # over furniture
	light_mask = 1 << (UVBeam.RESIDUE_LIGHT_LAYER - 1)
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_LIGHT_ONLY
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	if texture == null and ResourceLoader.exists(DEFAULT_ART):
		texture = load(DEFAULT_ART)


func _process(delta: float) -> void:
	if visible:
		_t += delta
		queue_redraw()


func _draw() -> void:
	var pulse := 0.85 + 0.15 * sin(_t * 4.0)
	if texture:
		draw_art(self, texture, Vector2.ZERO, flip_h, Color(1, 1, 1, pulse))
		return
	var green := Color(0.35, 1.0, 0.45)
	# Placeholder: soft glow
	for i in 4:
		var r := 7.0 - i * 1.5
		draw_circle(Vector2.ZERO, r, Color(green, 0.12 * pulse))
	# Smudged finger marks
	for p: Vector2 in [Vector2(-3, -1), Vector2(-1, -2.5), Vector2(1.5, -2.5), Vector2(3.5, -1), Vector2(0, 1.5)]:
		draw_circle(p, 0.9, Color(green, 0.75 * pulse))


## Draws residue art on `canvas` centred on `at` (also used for the editor
## preview). Snapped to whole pixels so pixel art stays crisp.
static func draw_art(canvas: CanvasItem, art: Texture2D, at: Vector2, flip: bool, tint: Color) -> void:
	var size := art.get_size()
	var corner := (at - size / 2.0).floor()
	if flip:
		canvas.draw_set_transform(Vector2(corner.x + size.x, corner.y), 0.0, Vector2(-1, 1))
		canvas.draw_texture(art, Vector2.ZERO, tint)
		canvas.draw_set_transform(Vector2.ZERO)
	else:
		canvas.draw_texture(art, corner, tint)
