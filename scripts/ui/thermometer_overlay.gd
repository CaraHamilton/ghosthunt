extends ToolOverlay
## The big thermometer on the right edge of the screen, shown while the
## player is using a thermometer (see ToolOverlay). The liquid column shows
## that thermometer's reading - there's no number, so the player has to read
## it off the scale.
##
## The glass, scale and bulb are res://art/thermometer_overlay.png, exported
## at 3x. The constants below say where the tube and scale are in that art,
## in its 1x pixels, so if you redraw it, update them to match.

const ART := preload("res://art/thermometer_overlay.png")
## How much bigger the art is drawn than its Aseprite pixels.
const ART_SCALE := 3.0
const LIQUID_COLOR := Color("910c0c")
## The inside of the tube that the liquid fills (the bulb starts at its bottom).
const TUBE := Rect2(18, 6, 4, 100)
## Height of the 0 mark on the scale (the middle of its tick).
const ZERO_Y := 79.5
## How many pixels the liquid rises per °C (10 °C between labels = 20 px).
const PIXELS_PER_DEGREE := 2.0

var _reading := NAN


func _is_for(item: ItemInstance) -> bool:
	return item is Thermometer


func _read(item: ItemInstance) -> void:
	_reading = (item as Thermometer).reading


func _art_size() -> Vector2:
	return ART.get_size()


func _draw() -> void:
	draw_texture(ART, Vector2.ZERO)
	if is_nan(_reading):
		return
	# Snap the top of the liquid to whole art pixels, like the rest of the art.
	var level := clampf(ZERO_Y - _reading * PIXELS_PER_DEGREE, TUBE.position.y, TUBE.end.y)
	var top := floorf(level)
	var liquid := Rect2(TUBE.position.x, top, TUBE.size.x, TUBE.end.y - top)
	draw_rect(Rect2(liquid.position * ART_SCALE, liquid.size * ART_SCALE), LIQUID_COLOR)
