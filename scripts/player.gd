class_name Player
extends CharacterBody2D
## Top-down player. Walks with WASD/arrows, runs with Shift, and hides in
## nearby HidingSpots with E/Space.

signal hidden_changed(is_hidden: bool)

@export var walk_speed := 70.0
@export var run_speed := 115.0

var is_hidden := false
var is_dead := false
var facing := Vector2.DOWN

## Hiding spots the player is currently standing next to.
var _nearby_spots: Array[HidingSpot] = []
var _current_spot: HidingSpot = null
var _walk_time := 0.0


func _physics_process(delta: float) -> void:
	if is_dead or is_hidden:
		velocity = Vector2.ZERO
		return

	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var speed := run_speed if Input.is_action_pressed("run") else walk_speed
	velocity = input * speed
	move_and_slide()

	if input != Vector2.ZERO:
		facing = input.normalized()
		_walk_time += delta * (speed / walk_speed)
	else:
		_walk_time = 0.0
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if is_dead or not event.is_action_pressed("interact"):
		return
	if is_hidden:
		leave_hiding_spot()
	else:
		var spot := _closest_spot()
		if spot:
			enter_hiding_spot(spot)
	get_viewport().set_input_as_handled()


func enter_hiding_spot(spot: HidingSpot) -> void:
	_current_spot = spot
	is_hidden = true
	visible = false
	spot.set_occupied(true)
	hidden_changed.emit(true)


func leave_hiding_spot() -> void:
	if _current_spot:
		_current_spot.set_occupied(false)
		# Step out in front of the furniture.
		global_position = _current_spot.get_exit_position()
	_current_spot = null
	is_hidden = false
	visible = true
	hidden_changed.emit(false)


func die() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	queue_redraw()


func register_spot(spot: HidingSpot) -> void:
	if spot not in _nearby_spots:
		_nearby_spots.append(spot)


func unregister_spot(spot: HidingSpot) -> void:
	_nearby_spots.erase(spot)


func _closest_spot() -> HidingSpot:
	var best: HidingSpot = null
	var best_dist := INF
	for spot in _nearby_spots:
		var d := global_position.distance_squared_to(spot.global_position)
		if d < best_dist:
			best_dist = d
			best = spot
	return best


# --- Placeholder art: swap this for an AnimatedSprite2D once you have sprites.

func _draw() -> void:
	var bob := -absf(sin(_walk_time * 10.0)) * 1.5
	var skin := Color("f2c49b")
	var shirt := Color("3f7fbf") if not is_dead else Color("6a6a7a")
	var hair := Color("6b3f22")

	# Shadow
	draw_set_transform(Vector2(0, 0), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 6.0, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO)

	# Legs
	var step := sin(_walk_time * 10.0) * 1.5
	draw_rect(Rect2(-3, -5 + step * 0.3, 2, 5), Color("3b2f4a"))
	draw_rect(Rect2(1, -5 - step * 0.3, 2, 5), Color("3b2f4a"))
	# Body
	draw_rect(Rect2(-4, -12 + bob, 8, 8), shirt)
	# Head
	draw_circle(Vector2(0, -16 + bob), 5.0, skin)
	# Hair (covers more of the head when facing away)
	if facing.y < -0.5:
		draw_circle(Vector2(0, -16.5 + bob), 5.0, hair)
	else:
		draw_rect(Rect2(-5, -21 + bob, 10, 3.5), hair)
		# Eyes
		var eye_off := Vector2(facing.x * 1.5, 0)
		draw_rect(Rect2(Vector2(-2.5, -16 + bob) + eye_off, Vector2(1, 2)), Color("2a2030"))
		draw_rect(Rect2(Vector2(1.5, -16 + bob) + eye_off, Vector2(1, 2)), Color("2a2030"))
