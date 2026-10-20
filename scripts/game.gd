extends Node2D
## Main game loop: spawns ghosts at random intervals, tracks survival time and
## handles game over / restart.

const GhostScene := preload("res://scenes/ghost.tscn")

@export var min_spawn_delay := 6.0
@export var max_spawn_delay := 14.0
## Seconds between the "chill" warning and the ghost appearing.
@export var warning_time := 1.5
## Ghosts never spawn closer than this to the player.
@export var min_spawn_distance := 170.0
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
	_ghost.chase_speed = minf(base_ghost_speed + ghost_speed_per_wave * (wave - 1), player.run_speed - 8.0)
	_ghost.global_position = _pick_spawn_point()
	_ghost.caught_player.connect(_on_ghost_caught_player)
	_ghost.vanished.connect(_on_ghost_vanished)
	world.add_child(_ghost)


func _pick_spawn_point() -> Vector2:
	var area: Rect2 = house.SPAWN_AREA
	var best := area.position
	var best_dist := -1.0
	for i in 30:
		var p := Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y))
		var d := p.distance_to(player.global_position)
		if d >= min_spawn_distance:
			return p
		if d > best_dist:
			best_dist = d
			best = p
	return best


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
