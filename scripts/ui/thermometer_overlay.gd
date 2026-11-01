extends Control
## The big thermometer on the right edge of the screen. It slides in while
## the player is using a thermometer and slides back out when they stop. The
## liquid column shows that thermometer's reading - there's no number, so
## the player has to read it off the scale.
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
## Gap between the thermometer and the right edge of the screen (screen px).
const EDGE_GAP := 16.0
## Seconds to slide in or out.
const SLIDE_TIME := 0.15

var player: Player

## 0 = hidden off the right edge, 1 = fully on screen.
var _shown := 0.0
var _reading := NAN


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	custom_minimum_size = ART.get_size()
	size = ART.get_size()


func _process(delta: float) -> void:
	var item := player.selected_item if player else null
	var using := player != null and player.is_using_item and item is Thermometer
	if using:
		_reading = item.reading
	_shown = move_toward(_shown, 1.0 if using else 0.0, delta / SLIDE_TIME)
	visible = _shown > 0.0
	# Slide in from past the right edge.
	position.x = get_parent_area_size().x - (size.x + EDGE_GAP) * ease(_shown, 0.4)
	queue_redraw()


func _draw() -> void:
	draw_texture(ART, Vector2.ZERO)
	if is_nan(_reading):
		return
	# Snap the top of the liquid to whole art pixels, like the rest of the art.
	var level := clampf(ZERO_Y - _reading * PIXELS_PER_DEGREE, TUBE.position.y, TUBE.end.y)
	var top := floorf(level)
	var liquid := Rect2(TUBE.position.x, top, TUBE.size.x, TUBE.end.y - top)
	draw_rect(Rect2(liquid.position * ART_SCALE, liquid.size * ART_SCALE), LIQUID_COLOR)
