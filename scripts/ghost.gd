class_name Ghost
extends CharacterBody2D
## A ghost that fades in, hunts the player through the house (pathfinding
## around walls and furniture), and gives up and fades away if the player hides.
## The node's origin is the floor point under the ghost.

signal caught_player
signal vanished

enum State { APPEARING, CHASING, SEARCHING, VANISHING }

@export var chase_speed := 62.0
@export var appear_time := 1.2
@export var search_time := 3.0
@export var catch_radius := 10.0
## How often (seconds) the ghost recalculates its path to the player.
@export var repath_interval := 0.25

var player: Player
var house: House
var state := State.APPEARING

var _state_time := 0.0
var _wander_target := Vector2.ZERO
var _path := PackedVector2Array()
var _path_target := Vector2.INF
var _repath_timer := 0.0
var _t := 0.0


func _ready() -> void:
	modulate.a = 0.0
	z_index = 10  # always float above furniture


func _physics_process(delta: float) -> void:
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
				# Prowl around the spot where the player was last seen.
				_wander_target = _random_point_near(player.global_position, 40.0)
			else:
				_follow_path_to(player.global_position, chase_speed, delta, true)
				if global_position.distance_to(player.global_position) < catch_radius:
					caught_player.emit()
					set_physics_process(false)

		State.SEARCHING:
			_follow_path_to(_wander_target, chase_speed * 0.4, delta, false)
			if global_position.distance_to(_wander_target) < 4.0:
				_wander_target = _random_point_near(global_position, 50.0)
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
	_path_target = Vector2.INF


## Walks along a grid path towards `target`; collision stops it from ever
## passing through walls even if the path is slightly off.
func _follow_path_to(target: Vector2, speed: float, delta: float, moving_target: bool) -> void:
	_repath_timer -= delta
	var stale := moving_target and _repath_timer <= 0.0
	if stale or not _path_target.is_equal_approx(target):
		_repath_timer = repath_interval
		_path_target = target
		_path = house.get_nav_path(global_position, target)
		if _path.size() > 0:
			_path.remove_at(0)  # the cell we're already standing in

	while _path.size() > 0 and global_position.distance_to(_path[0]) < 3.0:
		_path.remove_at(0)
	# Once the path runs out, close the last few pixels directly.
	var next := target if _path.is_empty() else _path[0]
	velocity = global_position.direction_to(next) * speed
	move_and_slide()


func _random_point_near(origin: Vector2, radius: float) -> Vector2:
	for i in 20:
		var p := origin + Vector2(randf_range(-radius, radius), randf_range(-radius, radius))
		if house.is_walkable(p):
			return p
	return global_position


# --- Placeholder art ------------------------------------------------------

func _draw() -> void:
	var bob := sin(_t * 3.0) * 2.0
	var body := Color(0.92, 0.95, 1.0)
	var center := Vector2(0, -12 + bob)  # float above the floor point

	# Faint shadow on the floor
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
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
