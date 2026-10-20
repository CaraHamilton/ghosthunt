class_name Ghost
extends Node2D
## A ghost that fades in, chases the player straight through walls, and gives
## up and fades away if the player hides.

signal caught_player
signal vanished

enum State { APPEARING, CHASING, SEARCHING, VANISHING }

@export var chase_speed := 62.0
@export var appear_time := 1.2
@export var search_time := 3.0
@export var catch_radius := 9.0

var player: Player
var state := State.APPEARING

var _state_time := 0.0
var _wander_target := Vector2.ZERO
var _t := 0.0


func _ready() -> void:
	modulate.a = 0.0
	z_index = 10  # always float above furniture


func _process(delta: float) -> void:
	_t += delta
	_state_time += delta

	match state:
		State.APPEARING:
			modulate.a = clampf(_state_time / appear_time, 0.0, 1.0) * 0.85
			if _state_time >= appear_time:
				_set_state(State.CHASING)

		State.CHASING:
			if player.is_hidden:
				_set_state(State.SEARCHING)
				# Drift around the spot where the player was last seen.
				_wander_target = global_position + (player.global_position - global_position) * 0.6
			else:
				_move_toward(player.global_position + Vector2(0, -8), chase_speed, delta)
				if global_position.distance_to(player.global_position + Vector2(0, -8)) < catch_radius:
					caught_player.emit()
					set_process(false)

		State.SEARCHING:
			_move_toward(_wander_target, chase_speed * 0.4, delta)
			if global_position.distance_to(_wander_target) < 4.0:
				_wander_target = global_position + Vector2(randf_range(-40, 40), randf_range(-30, 30))
			if not player.is_hidden and _state_time < search_time:
				# Player came out too early - the hunt is back on!
				_set_state(State.CHASING)
			elif _state_time >= search_time:
				_set_state(State.VANISHING)

		State.VANISHING:
			modulate.a = maxf(0.0, 0.85 - _state_time)
			if modulate.a <= 0.0:
				vanished.emit()
				queue_free()

	queue_redraw()


func _set_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0


func _move_toward(target: Vector2, speed: float, delta: float) -> void:
	global_position = global_position.move_toward(target, speed * delta)


# --- Placeholder art ------------------------------------------------------

func _draw() -> void:
	var bob := sin(_t * 3.0) * 2.0
	var body := Color(0.92, 0.95, 1.0)
	var center := Vector2(0, bob)

	# Faint shadow on the floor
	draw_set_transform(Vector2(0, 10), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 7.0, Color(0, 0, 0, 0.2))
	draw_set_transform(Vector2.ZERO)

	# Round head + body
	draw_circle(center + Vector2(0, -4), 9.0, body)
	draw_rect(Rect2(center + Vector2(-9, -4), Vector2(18, 10)), body)
	# Wavy tail
	var pts := PackedVector2Array()
	for i in 7:
		var x := -9.0 + i * 3.0
		var y := 6.0 + (2.5 if i % 2 == 0 else 0.0) + sin(_t * 6.0 + i) * 1.0
		pts.append(center + Vector2(x, y))
	pts.append(center + Vector2(9, 5))
	pts.append(center + Vector2(-9, 5))
	draw_colored_polygon(pts, body)

	# Eyes and mouth - angrier while chasing
	var eye := Color("1b1530")
	if state == State.CHASING:
		draw_rect(Rect2(center + Vector2(-5, -6), Vector2(3, 4)), eye)
		draw_rect(Rect2(center + Vector2(2, -6), Vector2(3, 4)), eye)
		draw_circle(center + Vector2(0, 1), 2.5, eye)
	else:
		draw_rect(Rect2(center + Vector2(-5, -5), Vector2(3, 2)), eye)
		draw_rect(Rect2(center + Vector2(2, -5), Vector2(3, 2)), eye)
