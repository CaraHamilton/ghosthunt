class_name Thermometer
extends Tool
## Reads the temperature of the room the player is standing in. It measures
## constantly (in use or not); using it just shows the number. Like a real
## thermometer it takes a while to settle: the number creeps towards the
## room's temperature, quicker when far off and slowing as it gets close
## (e.g. walking from a 20 °C room into a 5 °C one takes ~20 s to settle).

## How quickly the reading closes the gap to the real temperature (fraction
## of the remaining gap per second). Lower = slower, more sluggish sensor.
var response_rate := 0.15
## Fastest the displayed number can ever change, in °C per second.
var max_change_per_second := 0.8

var _house: House
var _temperatures: RoomTemperatures
var _room := ""
var _reading := NAN


func _init(house: House, temperatures: RoomTemperatures) -> void:
	display_name = "Thermometer"
	_house = house
	_temperatures = temperatures


## The sensor keeps measuring even while the thermometer is put away, so
## taking it out shows an up-to-date (but still settling) reading.
func process_always(delta: float) -> void:
	# In a doorway, keep reading the last room we were in.
	var room := _house.room_at(player.global_position)
	if room != "":
		_room = room
	if _room == "":
		return
	var actual := _temperatures.get_temperature(_room)
	if is_nan(_reading):
		_reading = actual
	var step := (actual - _reading) * (1.0 - exp(-response_rate * delta))
	_reading += clampf(step, -max_change_per_second * delta, max_change_per_second * delta)


func get_readout() -> String:
	if is_nan(_reading):
		return "--.- °C"
	return "%.1f °C" % _reading


func draw_icon(canvas: CanvasItem, rect: Rect2) -> void:
	var c := rect.get_center()
	var h := rect.size.y * 0.6
	var tube := Rect2(c.x - 4, c.y - h / 2.0, 8, h)
	canvas.draw_rect(tube, Color("e8e8f0"))
	canvas.draw_rect(tube, Color("50506a"), false, 2.0)
	canvas.draw_circle(Vector2(c.x, tube.end.y), 8.0, Color("50506a"))
	canvas.draw_circle(Vector2(c.x, tube.end.y), 6.0, Color("d8403a"))
	canvas.draw_rect(Rect2(c.x - 2, c.y - 2, 4, h / 2.0 + 2), Color("d8403a"))
