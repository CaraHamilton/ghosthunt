class_name Ghost
extends CharacterBody2D
## The ghost haunting the house. It is always somewhere in the house, but
## usually invisible: it drifts around the house, keeps coming back to its
## favourite room, and every so often decides to hunt. A hunt can start from
## anywhere in the house.
##
## During a hunt the ghost can only go after what it has seen:
##   INVESTIGATING  walks (at the player's walking speed) to the last place
##                  it saw the player - it remembers this even between hunts
##   CHASING        it can see the player: straight for them. Starts a bit
##                  slower than the player runs, speeds up the longer it
##                  keeps sight of them, and resets when it loses them.
##                  It pauses briefly on spotting the player (a head start)
##   SEARCHING      reached the last-seen spot and the player isn't there:
##                  prowls nearby until a timer runs out, then the hunt ends
## Seeing the player at any point switches to CHASING; losing sight of them
## switches back to INVESTIGATING. Walls and furniture block its view.
##
## The player can always walk straight through the ghost, so they never feel
## it while it is invisible. It only collides with walls and furniture.
## Hunts only start once the player's sanity is low enough. During a hunt,
## touching the player catches them (costing them sanity) and ends the hunt.
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
	INVESTIGATING, ## hunt: walking to where it last saw the player
	CHASING,       ## hunt: can see the player, going straight for them
	SEARCHING,     ## hunt: prowling around the last-seen spot until time runs out
	VANISHING,     ## fading out at the end of a hunt
	RETURNING,     ## invisible, heading back to its favourite room
}

const HUNT_STATES := [State.APPEARING, State.INVESTIGATING, State.CHASING, State.SEARCHING, State.VANISHING]
const WORLD_LAYER := 1
const VISIBLE_ALPHA := 0.85

@export_group("Hunting")
## Chase speed when a chase begins, as a multiple of the player's RUN speed
## (<1 = slower than you can run).
@export var chase_start_speed_factor := 0.92
## Top chase speed, reached after keeping sight of the player for
## `chase_ramp_time` seconds (>1 = faster than you can run).
@export var chase_max_speed_factor := 1.15
## Seconds of unbroken sight to go from start speed to top speed. Losing
## sight (ending the chase) resets it - break line of sight quickly!
@export var chase_ramp_time := 7.0
## Seconds the ghost freezes when it first spots the player (every time it
## switches into a chase) - a head start for the player. It can't catch
## anyone during this pause.
@export var chase_start_delay := 0.5
## Investigate speed as a multiple of the player's WALK speed.
@export var investigate_speed_factor := 1.0
## Search speed as a multiple of the player's WALK speed.
@export var search_speed_factor := 0.6
## Seconds the ghost searches around the last-seen spot before the hunt ends.
@export var search_time := 10.0
## How far (px) from the last-seen spot the ghost looks around while searching.
@export var search_radius := 56.0
## Seconds out of sight before a chase turns back into an investigation
## (stops it flip-flopping when the player ducks past a corner).
@export var lose_sight_delay := 0.4
## Chance (0-1) of starting a hunt each `hunt_check_interval` once the ghost
## is off cooldown (and the player isn't too close).
@export var hunt_chance := 0.2
@export var hunt_check_interval := 1.0
## Random wait (seconds) after each hunt - and from the moment the player's
## sanity first drops low enough - before the ghost may hunt again.
@export var min_hunt_cooldown := 20.0
@export var max_hunt_cooldown := 45.0
## The ghost won't start a hunt on its own if the player is closer than this.
@export var min_hunt_distance := 64.0
## The ghost only starts hunts on its own once the player's sanity is below
## this fraction of full (0.75 = 75%).
@export_range(0.0, 1.0) var hunt_sanity_threshold := 0.75
@export var appear_time := 1.0
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
## True if the ghost can see the player this frame.
var sees_player := false
## Where the ghost last saw the player (INF if it never has). Remembered
## between hunts too, while it's invisible.
var last_seen_position := Vector2.INF

var _state_time := 0.0
var _hunt_cooldown := 0.0
## True while the player's sanity is too high for hunts. Dropping below the
## threshold starts a fresh cooldown, so a hunt never fires the instant it's
## allowed - the ghost merely *can* hunt from then on.
var _hunts_locked := true
var _hunt_check_timer := 0.0
var _wander_target := Vector2.INF
var _wander_pause := 0.0
var _stuck_time := 0.0
var _time_away := 0.0
var _interact_timer := 0.0
var _out_of_sight_time := 0.0
## Seconds the ghost has kept sight of the player in the current chase.
var _chase_sight_time := 0.0
var _search_center := Vector2.ZERO
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
		favorite_room = house.get_room_names().pick_random()
	_start_hunt_cooldown()
	behavior.on_spawned()


