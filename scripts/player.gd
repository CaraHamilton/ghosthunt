class_name Player
extends CharacterBody2D
## Top-down player. Walks with WASD/arrows, runs with Shift, and hides in
## nearby HidingSpots with E/Space. Picks a toolbar slot with 1-5 or the mouse
## wheel, and uses the selected tool while holding F / left mouse.

signal hidden_changed(is_hidden: bool)
signal tools_changed

const TOOLBAR_SLOTS := 5

@export var walk_speed := 70.0
@export var run_speed := 115.0

var is_hidden := false
var is_dead := false
var facing := Vector2.DOWN

## Toolbar contents; empty slots are null.
var tools: Array[Tool] = []
var selected_slot := 0
var is_using_tool := false
var selected_tool: Tool:
	get:
		return tools[selected_slot]

## Hiding spots the player is currently standing next to.
var _nearby_spots: Array[HidingSpot] = []
var _current_spot: HidingSpot = null
var _walk_time := 0.0


func _init() -> void:
	tools.resize(TOOLBAR_SLOTS)


func _physics_process(delta: float) -> void:
	_update_tool_use(delta)
	if is_dead or is_hidden:
		velocity = Vector2.ZERO
		return

	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if is_using_tool and selected_tool.blocks_movement:
		input = Vector2.ZERO
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
	if is_dead:
		return
	for i in TOOLBAR_SLOTS:
		if event.is_action_pressed("tool_slot_%d" % (i + 1)):
			select_slot(i)
			return
	if event.is_action_pressed("next_tool"):
		select_slot(posmod(selected_slot + 1, TOOLBAR_SLOTS))
		return
	if event.is_action_pressed("prev_tool"):
		select_slot(posmod(selected_slot - 1, TOOLBAR_SLOTS))
		return
	if not event.is_action_pressed("interact"):
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


## Puts a tool in the first empty toolbar slot (or `slot` if given).
func give_tool(tool: Tool, slot := -1) -> void:
	if slot < 0:
		slot = tools.find(null)
		if slot < 0:
			push_warning("Toolbar is full, can't add %s" % tool.display_name)
			return
	tool.player = self
	tools[slot] = tool
	tools_changed.emit()


func select_slot(slot: int) -> void:
	if slot == selected_slot:
		return
	_set_using_tool(false)
	selected_slot = slot
	tools_changed.emit()


## Uses the selected tool while the use button is held.
func _update_tool_use(delta: float) -> void:
	var want := Input.is_action_pressed("use_tool") and selected_tool != null \
		and not is_hidden and not is_dead
	_set_using_tool(want)
	if not is_dead:
		for tool in tools:
			if tool:
				tool.process_always(delta)
	if is_using_tool:
		selected_tool.process_use(delta)


func _set_using_tool(value: bool) -> void:
	if value == is_using_tool:
		return
	is_using_tool = value
	if selected_tool:
		if value:
			selected_tool.start_use()
		else:
			selected_tool.stop_use()
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

	# Holding the active tool out in front (placeholder until there's art)
	if is_using_tool:
		var hand := Vector2(5 if facing.x >= 0 else -6, -10 + bob)
		draw_rect(Rect2(hand, Vector2(1.5, 5)), Color("e8e8f0"))
		draw_circle(hand + Vector2(0.75, 5.5), 1.3, Color("d8403a"))
