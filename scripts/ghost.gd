class_name Ghost
extends CharacterBody2D
## The ghost haunting the house. It is always somewhere in the house, but
## usually invisible: it drifts around the house, keeps coming back to its
## favourite room, and every so often decides to hunt. The ghost always knows
## where the player is, so a hunt can start from anywhere in the house.
##
## The player can always walk straight through the ghost, so they never feel
## it while it is invisible. It only collides with walls and furniture. During
## a hunt, touching the player means game over.
##
## The node's origin is the floor point under the ghost. What *kind* of ghost
## it is (Demon, Banshee, Poltergeist, Wraith) lives in `behavior` - see
## scripts/ghost_types/. Every ghost looks the same, so the player has to work
## out the type from how it behaves.

signal hunt_started
signal hunt_ended
signal caught_player
## Emitted when the ghost (invisibly) messes with something, e.g. a sink.
signal interacted(item: GhostInteractable)

enum State {
	IDLE,          ## invisible, wandering (mostly around its favourite room)
	APPEARING,     ## hunt just started: fading in (harmless)
	CHASING,       ## visible, chasing the player
	SEARCHING,     ## player hid - prowling around before giving up
	VANISHING,     ## fading out at the end of a hunt
	RETURNING,     ## invisible, heading back to its favourite room
}

const HUNT_STATES := [State.APPEARING, State.CHASING, State.SEARCHING, State.VANISHING]
const WORLD_LAYER := 1
const VISIBLE_ALPHA := 0.85

@export_group("Hunting")
@export var chase_speed := 62.0
## Chance (0-1) of starting a hunt each `hunt_check_interval` once the ghost
## is off cooldown (and the player isn't hiding or too close).
@export var hunt_chance := 0.15
@export var hunt_check_interval := 1.0
@export var min_hunt_cooldown := 6.0
@export var max_hunt_cooldown := 14.0
## The ghost won't start a hunt on its own if the player is closer than this.
@export var min_hunt_distance := 64.0
@export var appear_time := 1.0
@export var search_time := 3.0
@export var search_speed_factor := 0.4
@export var catch_radius := 10.0

@export_group("Wandering")
@export var wander_speed := 22.0
## While in its favourite room: chance (0-1) that the next wander trip goes
## out to another room.
@export var roam_chance := 0.25
## While outside its favourite room: chance (0-1) that the next wander trip
## heads back home (otherwise it keeps exploring other rooms).
@export var return_home_chance := 0.7
## After this many seconds away from its favourite room, the ghost always
## heads home on its next wander trip.
@export var max_time_away := 30.0
@export var min_wander_pause := 1.0
@export var max_wander_pause := 3.5

@export_group("Interactions")
## How often (seconds) the invisible ghost considers messing with nearby
## objects. Each object's own `ghost_interaction_chance` is rolled per check.
@export var interact_check_interval := 1.0
## Chance (0-1) that a wander trip heads to an object (e.g. a sink) in the
## chosen room instead of a random spot, so the ghost actually goes near them.
@export var visit_object_chance := 0.35

@export_group("Debug")
## Draw the ghost faintly even while it's invisible.
@export var debug_reveal := false

@export_group("")
## How often (seconds) the ghost recalculates its path to a moving target.
@export var repath_interval := 0.25

var player: Player
var house: House
var type: GhostBehavior.Type
var behavior: GhostBehavior
var favorite_room := ""
var state := State.IDLE
## True while the player can see the ghost (hunts now, other ghost events later).
var is_manifested := false
var is_hunting: bool:
	get:
		return state in HUNT_STATES

var _state_time := 0.0
var _hunt_cooldown := 0.0
var _hunt_check_timer := 0.0
var _wander_target := Vector2.INF
var _wander_pause := 0.0
var _stuck_time := 0.0
var _time_away := 0.0
var _interact_timer := 0.0
var _path := PackedVector2Array()
var _path_target := Vector2.INF
var _repath_timer := 0.0
var _t := 0.0


## Call before adding the ghost to the scene.
func set_type(new_type: GhostBehavior.Type) -> void:
	type = new_type
	behavior = GhostBehavior.create(new_type)
	behavior.ghost = self


func _ready() -> void:
	z_index = 10  # always float above furniture
	modulate.a = 0.0
	if behavior == null:
		set_type(GhostBehavior.random_type())
	if favorite_room == "":
		favorite_room = House.ROOMS.keys().pick_random()
	_start_hunt_cooldown()
	behavior.on_spawned()


func _physics_process(delta: float) -> void:
	_t += delta
	_state_time += delta
	behavior.process(delta)

	match state:
		State.IDLE:
			_time_away = 0.0 if house.room_at(global_position) == favorite_room else _time_away + delta
			_wander(delta)
			_try_interact(delta)
			_try_start_hunt(delta)

		State.APPEARING:
			if _state_time >= appear_time:
				set_state(State.CHASING)

		State.CHASING:
			if player.is_hidden:
				set_state(State.SEARCHING)
				# Prowl around the spot where the player was last seen.
				_wander_target = _random_point_near(player.global_position, 40.0)
				behavior.on_player_hid()
			else:
				_follow_path_to(player.global_position, behavior.get_chase_speed(chase_speed), delta, true)
				if global_position.distance_to(player.global_position) < catch_radius:
					behavior.on_caught_player()
					caught_player.emit()
					set_physics_process(false)

		State.SEARCHING:
			var speed := behavior.get_search_speed(chase_speed * search_speed_factor)
			_follow_path_to(_wander_target, speed, delta, false)
			if global_position.distance_to(_wander_target) < 4.0:
				_wander_target = _random_point_near(global_position, 50.0)
			var give_up_time := behavior.get_search_time(search_time)
			if not player.is_hidden and _state_time < give_up_time:
				# Player came out too early - the hunt is back on!
				set_state(State.CHASING)
			elif _state_time >= give_up_time:
				is_manifested = false
				set_state(State.VANISHING)

		State.VANISHING:
			if modulate.a <= _hidden_alpha():
				_start_hunt_cooldown()
				_wander_target = house.random_point_in_room(favorite_room)
				set_state(State.RETURNING)
				hunt_ended.emit()

		State.RETURNING:
			_follow_path_to(_wander_target, wander_speed * 1.5, delta, false)
			if global_position.distance_to(_wander_target) < 4.0:
				_wander_target = Vector2.INF
				_wander_pause = randf_range(min_wander_pause, max_wander_pause)
				set_state(State.IDLE)
			else:
				_try_interact(delta)
				_try_start_hunt(delta)

	_update_fade(delta)
	queue_redraw()


