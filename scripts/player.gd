class_name Player
extends CharacterBody2D
## Top-down player. Walks with WASD/arrows, runs with Shift, and uses the
## closest nearby object with E/Space (toggles sinks, picks up items - only
## the closest one shows its prompt). Picks a toolbar slot with 1-9 and 0, or the
## mouse wheel, uses the selected item while holding F / left mouse, and
## drops it with Q. There's nowhere to hide: during a hunt, run and break the
## ghost's line of sight.
##
## Sanity starts full and slowly drains while in the house (it stops, but
## doesn't recover, outside). Being caught by the ghost costs a big chunk; at
## 0 it's game over. Only restore_sanity() (e.g. medicine) brings it back up.

## Emitted once when sanity hits 0.
signal sanity_depleted

## How many inventory slots the player has. The toolbar shows the first
## TOOLBAR_SLOTS of them (all of them, for now).
const INVENTORY_SIZE := 10
const TOOLBAR_SLOTS := 10
## How far in front of the player dropped items land (px).
const DROP_DISTANCE := 10.0
## The rows of an item's held_sheet, top to bottom.
const HELD_ROWS: Array[StringName] = [&"hold_down", &"hold_up", &"hold_side"]
## Light mask layer the player's sprite is on, instead of the default layer
## 1. The lantern lights it, but the UV beam's cone doesn't (it would light
## her body in the cone's pattern) - UVBeam tints her with a soft glow instead.
const LIGHT_LAYER := 3

@export var walk_speed := 70.0

@export_group("Sanity")
@export var max_sanity := 100.0
## Sanity at the start of the game. Lower it to test hunts sooner.
@export_range(0.0, 100.0) var start_sanity := 100.0
## How much sanity drains per second just from being in the house
## (0.15/s = full to empty in about 11 minutes).
@export var sanity_drain_per_second := 0.15

@export_group("")
var sanity := 100.0
## Sanity as a fraction of the maximum (0-1).
var sanity_ratio: float:
	get:
		return sanity / max_sanity
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

## Things the player is standing next to and can use with E (player-usable
## GhostInteractables like sinks, items on the floor).
var _nearby: Array[Node2D] = []
## The one the E key acts on right now (the closest).
var _focused: Node2D = null
## After closing a menu, ignore the use button until it's released, so the
## press that closed the journal doesn't instantly reopen it.
var _use_blocked_until_release := false


@onready var sprite: AnimatedSprite2D = $Sprite
## The selected item drawn in the player's hand, on top of the sprite.
@onready var held_item: Sprite2D = $Sprite/HeldItem


func _ready() -> void:
	sanity = minf(start_sanity, max_sanity)
	var layer := 1 << (LIGHT_LAYER - 1)
	sprite.light_mask = layer
	held_item.light_mask = layer
	($Lantern as PointLight2D).range_item_cull_mask |= layer
	inventory.changed.connect(_update_held_item)
	sprite.frame_changed.connect(_sync_held_item)
	sprite.animation_changed.connect(_sync_held_item)
	_update_animation(false)


func _physics_process(delta: float) -> void:
	if not is_dead and is_in_house():
		lose_sanity(sanity_drain_per_second * delta)
	_update_item_use(delta)
	_update_focus()
	if is_dead:
		velocity = Vector2.ZERO
		return

	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if in_menu or (is_using_item and selected_item.blocks_movement):
		input = Vector2.ZERO
	velocity = input * walk_speed
	move_and_slide()

	if input != Vector2.ZERO:
		facing = input.normalized()
	_update_animation(input != Vector2.ZERO)


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
		drop_selected()
		return
	if not event.is_action_pressed("interact"):
		return
	if _focused and _focused.has_method("player_interact"):
		_focused.player_interact(self)
	get_viewport().set_input_as_handled()


func die() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	sprite.stop()
	sprite.modulate = Color(0.55, 0.55, 0.6)  # drained of colour


## True while the player is inside the house (sanity only drains in there).
func is_in_house() -> bool:
	var game := Game.current
	return game == null or game.house.is_inside(global_position)


## Gives sanity back, up to the maximum - for medicine and the like.
func restore_sanity(amount: float) -> void:
	if is_dead:
		return
	sanity = minf(max_sanity, sanity + amount)


## Takes away sanity (it never goes below 0). Hitting 0 emits sanity_depleted.
func lose_sanity(amount: float) -> void:
	if sanity <= 0.0:
		return
	sanity = maxf(0.0, sanity - amount)
	if sanity <= 0.0:
		sanity_depleted.emit()


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
	var want := pressed and selected_item != null and not is_dead \
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
	var target: Node2D = null if is_dead else _closest_interactable()
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


# --- Art ------------------------------------------------------------------------

## Plays walk_down / walk_up / walk_side for the way the player faces (the
## side art faces left, so it's mirrored for facing right). While the
## selected item has a held_sheet it plays hold_down / hold_up / hold_side
## instead, with that item drawn on top. Standing still holds the first frame.
func _update_animation(moving: bool) -> void:
	var prefix := "hold_" if _held_sheet() else "walk_"
	var anim: StringName
	if absf(facing.x) > absf(facing.y):
		anim = StringName(prefix + "side")
		sprite.flip_h = facing.x > 0.0
	else:
		anim = StringName(prefix + ("down" if facing.y > 0.0 else "up"))
		sprite.flip_h = false
	held_item.flip_h = sprite.flip_h
	if not sprite.sprite_frames.has_animation(anim):
		return
	if moving:
		if sprite.animation != anim or not sprite.is_playing():
			# Keep the step the legs are on when picking up/putting away an item.
			var frame := sprite.frame
			var progress := sprite.frame_progress
			sprite.play(anim)
			sprite.set_frame_and_progress(frame, progress)
	else:
		sprite.animation = anim
		sprite.stop()
		sprite.frame = 0


## The selected item's held_sheet, or null if it has none (or the slot is empty).
func _held_sheet() -> Texture2D:
	var item := selected_item
	return item.data.held_sheet if item else null


## Called when the selected item changes: shows the new one in hand (or none).
func _update_held_item() -> void:
	held_item.texture = _held_sheet()
	_update_animation(sprite.is_playing())
	_sync_held_item()


## Shows the held item's frame that matches the player's current frame. Its
## sheet has a row per hold animation, in HELD_ROWS order.
func _sync_held_item() -> void:
	var row := HELD_ROWS.find(sprite.animation)
	held_item.visible = held_item.texture != null and row != -1
	if held_item.visible:
		held_item.frame = row * held_item.hframes + sprite.frame


## Shadow on the floor under the player (the sprite draws on top).
func _draw() -> void:
	draw_set_transform(Vector2(0, 0), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 6.0, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO)
