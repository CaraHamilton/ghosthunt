extends Node2D
## Main game loop: spawns ghosts at random intervals, tracks survival time and
## handles game over / restart.

const GhostScene := preload("res://scenes/ghost.tscn")

@export var min_spawn_delay := 6.0
@export var max_spawn_delay := 14.0
## Seconds between the "chill" warning and the ghost appearing.
@export var warning_time := 1.5
## Ghosts spawn on screen, but try not to appear closer than this.
@export var min_spawn_distance := 90.0
@export var base_ghost_speed := 60.0
@export var ghost_speed_per_wave := 4.0

@onready var house: House = $House
@onready var world: Node2D = $World
@onready var player: Player = $World/Player
@onready var darkness: CanvasModulate = $Darkness
@onready var spawn_timer: Timer = $SpawnTimer
@onready var time_label: Label = $HUD/TimeLabel
@onready var message_label: Label = $HUD/MessageLabel
@onready var hide_overlay: ColorRect = $HUD/HideOverlay
@onready var game_over_panel: Control = $HUD/GameOver
@onready var game_over_stats: Label = $HUD/GameOver/Box/Stats

var survived_time := 0.0
var ghosts_escaped := 0
var wave := 0
var is_game_over := false
var _ghost: Ghost = null
var _base_darkness: Color


func _ready() -> void:
	randomize()
	_base_darkness = darkness.color
	player.global_position = house.PLAYER_START
	var furniture: Array[Rect2] = []
	for spot in get_tree().get_nodes_in_group("hiding_spots"):
		furniture.append(spot.get_footprint())
	house.build_navigation(furniture)
	player.hidden_changed.connect(_on_player_hidden_changed)
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	game_over_panel.visible = false
	hide_overlay.visible = false
	_show_message("Something feels wrong in this house...", 3.0)
	_schedule_next_ghost()


func _process(delta: float) -> void:
	if is_game_over:
		if Input.is_action_just_pressed("restart"):
			get_tree().reload_current_scene()
		return
	survived_time += delta
	time_label.text = "Survived: %ds    Ghosts escaped: %d" % [int(survived_time), ghosts_escaped]


func _schedule_next_ghost() -> void:
	# Ghosts come a little sooner as the night goes on.
	var squeeze := minf(wave * 0.5, 4.0)
	spawn_timer.start(randf_range(min_spawn_delay - squeeze * 0.5, max_spawn_delay - squeeze))


func _on_spawn_timer_timeout() -> void:
	if is_game_over or _ghost != null:
		return
	_show_message("You feel a chill...", warning_time + 0.5)
	_flicker_lights()
	await get_tree().create_timer(warning_time).timeout
	if not is_game_over:
		_spawn_ghost()


func _spawn_ghost() -> void:
	wave += 1
	_ghost = GhostScene.instantiate() as Ghost
	_ghost.player = player
	_ghost.house = house
	_ghost.chase_speed = minf(base_ghost_speed + ghost_speed_per_wave * (wave - 1), player.run_speed - 8.0)
	_ghost.global_position = _pick_spawn_point()
	_ghost.caught_player.connect(_on_ghost_caught_player)
	_ghost.vanished.connect(_on_ghost_vanished)
	world.add_child(_ghost)


## Picks a spawn point that is on screen, in the player's line of sight and
## reachable on foot - preferring points at least `min_spawn_distance` away.
func _pick_spawn_point() -> Vector2:
	var camera := player.get_node("Camera2D") as Camera2D
	var half := get_viewport_rect().size / camera.zoom / 2.0
	var view := Rect2(camera.get_screen_center_position() - half, half * 2.0).grow(-16.0)
	var target := player.global_position

	var far_enough: Array[Vector2] = []
	var closest_fallback := Vector2.INF
	var fallback_dist := -1.0
	for i in 120:
		var p := Vector2(randf_range(view.position.x, view.end.x), randf_range(view.position.y, view.end.y))
		if not _is_valid_spawn(p, target):
			continue
		var d := p.distance_to(target)
		if d >= min_spawn_distance:
			far_enough.append(p)
		elif d > fallback_dist:
			fallback_dist = d
			closest_fallback = p
	if not far_enough.is_empty():
		return far_enough.pick_random()
	if fallback_dist >= 0.0:
		return closest_fallback
	# Nowhere visible (very unlikely) - spawn anywhere reachable in the house.
	for i in 200:
		var p := Vector2(randf_range(0, House.SIZE.x), randf_range(0, House.SIZE.y))
		if house.is_walkable(p) and _is_reachable(p, target):
			return p
	return target + Vector2(0, min_spawn_distance)


func _is_valid_spawn(point: Vector2, target: Vector2) -> bool:
	return house.is_walkable(point) and _has_line_of_sight(point, target) and _is_reachable(point, target)


func _has_line_of_sight(from: Vector2, to: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from, to, 1)  # world layer only
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _is_reachable(from: Vector2, to: Vector2) -> bool:
	var path := house.get_nav_path(from, to)
	return path.size() > 0 and path[path.size() - 1].distance_to(to) < 16.0


func _on_ghost_vanished() -> void:
	_ghost = null
	ghosts_escaped += 1
	_show_message("It's gone... for now.", 2.0)
	_schedule_next_ghost()


func _on_ghost_caught_player() -> void:
	is_game_over = true
	spawn_timer.stop()
	player.die()
	hide_overlay.visible = false
	message_label.visible = false
	game_over_stats.text = "You survived %d seconds and escaped %d ghost%s." % [
		int(survived_time), ghosts_escaped, "" if ghosts_escaped == 1 else "s"]
	game_over_panel.visible = true


func _on_player_hidden_changed(is_hidden: bool) -> void:
	hide_overlay.visible = is_hidden


func _flicker_lights() -> void:
	var tween := create_tween()
	for i in 3:
		tween.tween_property(darkness, "color", _base_darkness.darkened(0.6), 0.08)
		tween.tween_property(darkness, "color", _base_darkness, 0.12)


var _message_id := 0

func _show_message(text: String, duration: float) -> void:
	_message_id += 1
	var id := _message_id
	message_label.text = text
	message_label.visible = true
	await get_tree().create_timer(duration).timeout
	if id == _message_id and not is_game_over:
		message_label.visible = false