func _physics_process(delta: float) -> void:
	_t += delta
	_state_time += delta
	behavior.process(delta)
	_update_sight()

	match state:
		State.IDLE:
			_time_away = 0.0 if house.room_at(global_position) == favorite_room else _time_away + delta
			_wander(delta)
			_try_interact(delta)
			_try_start_hunt(delta)

		State.APPEARING:
			velocity = Vector2.ZERO
			if _state_time >= appear_time:
				_pursue()

		State.INVESTIGATING:
			if sees_player:
				set_state(State.CHASING)
			else:
				var speed := behavior.get_investigate_speed(player.walk_speed * investigate_speed_factor)
				_follow_path_to(last_seen_position, speed, delta, false)
				_stuck_time = _stuck_time + delta if get_real_velocity().length() < 2.0 else 0.0
				if global_position.distance_to(last_seen_position) < 6.0 or _stuck_time > 1.0:
					_start_search(last_seen_position)
				_check_catch()

		State.CHASING:
			if _state_time < chase_start_delay:
				# Just spotted the player: a brief pause before it gives chase.
				velocity = Vector2.ZERO
			else:
				if sees_player:
					_chase_sight_time += delta
				_follow_path_to(player.global_position, get_current_chase_speed(), delta, true)
				_check_catch()
			_out_of_sight_time = 0.0 if sees_player else _out_of_sight_time + delta
			if _out_of_sight_time > lose_sight_delay and state == State.CHASING:
				behavior.on_lost_sight_of_player()
				set_state(State.INVESTIGATING)

		State.SEARCHING:
			if sees_player:
				set_state(State.CHASING)
			elif _state_time >= behavior.get_search_time(search_time):
				end_hunt()  # didn't find them - the hunt is over
			else:
				var speed := behavior.get_search_speed(player.walk_speed * search_speed_factor)
				_follow_path_to(_wander_target, speed, delta, false)
				_stuck_time = _stuck_time + delta if get_real_velocity().length() < 2.0 else 0.0
				if global_position.distance_to(_wander_target) < 4.0 or _stuck_time > 1.0:
					_stuck_time = 0.0
					_wander_target = _random_point_near(_search_center, search_radius)
				_check_catch()

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

	_update_animation()
	_update_fade(delta)
	queue_redraw()


## Faces the sprite the way the ghost is moving: "down", "up" or "side"
## (the side art faces left, so it's flipped for moving right). Keeps the
## last facing while the ghost is standing still.
func _update_animation() -> void:
	var sprite := $Sprite as AnimatedSprite2D
	var move := get_real_velocity()
	if move.length() < 2.0:
		return
	var anim: StringName
	if absf(move.x) > absf(move.y):
		anim = &"side"
		sprite.flip_h = move.x > 0.0
	else:
		anim = &"down" if move.y > 0.0 else &"up"
		sprite.flip_h = false
	if sprite.animation != anim and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)


## Switches state. Ghost types can call this to force a state change.
func set_state(new_state: State) -> void:
	var old_state := state
	state = new_state
	_state_time = 0.0
	_stuck_time = 0.0
	_out_of_sight_time = 0.0
	_chase_sight_time = 0.0  # every new chase starts at the slow start speed
	_path_target = Vector2.INF
	if old_state != new_state:
		if OS.is_debug_build() and (new_state in HUNT_STATES or old_state in HUNT_STATES):
			print("[debug] Ghost: %s -> %s" % [State.keys()[old_state], State.keys()[new_state]])
		behavior.on_state_changed(old_state, new_state)


## Starts a hunt right away (ignores cooldown, distance and line of sight).
func start_hunt() -> void:
	if is_hunting:
		return
	is_manifested = true
	set_state(State.APPEARING)
	hunt_started.emit()


## Chase speed right now: starts a little slower than the player can run and
## builds up the longer the ghost keeps sight of them.
func get_current_chase_speed() -> float:
	var ramp := clampf(_chase_sight_time / chase_ramp_time, 0.0, 1.0)
	var factor := lerpf(chase_start_speed_factor, chase_max_speed_factor, ramp)
	return behavior.get_chase_speed(player.run_speed * factor)


## True if nothing solid (walls, furniture) is between the ghost and player.
func can_see_player() -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position, player.global_position, WORLD_LAYER)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## Looks for the player and remembers where it last saw them.
func _update_sight() -> void:
	sees_player = not player.is_dead and can_see_player()
	if sees_player:
		last_seen_position = player.global_position


## Once a hunt's fade-in is over: chase if it can see the player, otherwise
## investigate where it last saw them - or, if it never has, search around
## where it is.
func _pursue() -> void:
	if sees_player:
		set_state(State.CHASING)
	elif last_seen_position != Vector2.INF:
		set_state(State.INVESTIGATING)
	else:
		_start_search(global_position)


func _start_search(center: Vector2) -> void:
	_search_center = center
	_wander_target = _random_point_near(center, search_radius)
	set_state(State.SEARCHING)


## Catching the player ends the hunt (the game takes away their sanity).
func _check_catch() -> void:
	if state in HUNT_STATES and global_position.distance_to(player.global_position) < catch_radius:
		behavior.on_caught_player()
		end_hunt()
		caught_player.emit()


## Ends the current hunt: the ghost fades out and heads back home.
func end_hunt() -> void:
	if not is_hunting or state == State.VANISHING:
		return
	is_manifested = false
	set_state(State.VANISHING)


func _try_start_hunt(delta: float) -> void:
	if player.sanity_ratio >= behavior.get_hunt_sanity_threshold(hunt_sanity_threshold):
		_hunts_locked = true  # the player's mind is still too strong
		return
	if _hunts_locked:
		# Sanity just dropped low enough: hunts are now possible, but only
		# after a fresh random wait.
		_hunts_locked = false
		_start_hunt_cooldown()
		return
	_hunt_cooldown -= delta
	if _hunt_cooldown > 0.0:
		return
	_hunt_check_timer -= delta
	if _hunt_check_timer > 0.0:
		return
	_hunt_check_timer = hunt_check_interval
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
	var other_rooms: Array = house.get_room_names().filter(func(r): return r != favorite_room)
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
	# If the ghost's body can slide straight there without hitting anything,
	# skip the grid path and go direct (tighter chases, and it can squeeze
	# into any gap its body physically fits).
	var to_target := target - global_position
	if to_target.length() > 0.5 and not test_move(global_transform, to_target):
		_path_target = Vector2.INF  # re-plan if the straight line gets blocked
		velocity = to_target.normalized() * speed
		move_and_slide()
		return

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

	# Faint shadow on the floor
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 7.0, Color(0, 0, 0, 0.2))
	draw_set_transform(Vector2.ZERO)
