class_name Player
extends CharacterBody2D
## Top-down player. Walks with WASD/arrows, runs with Shift, and picks a
## toolbar slot with 1-9 or the mouse wheel.
##   Left mouse / F  uses the selected item while held (the doll and fog
##                   machine have no use in hand). Left-clicking a house
##                   object within reach (sink, tub, book stack...) uses
##                   that instead - see house_object_at.
##   Right mouse     on her own tile or the 8 around it: picks up a placed
##                   tool (whatever she's holding), or puts the selected
##                   item down on an empty tile. Hold it to see which first.
##                   See right_click_target.
##   Q               places the selected item on the tile in front of her
##                   when let go (holding it shows which tile first).
##   E / Space       uses the closest nearby object (or picks up an item).
## One item per tile; tables and other surfaces take items too. There's
## nowhere to hide: during a hunt, run and break the ghost's line of sight.
##
## Sanity starts full and slowly drains while in the house (it stops, but
## doesn't recover, outside). Reaching 0 isn't game over (being caught by the
## ghost is). Only restore_sanity() (e.g. medicine) brings it back up.

## Emitted once when sanity hits 0.
signal sanity_depleted

## How many inventory slots the player has. The toolbar shows the first
## TOOLBAR_SLOTS of them (all of them, for now).
const INVENTORY_SIZE := 9
const TOOLBAR_SLOTS := 9
## How far in front of the player dropped items land (px).
const DROP_DISTANCE := 10.0
## Corner correction: walking straight into the corner of a wall or piece of
## furniture, overlapping it by up to this many px, slides her around it
## instead of stopping her dead.
const CORNER_NUDGE := 4
## The rows of an item's held_sheet, top to bottom.
const HELD_ROWS: Array[StringName] = [&"hold_down", &"hold_up", &"hold_side"]
## Light mask layer the player's sprite is on, instead of the default layer
## 1. World lights (the lantern, fireplaces) don't reach it directly - her
## PlayerLight copies the brightest of them, so overlapping lights don't add
## up on her. The UV beam's cone doesn't either (it would light her body in
## the cone's pattern) - UVBeam tints her with a soft glow instead.
const LIGHT_LAYER := 3

@export var walk_speed := 70.0

@export_group("Sound")
## Frames of the walk (and hold) animations where a foot lands - a footstep
## plays on each. Frames count from 0.
@export var footstep_frames: Array[int] = [1, 3]
## How loud her footsteps are (dB; 0 = as exported, -6 = about half).
@export var footstep_volume_db := -4.0

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
## Outlines the tile Q would place the selected item on.
var _place_highlight: PlaceHighlight


@onready var sprite: AnimatedSprite2D = $Sprite
## Her collision shape at her feet.
@onready var _feet: CollisionShape2D = $CollisionShape2D
## The selected item drawn in the player's hand, on top of the sprite.
@onready var held_item: Sprite2D = $Sprite/HeldItem


func _ready() -> void:
	sanity = minf(start_sanity, max_sanity)
	var layer := 1 << (LIGHT_LAYER - 1)
	sprite.light_mask = layer
	held_item.light_mask = layer
	add_child(PlayerLight.new())
	_place_highlight = PlaceHighlight.new()
	add_child(_place_highlight)
	inventory.changed.connect(_update_held_item)
	sprite.frame_changed.connect(_sync_held_item)
	sprite.frame_changed.connect(_play_footstep)
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
	# (selected_item can be gone while using it - e.g. the last flask of holy
	# water was just thrown.)
	if in_menu or (is_using_item and selected_item and selected_item.blocks_movement):
		input = Vector2.ZERO
	velocity = input * walk_speed
	move_and_slide()
	_nudge_around_corners(input, delta)

	if input != Vector2.ZERO:
		facing = input.normalized()
	_update_animation(input != Vector2.ZERO)


