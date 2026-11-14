class_name Thermometer
extends ItemInstance
## Reads the temperature of the room it's in. Each thermometer keeps its own
## reading and measures constantly - in your pocket or lying on the floor -
## so you can leave one in a room and come back to read it. Using it shows
## the big thermometer on screen (ThermometerOverlay), with no number - the
## player reads it off the scale. Like a real thermometer it takes a while
## to settle: the reading creeps towards the room's temperature, quicker
## when far off and slowing as it gets close (20 °C -> 5 °C takes ~20 s to
## settle).

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
	var pos := get_world_position()
	var actual: float
	var outside := game.outside_area_at(pos)
	if outside:
		actual = outside.temperature  # out in the yard
	else:
		# In a doorway, keep reading the last room it was in.
		var room := game.house.room_at(pos)
		if room != "":
			_room = room
		if _room == "":
			return
		actual = game.temperatures.get_temperature(_room)
	if is_nan(reading):
		reading = actual
	var step := (actual - reading) * (1.0 - exp(-response_rate * delta))
	reading += clampf(step, -max_change_per_second * delta, max_change_per_second * delta)
