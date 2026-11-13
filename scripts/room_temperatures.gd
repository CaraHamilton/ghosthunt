class_name RoomTemperatures
extends Node
## Tracks the temperature of every room in the house. The room the ghost is
## in slowly cools down; every other room slowly warms back up. The ghost's
## favourite room gets the coldest (it chills further and never fully warms
## up), so it is reliably the coldest room - a clue the player can find with
## the thermometer. Other rooms still get noticeably cooler while the ghost
## passes through.
##
## Temperatures move exponentially towards their target (fast at first, then
## easing off), so readings drift gradually rather than jumping.

## Normal room temperature (°C). Each room gets a little random variation.
@export var base_temperature := 20.0
@export var base_variation := 0.8
## The coldest (°C) the favourite room of a ghost that isn't a freezing type
## gets while the ghost is in it - just above 0, so it's hard to tell from
## freezing at a glance. (Freezing types go below 0 instead - see
## GhostBehavior.get_cold_temperature.)
@export var ghost_cold_temperature := 1.0
## The temperature (°C) any other room heads towards while the ghost is in it.
@export var passing_cold_temperature := 10.0
## The favourite room never warms above this (°C): a lingering chill.
@export var favorite_room_rest_temperature := 12.0
## How quickly a room cools while the ghost is in it (fraction of the gap
## closed per second).
@export var cooling_rate := 0.03
## How quickly a room warms back up once the ghost has left.
@export var warming_rate := 0.01
## A cooling room aims this many °C past its cold temperature (then stops at
## it), so it actually gets there instead of creeping closer forever.
@export var cool_past_target := 2.0
## How far (0-1) towards cold the favourite room already is at the start,
## since the ghost has been haunting it before the player arrived.
@export var favorite_room_head_start := 0.6

var house: House
var ghost: Ghost

var _temps := {}
var _base := {}


## Call once the ghost has been placed.
func setup(new_house: House, new_ghost: Ghost) -> void:
	house = new_house
	ghost = new_ghost
	for room in house.get_room_names():
		_base[room] = base_temperature + randf_range(-base_variation, base_variation)
		_temps[room] = _base[room]
	var fav: String = ghost.favorite_room
	_temps[fav] = lerpf(_rest_target(fav), _cold_target(fav), favorite_room_head_start)


func _process(delta: float) -> void:
	if ghost == null:
		return
	var ghost_room := house.room_at(ghost.global_position)
	for room in _temps:
		if room == ghost_room:
			var cold := _cold_target(room)
			var before: float = _temps[room]
			var aim := cold - cool_past_target
			_temps[room] = before + (aim - before) * (1.0 - exp(-cooling_rate * delta))
			# Stop at the cold temperature (never warm a room that's already colder).
			_temps[room] = maxf(_temps[room], minf(cold, before))
		else:
			var target := _rest_target(room)
			_temps[room] += (target - _temps[room]) * (1.0 - exp(-warming_rate * delta))


func get_temperature(room: String) -> float:
	return _temps.get(room, base_temperature)


## What a room cools towards while the ghost is in it.
func _cold_target(room: String) -> float:
	var is_favorite := room == ghost.favorite_room
	var cold := ghost_cold_temperature if is_favorite else passing_cold_temperature
	return ghost.behavior.get_cold_temperature(cold, is_favorite)


## What a room warms back up to once the ghost leaves.
func _rest_target(room: String) -> float:
	if room == ghost.favorite_room:
		return minf(_base[room], favorite_room_rest_temperature)
	return _base[room]