## If walking straight (not diagonally) was blocked by just the edge of
## something, slides her sideways toward the gap - checking 1 px either side,
## then 2 px... up to CORNER_NUDGE - at no more than walking speed.
func _nudge_around_corners(input: Vector2, delta: float) -> void:
	var dir: Vector2
	if absf(input.y) < 0.1 and input.x != 0.0:
		dir = Vector2(signf(input.x), 0)
	elif absf(input.x) < 0.1 and input.y != 0.0:
		dir = Vector2(0, signf(input.y))
	else:
		return  # standing still, or diagonal (move_and_slide slides those)
	var step := dir * walk_speed * delta
	if not test_move(global_transform, step):
		return  # not blocked
	var side := Vector2(-dir.y, dir.x)
	# (+1: clearing an overlap of n px takes an n+1 px shift - Godot keeps a
	# tiny gap between colliding shapes.)
	for d in range(1, CORNER_NUDGE + 2):
		for s: float in [1.0, -1.0]:
			var shift := side * s * d
			# The sideways path must be clear, and the way ahead clear from there.
			if not test_move(global_transform, shift) \
					and not test_move(global_transform.translated(shift), step):
				move_and_collide(side * s * minf(d, walk_speed * delta))
				return


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
	# Hold Q to see where the item will go (and move/turn to aim), let go to
	# place it. A quick tap places it straight away.
	if event.is_action_pressed("place_item"):
		_place_highlight.aiming = true
		return
	if event.is_action_released("place_item"):
		if _place_highlight.aiming:
			_place_highlight.aiming = false
			place_selected()
		return
	# Left click on a house object (a sink...) uses it instead of the held
	# tool - and the tool stays unused until the button is let go.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed and left_click(get_global_mouse_position()):
		_use_blocked_until_release = true
		_set_using_item(false)
		get_viewport().set_input_as_handled()
		return
	# Same as Q for right click: hold it to see what it will act on, let go.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			_place_highlight.mouse_aiming = true
		elif _place_highlight.mouse_aiming:
			_place_highlight.mouse_aiming = false
			right_click(get_global_mouse_position())
		get_viewport().set_input_as_handled()
		return
	if not event.is_action_pressed("interact"):
		return
	if _focused and _focused.has_method("player_interact"):
		_focused.player_interact(self)
	get_viewport().set_input_as_handled()


func die() -> void:
	is_dead = true
	_place_highlight.aiming = false
	_place_highlight.mouse_aiming = false
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
	# A held Q or right click doesn't act after the menu.
	_place_highlight.aiming = false
	_place_highlight.mouse_aiming = false
	if not value:
		_use_blocked_until_release = true


func select_slot(slot: int) -> void:
	if slot == selected_slot:
		return
	_set_using_item(false)
	selected_slot = slot
	inventory.changed.emit()
	Sfx.play("ui/select_slot")


## Picks up an item that's on the floor (`from_node` is its world node).
## Returns false if there's no room.
func pick_up(item: ItemInstance, from_node: Node2D) -> bool:
	if not inventory.has_room_for(item):
		return false
	unregister_interactable(from_node)
	if from_node == _focused:
		_focused = null
	# Into the selected slot if it's free, else the first free one.
	inventory.add_item(item, selected_slot)
	item.on_picked_up(self)
	Sfx.play("tools/pick_up")
	return true


## The tile next to the one we're standing on, the way we face (up, down,
## left or right) - where Q places the selected item.
func place_target() -> Vector2i:
	var dir := Vector2i(signi(roundi(facing.x)), 0) if absf(facing.x) > absf(facing.y) \
		else Vector2i(0, 1 if facing.y > 0.0 else -1)
	# Our tile is the one under the middle of our feet (the collision shape),
	# not the very bottom edge of the sprite.
	return Game.current.house.tile_at(global_position + _feet.position) + dir


## Where the selected item would be placed (see House.get_place_spot): the
## tile in front of us, on a table there only if the item may go on one.
func place_spot() -> Dictionary:
	var on_surfaces := selected_item != null and selected_item.data.can_place_on_surfaces
	return Game.current.house.get_place_spot(place_target(), on_surfaces)


## True if the selected item can be put down (not empty, and not an item
## like the journal that never leaves your hands - ItemData.can_place).
func can_place_selected() -> bool:
	return selected_item != null and selected_item.data.can_place


## Places the selected item (one of a stack) on the tile in front of us -
## on the floor, or on a table there. Does nothing if that tile is blocked.
func place_selected() -> void:
	if selected_item == null:
		return
	if not can_place_selected():
		_place_highlight.flash_blocked()  # (the journal can't be put down)
		return
	var game := Game.current
	var spot := place_spot()
	if not spot.ok:
		_place_highlight.flash_blocked()
		return
	_place_at(spot)


## Puts one of the selected item down at `spot` (from House.get_place_spot,
## and ok).
func _place_at(spot: Dictionary) -> void:
	_set_using_item(false)
	var item := inventory.remove_from_slot(selected_slot, 1)
	var node := ItemPickup.place(item, Game.current.world, spot)
	Sfx.play("tools/set_down", node.global_position)


# --- Mouse ----------------------------------------------------------------------

## The tile under the middle of our feet.
func standing_cell() -> Vector2i:
	return Game.current.house.tile_at(global_position + _feet.position)


