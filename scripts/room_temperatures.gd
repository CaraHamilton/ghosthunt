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
## The temperature (°C) the favourite room heads towards while the ghost is in it.
@export var ghost_cold_temperature := 3.0
## The temperature (°C) any other room heads towards while the ghost is in it.
@export var passing_cold_temperature := 10.0
## The favourite room never warms above this (°C): a lingering chill.
@export var favorite_room_rest_temperature := 12.0
## How quickly a room cools while the ghost is in it (fraction of the gap
## closed per second).
@export var cooling_rate := 0.03
## How quickly a room warms back up once the ghost has left.
@export var warming_rate := 0.01
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
	for room in House.ROOMS:
		_base[room] = base_temperature + randf_range(-base_variation, base_variation)
		_temps[room] = _base[room]
	var fav: String = ghost.favorite_room
	_temps[fav] = lerpf(_rest_target(fav), _cold_target(fav), favorite_room_head_start)


func _process(delta: float) -> void:
	if ghost == null:
		return
	var ghost_room := house.room_at(ghost.global_position)
	for room in _temps:
		var target: float
		var rate: float
		if room == ghost_room:
			target = _cold_target(room)
			rate = cooling_rate
		else:
			target = _rest_target(room)
			rate = warming_rate
		_temps[room] += (target - _temps[room]) * (1.0 - exp(-rate * delta))


func get_temperature(room: String) -> float:
	return _temps.get(room, base_temperature)


## What a room cools towards while the ghost is in it.
func _cold_target(room: String) -> float:
	var cold := ghost_cold_temperature if room == ghost.favorite_room else passing_cold_temperature
	return ghost.behavior.get_cold_temperature(cold)


## What a room warms back up to once the ghost leaves.
func _rest_target(room: String) -> float:
	if room == ghost.favorite_room:
		return minf(_base[room], favorite_room_rest_temperature)
	return _base[room]
