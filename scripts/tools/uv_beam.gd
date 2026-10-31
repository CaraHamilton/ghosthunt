class_name UVBeam
extends Node2D
## The UV light's beam: real lights shaped by a cone texture
## (res://art/uv_beam.png - white, pointing right, tip at the middle of the
## left edge). The UV tool moves it to the flashlight's lens and turns it to
## match facing.
##
## Two lights share the cone:
##   - a purple one that lights the room (floor, walls, furniture, ghost)
##   - a green-white one that only lights ghost residue (light mask layer 2,
##     see ResidueGlow), so residue glows exactly where the beam falls. The
##     lantern (LanternItem) doesn't reach layer 2, so it never shows residue.
## The cone skips the player (Player.LIGHT_LAYER) so it doesn't light her body
## in its pattern; a soft round glow tints her purple instead.

const CONE := preload("res://art/uv_beam.png")
## Light mask layer that only ghost residue is on.
const RESIDUE_LIGHT_LAYER := 2

var _room_light: PointLight2D
var _residue_light: PointLight2D
var _t := 0.0


func _ready() -> void:
	_room_light = _make_light(Color(0.6, 0.3, 1.0), 1.6, 1)
	_residue_light = _make_light(Color(0.75, 1.0, 0.8), 2.0, RESIDUE_LIGHT_LAYER)
	_add_player_glow()


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	var flicker := 0.94 + 0.06 * sin(_t * 23.0)
	_room_light.energy = 1.6 * flicker
	_residue_light.energy = 2.0 * flicker


func _make_light(color: Color, energy: float, cull_mask: int) -> PointLight2D:
	var light := PointLight2D.new()
	light.texture = CONE
	# Drawn at scale 1 (one cone pixel = one world pixel, like the other art),
	# so the beam reaches as far as the cone image is wide. The texture is
	# centred on the light: shift it so the cone's tip sits in the hand.
	light.offset = Vector2(CONE.get_width() / 2.0, 0)
	light.color = color
	light.energy = energy
	light.range_item_cull_mask = cull_mask
	add_child(light)
	return light


## The purple spill of the UV light on the player herself: an even, round
## glow (it doesn't turn with the beam).
func _add_player_glow() -> void:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color.BLACK])
	var glow := GradientTexture2D.new()
	glow.gradient = gradient
	glow.width = 64
	glow.height = 64
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5, 0.5)
	glow.fill_to = Vector2(0.5, 0.0)
	var light := PointLight2D.new()
	light.texture = glow  # centred on the hand, wide enough to cover all of her
	light.color = Color(0.6, 0.3, 1.0)
	light.energy = 1.2
	light.range_item_cull_mask = 1 << (Player.LIGHT_LAYER - 1)
	add_child(light)