## The house object a left click at `point` (world space) would use instead
## of the held tool: something the player can switch, like a sink, tub or
## book stack, whose art is under `point` and that's within reach (our tile
## and the 8 around it). The front-most one if several overlap. Null if none.
## Fires (left click with the lantern lights them), breakables (only the
## ghost touches those) and placed tools (right click picks those up) don't
## count.
func house_object_at(point: Vector2) -> GhostInteractable:
	var reach := Game.current.house.tile_rect(standing_cell()).grow(16.0)
	var best: GhostInteractable = null
	for thing: GhostInteractable in get_tree().get_nodes_in_group("ghost_interactables"):
		if not thing.player_can_use or thing.is_queued_for_deletion():
			continue
		if ("item" in thing and thing.item != null) or (thing is Switchable and not thing.player_can_switch()):
			continue
		if not thing.is_clicked_at(point):
			continue
		if thing not in _nearby and not thing.get_footprint().intersects(reach):
			continue
		if best == null or thing.global_position.y > best.global_position.y:
			best = thing
	return best


## Left click at `point`: uses the house object there, if any (see
## house_object_at). Returns true if it did - then the held tool isn't used
## for this click.
func left_click(point: Vector2) -> bool:
	if is_dead or in_menu:
		return false
	var thing := house_object_at(point)
	if thing == null:
		return false
	thing.player_interact(self)
	return true


## What a right click at `point` (world space) would do. Only our own tile
## or the 8 around it count. In order:
##   kind "pick_up" - a tool we placed is there (node = its world node)
##   kind "place"   - an empty tile next to us, and we're holding something
##                    (spot = from House.get_place_spot; spot.ok is false if
##                    the item can't go there)
##   kind "blocked" - a tile too far away, or the one we're standing on
##                    while holding something (we're in the way)
##   kind "none"    - nothing to do
## `rect` is the area to highlight.
func right_click_target(point: Vector2) -> Dictionary:
	var house := Game.current.house
	var me := standing_cell()
	var near := func(cell: Vector2i) -> bool:
		return absi(cell.x - me.x) <= 1 and absi(cell.y - me.y) <= 1

	# A placed tool (on the floor, or raised up on a table).
	for node in get_tree().get_nodes_in_group(House.PLACED_GROUP):
		if node.is_queued_for_deletion() or not ("item" in node) or node.item == null:
			continue  # (snapped decor like book stacks is in the group too)
		var cell: Variant = node.get_meta("place_tile", null)
		if cell == null or not near.call(cell):
			continue
		var rect := house.tile_rect(cell)
		var lift: float = node.get("elevation") if "elevation" in node else 0.0
		var raised := Rect2(rect.position - Vector2(0, lift), rect.size)
		if rect.has_point(point) or raised.has_point(point):
			return {kind = &"pick_up", node = node, rect = raised}

	# An empty tile next to us to put the held item on.
	var placeable := can_place_selected()
	if placeable:
		var on_surfaces := selected_item.data.can_place_on_surfaces
		var blocked := {}
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var spot := house.get_place_spot(me + Vector2i(dx, dy), on_surfaces)
				if (spot.rect as Rect2).has_point(point):
					if spot.ok:
						return {kind = &"place", spot = spot, rect = spot.rect}
					blocked = spot
		if not blocked.is_empty():
			return {kind = &"place", spot = blocked, rect = blocked.rect}
	# Our own tile (we're in the way), or too far: nothing can happen there.
	var cell := house.tile_at(point)
	if cell != me or placeable:
		return {kind = &"blocked", rect = house.tile_rect(cell)}
	return {kind = &"none"}


## Right click at `point`: picks up a placed tool or puts the held item
## down - see right_click_target. Whatever we're holding stays selected.
func right_click(point: Vector2) -> void:
	if is_dead or in_menu:
		return
	var target := right_click_target(point)
	match target.kind:
		&"pick_up":
			var node: Node2D = target.node
			if not inventory.has_room_for(node.item):
				_place_highlight.flash_blocked(target.rect)
				return
			node.player_interact(self)
		&"place":
			if target.spot.ok:
				_place_at(target.spot)
			else:
				_place_highlight.flash_blocked(target.rect)
		&"blocked":
			_place_highlight.flash_blocked(target.rect)


## Drops the selected item (one of a stack) on the floor in front of us,
## anywhere - not on the tile grid. (Not on a key yet: Q places instead.)
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
## Each must have `player_interact(player)`.
func register_interactable(item: Node2D) -> void:
	if item not in _nearby:
		_nearby.append(item)


func unregister_interactable(item: Node2D) -> void:
	_nearby.erase(item)


## Picks which nearby object E acts on (the closest).
func _update_focus() -> void:
	_focused = null if is_dead else _closest_interactable()


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


## A footstep when the walk animation reaches a frame where a foot lands.
func _play_footstep() -> void:
	if not sprite.is_playing() or is_dead:
		return
	if footstep_frames.has(sprite.frame):
		Sfx.play("player/footstep", null, footstep_volume_db)
