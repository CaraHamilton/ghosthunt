class_name Player
extends CharacterBody2D
## Top-down player. Walks with WASD/arrows, runs with Shift, and uses the
## closest nearby object with E/Space (hides in HidingSpots, toggles sinks,
## picks up items - only the closest one shows its prompt). Picks a toolbar
## slot with 1-5 or the mouse wheel, uses the selected item while holding
## F / left mouse, and drops it with Q.

signal hidden_changed(is_hidden: bool)

## How many inventory slots the player has. The toolbar shows the first
## TOOLBAR_SLOTS of them (all of them, for now).
const INVENTORY_SIZE := 5
const TOOLBAR_SLOTS := 5
## How far in front of the player dropped items land (px).
const DROP_DISTANCE := 10.0

@export var walk_speed := 70.0
@export var run_speed := 115.0

var is_hidden := false
var is_dead := false
var facing := Vector2.DOWN
## True while a window like the journal is open: no moving or using items.
var in_menu := false

var inventory := Inventory.new(INVENTORY_SIZE, self)
var selected_slot := 0
var is_using_item := false
var selected_item: ItemInstance:
	get:
		return inventory.get_item(selected_slot)

## Things the player is standing next to and can use with E (HidingSpots,
## player-usable GhostInteractables, items on the floor).
var _nearby: Array[Node2D] = []
## The one the E key acts on right now (closest, or the spot we're hiding in).
var _focused: Node2D = null
var _current_spot: HidingSpot = null
var _walk_time := 0.0
## After closing a menu, ignore the use button until it's released, so the
## press that closed the journal doesn't instantly reopen it.
var _use_blocked_until_release := false


func _physics_process(delta: float) -> void:
	_update_item_use(delta)
	_update_focus()
	if is_dead or is_hidden:
		velocity = Vector2.ZERO
		return

	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if in_menu or (is_using_item and selected_item.blocks_movement):
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
	if is_dead or in_menu:
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
	if event.is_action_pressed("drop_item"):
		if not is_hidden:
			drop_selected()
		return
	if not event.is_action_pressed("interact"):
		return
	if is_hidden:
		leave_hiding_spot()
	elif _focused is HidingSpot:
		enter_hiding_spot(_focused)
	elif _focused and _focused.has_method("player_interact"):
		_focused.player_interact(self)
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


## Called by windows like the journal when they open and close.
func set_in_menu(value: bool) -> void:
	in_menu = value
	if not value:
		_use_blocked_until_release = true


func select_slot(slot: int) -> void:
	if slot == selected_slot:
		return
	_set_using_item(false)
	selected_slot = slot
	inventory.changed.emit()


## Picks up an item that's on the floor (`from_node` is its world node).
## Returns false if there's no room.
func pick_up(item: ItemInstance, from_node: Node2D) -> bool:
	if not inventory.has_room_for(item):
		return false
	unregister_interactable(from_node)
	if from_node == _focused:
		_focused = null
	inventory.add_item(item)
	item.on_picked_up(self)
	return true


## Drops the selected item (one of a stack) on the floor in front of us.
func drop_selected() -> void:
	if selected_item == null:
		return
	_set_using_item(false)
	var item := inventory.remove_from_slot(selected_slot, 1)
	var spot := global_position + facing * DROP_DISTANCE
	var game := Game.current
	if not game.house.is_walkable(spot):
		spot = global_position  # too close to a wall: drop it at our feet
	ItemPickup.drop(item, game.world, spot)


## Uses the selected item while the use button is held, and keeps every
## carried item ticking (sensors keep measuring in your pocket).
func _update_item_use(delta: float) -> void:
	var pressed := Input.is_action_pressed("use_tool")
	if not pressed:
		_use_blocked_until_release = false
	var want := pressed and selected_item != null and not is_hidden and not is_dead \
		and not in_menu and not _use_blocked_until_release
	_set_using_item(want)
	if not is_dead:
		for item in inventory.items():
			item.process_always(delta)
	if is_using_item and selected_item:
		selected_item.process_use(delta)


func _set_using_item(value: bool) -> void:
	if value == is_using_item:
		return
	is_using_item = value
	var item := selected_item
	if item:
		if value:
			item.start_use()
		else:
			item.stop_use()
	queue_redraw()


## Called by objects' interaction zones when the player walks into range.
## Each must have `set_prompt_visible(bool)`.
func register_interactable(item: Node2D) -> void:
	if item not in _nearby:
		_nearby.append(item)


func unregister_interactable(item: Node2D) -> void:
	_nearby.erase(item)


## Picks which nearby object E acts on and shows only that one's prompt.
func _update_focus() -> void:
	var target: Node2D = null
	if is_hidden:
		target = _current_spot
	elif not is_dead:
		target = _closest_interactable()
	if target == _focused:
		return
	if is_instance_valid(_focused):
		_focused.set_prompt_visible(false)
	_focused = target
	if _focused:
		_focused.set_prompt_visible(true)


func _closest_interactable() -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	for thing in _nearby:
		if not is_instance_valid(thing):
			continue
		var d := global_position.distance_squared_to(thing.global_position)
		if d < best_dist:
			best_dist = d
			best = thing
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
	if is_using_item:
		var hand := Vector2(5 if facing.x >= 0 else -6, -10 + bob)
		draw_rect(Rect2(hand, Vector2(1.5, 5)), Color("e8e8f0"))
		draw_circle(hand + Vector2(0.75, 5.5), 1.3, Color("d8403a"))