## Switches state. Ghost types can call this to force a state change.
func set_state(new_state: State) -> void:
	var old_state := state
	state = new_state
	_state_time = 0.0
	_path_target = Vector2.INF
	if old_state != new_state:
		behavior.on_state_changed(old_state, new_state)


## Starts a hunt right away (ignores cooldown, distance and line of sight).
func start_hunt() -> void:
	if is_hunting:
		return
	is_manifested = true
	set_state(State.APPEARING)
	hunt_started.emit()


## True if nothing solid is between the ghost and a non-hidden player.
func can_see_player() -> bool:
	if player.is_hidden:
		return false
	var query := PhysicsRayQueryParameters2D.create(global_position, player.global_position, WORLD_LAYER)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _try_start_hunt(delta: float) -> void:
	_hunt_cooldown -= delta
	if _hunt_cooldown > 0.0:
		return
	_hunt_check_timer -= delta
	if _hunt_check_timer > 0.0:
		return
	_hunt_check_timer = hunt_check_interval
	if player.is_hidden:
		return
	var far_enough := global_position.distance_to(player.global_position) >= min_hunt_distance
	if far_enough and randf() < behavior.get_hunt_chance(hunt_chance):
		start_hunt()


## Every `interact_check_interval`, maybe mess with one nearby object.
## Only called while the ghost is invisible and not hunting, so the player
## sees the effect (e.g. a sink turning on) but never the ghost.
func _try_interact(delta: float) -> void:
	_interact_timer -= delta
	if _interact_timer > 0.0:
		return
	_interact_timer = interact_check_interval
	for item: GhostInteractable in get_tree().get_nodes_in_group("ghost_interactables"):
		if not item.ghost_can_use(self) or not item.is_in_ghost_reach(global_position) \
				or not item.can_ghost_interact():
			continue
		if randf() < behavior.get_interaction_chance(item, item.ghost_interaction_chance):
			item.ghost_interact(self)
			behavior.on_interacted(item)
			interacted.emit(item)
			return


func _start_hunt_cooldown() -> void:
	_hunt_cooldown = behavior.get_hunt_cooldown(randf_range(min_hunt_cooldown, max_hunt_cooldown))
	_hunt_check_timer = 0.0


## Drift between random points around the house, often heading back to the
## favourite room.
func _wander(delta: float) -> void:
	if _wander_pause > 0.0:
		_wander_pause -= delta
		velocity = Vector2.ZERO
		return
	if _wander_target == Vector2.INF:
		var room := _pick_wander_room()
		_wander_target = house.random_point_in_room(room)
		if randf() < visit_object_chance:
			var spot := _object_stand_point_in(room)
			if spot != Vector2.INF:
				_wander_target = spot

	_follow_path_to(_wander_target, wander_speed, delta, false)
	# Give up on a target we can't reach.
	_stuck_time = _stuck_time + delta if get_real_velocity().length() < 2.0 else 0.0
	if global_position.distance_to(_wander_target) < 4.0 or _stuck_time > 1.0:
		_wander_target = Vector2.INF
		_stuck_time = 0.0
		_wander_pause = randf_range(min_wander_pause, max_wander_pause)


## A walkable spot next to a random interactable in `room`, or INF if the
## room has none.
func _object_stand_point_in(room: String) -> Vector2:
	var items := get_tree().get_nodes_in_group("ghost_interactables").filter(
		func(item): return item.ghost_can_use(self) \
			and house.room_at(item.get_footprint().get_center()) == room)
	if items.is_empty():
		return Vector2.INF
	var item: GhostInteractable = items.pick_random()
	var spot := item.get_ghost_stand_point()
	return spot if house.is_walkable(spot) else _random_point_near(spot, 8.0)


func _pick_wander_room() -> String:
	var other_rooms: Array = House.ROOMS.keys().filter(func(r): return r != favorite_room)
	var at_home := house.room_at(global_position) == favorite_room
	if at_home:
		if randf() < behavior.get_roam_chance(roam_chance):
			return other_rooms.pick_random()
		return favorite_room
	if _time_away >= max_time_away or randf() < behavior.get_return_home_chance(return_home_chance):
		return favorite_room
	return other_rooms.pick_random()


func _update_fade(delta: float) -> void:
	var target := VISIBLE_ALPHA if is_manifested else _hidden_alpha()
	modulate.a = move_toward(modulate.a, target, VISIBLE_ALPHA / appear_time * delta)


func _hidden_alpha() -> float:
	return 0.25 if debug_reveal else 0.0


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
