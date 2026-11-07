class_name PlayerLight
extends PointLight2D
## The one light that lights the player's sprite. World lights (the lantern,
## fireplaces...) only light the world; each frame this copies whichever of
## them is brightest where she's standing. So standing in two lights at once
## lights her as much as the brighter one, not both added together.
##
## A light counts as a world light if it's in the "world_lights" group (Node
## tab > Groups in the editor). Its light mask should be just layer 1, so it
## doesn't also light her directly.

const GROUP := &"world_lights"
## Where on the player the lights are measured (about her middle).
const SAMPLE_OFFSET := Vector2(0, -12)

## Each light texture's pixels, for measuring how bright it is at a point.
static var _images := {}


func _ready() -> void:
	# An even light big enough to cover her and the item in her hand.
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	texture = ImageTexture.create_from_image(img)
	texture_scale = 16.0
	position = SAMPLE_OFFSET
	range_item_cull_mask = 1 << (Player.LIGHT_LAYER - 1)


func _process(_delta: float) -> void:
	var best := Color.BLACK
	for light: PointLight2D in get_tree().get_nodes_in_group(GROUP):
		var c := _light_at(light, global_position)
		if c.get_luminance() > best.get_luminance():
			best = c
	color = best
	energy = 1.0
	visible = best.get_luminance() > 0.0


## How much `light` lights `point` (its colour x energy x texture there).
func _light_at(light: PointLight2D, point: Vector2) -> Color:
	if not light.enabled or not light.is_visible_in_tree() or light.texture == null:
		return Color.BLACK
	var size := light.texture.get_size() * light.texture_scale
	var uv := (light.global_transform.affine_inverse() * point - light.offset) / size + Vector2(0.5, 0.5)
	if uv.x < 0.0 or uv.y < 0.0 or uv.x >= 1.0 or uv.y >= 1.0:
		return Color.BLACK
	var img: Image = _images.get(light.texture)
	if img == null:
		img = light.texture.get_image()
		_images[light.texture] = img
	var t := img.get_pixelv(Vector2i(uv * Vector2(img.get_size())))
	var k := t.a * light.color.a * light.energy
	return Color(t.r * light.color.r * k, t.g * light.color.g * k, t.b * light.color.b * k)
