class_name Thermometer
extends ItemInstance
## Reads the temperature of the room it's in. Each thermometer keeps its own
## reading and measures constantly - in your pocket or lying on the floor -
## so you can leave one in a room and come back to read it. Using it just
## shows the number. Like a real thermometer it takes a while to settle: the
## number creeps towards the room's temperature, quicker when far off and
## slowing as it gets close (20 °C -> 5 °C takes ~20 s to settle).

## How quickly the reading closes the gap to the real temperature (fraction
## of the remaining gap per second). Lower = slower, more sluggish sensor.
var response_rate := 0.15
## Fastest the displayed number can ever change, in °C per second.
var max_change_per_second := 0.8

## This thermometer's current reading (NAN until it first measures).
var reading := NAN

var _room := ""


func process_always(delta: float) -> void:
	var game := Game.current
	if game == null:
		return
	# In a doorway, keep reading the last room it was in.
	var room := game.house.room_at(get_world_position())
	if room != "":
		_room = room
	if _room == "":
		return
	var actual := game.temperatures.get_temperature(_room)
	if is_nan(reading):
		reading = actual
	var step := (actual - reading) * (1.0 - exp(-response_rate * delta))
	reading += clampf(step, -max_change_per_second * delta, max_change_per_second * delta)


func get_readout() -> String:
	if is_nan(reading):
		return "--.- °C"
	return "%.1f °C" % reading


func draw_icon(canvas: CanvasItem, rect: Rect2) -> void:
	if data.icon:
		super(canvas, rect)
		return
	var c := rect.get_center()
	var s := rect.size.x / 44.0  # placeholder was designed for a 44px slot
	var h := rect.size.y * 0.6
	var tube := Rect2(c.x - 4 * s, c.y - h / 2.0, 8 * s, h)
	canvas.draw_rect(tube, Color("e8e8f0"))
	canvas.draw_rect(tube, Color("50506a"), false, 2.0 * s)
	canvas.draw_circle(Vector2(c.x, tube.end.y), 8.0 * s, Color("50506a"))
	canvas.draw_circle(Vector2(c.x, tube.end.y), 6.0 * s, Color("d8403a"))
	canvas.draw_rect(Rect2(c.x - 2 * s, c.y - 2 * s, 4 * s, h / 2.0 + 2 * s), Color("d8403a"))
