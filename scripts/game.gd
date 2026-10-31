class_name Game
extends Node2D
## Main game loop: places the house's ghost, reacts to its hunts, tracks
## survival time and handles game over / restart.

const GhostScene := preload("res://scenes/ghost.tscn")
## Items the player starts with, by id (see res://items/).
const STARTING_ITEMS: Array[StringName] = [&"lantern", &"thermometer", &"emf_reader", &"doll", &"uv_light", &"journal"]

## The running game, so items can find the house, ghost, etc.
static var current: Game

## Fraction of full sanity lost each time the ghost catches the player
## (0.5 = 50%: two catches empty even a full sanity bar).
@export_range(0.0, 1.0) var catch_sanity_cost := 0.5
## Debug: draw the ghost faintly while it's invisible.
@export var debug_show_ghost := false
## Debug: show the exact sanity percentage on the sanity bar (players
## normally have to estimate it from the bar).
@export var debug_show_sanity_number := false
## Debug: start the game with sanity right at the point where the ghost is
## allowed to hunt (its hunt_sanity_threshold), to test hunts without waiting.
@export var debug_start_at_hunt_threshold := false

@onready var house: House = $House
@onready var world: Node2D = $World
@onready var player: Player = $World/Player
@onready var darkness: CanvasModulate = $Darkness
@onready var temperatures: RoomTemperatures = $RoomTemperatures
@onready var toolbar: Control = $HUD/Toolbar
@onready var journal_panel: JournalPanel = $HUD/JournalPanel
@onready var time_label: Label = $HUD/TimeLabel
@onready var message_label: Label = $HUD/MessageLabel
@onready var game_over_panel: Control = $HUD/GameOver
@onready var game_over_stats: Label = $HUD/GameOver/Box/Stats
@onready var game_over_title: Label = $HUD/GameOver/Box/Title
@onready var sanity_bar: ProgressBar = $HUD/SanityBar
@onready var hurt_flash: ColorRect = $HUD/HurtFlash
@onready var sanity_text: Label = $HUD/SanityBar/SanityText

var survived_time := 0.0
var hunts := 0
var is_game_over := false
var times_caught := 0
var _game_over_reason := ""
## The ghost haunting the house. It exists for the whole game.
var ghost: Ghost
## The type of ghost haunting the house this game. The player's goal is to
## work this out from how the ghost behaves.
var ghost_type: GhostBehavior.Type
var _base_darkness: Color


func _ready() -> void:
	current = self
	randomize()
	# Always on in the game. (Hide the Darkness and HUD nodes in the editor
	# while painting the map - they cover/darken the editor view too.)
	darkness.visible = true
	$HUD.visible = true
	_base_darkness = darkness.color
	player.global_position = house.get_player_start()
	_fit_camera_to_house()
	var furniture: Array[Rect2] = []
	for obstacle in get_tree().get_nodes_in_group("nav_obstacles"):
		furniture.append(obstacle.get_footprint())
	house.build_navigation(furniture)
	game_over_panel.visible = false
	player.sanity_depleted.connect(_on_player_sanity_depleted)
	_spawn_ghost()
	if debug_start_at_hunt_threshold:
		# Just under the line where this ghost (type included) may start hunting.
		var threshold := ghost.behavior.get_hunt_sanity_threshold(ghost.hunt_sanity_threshold)
		player.sanity = player.max_sanity * threshold - 0.01
	temperatures.setup(house, ghost)
	for id in STARTING_ITEMS:
		player.inventory.add_item(ItemDB.create(id))
	toolbar.player = player
	_show_message("Something feels wrong in this house...", 3.0)


## F11 switches between fullscreen and a window.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if is_game_over:
		if Input.is_action_just_pressed("restart"):
			get_tree().reload_current_scene()
		return
	survived_time += delta
	time_label.text = "Survived: %ds" % int(survived_time)
	_update_sanity_bar()


## Stops the camera scrolling far past the edges of the painted map.
func _fit_camera_to_house() -> void:
	var camera := player.get_node("Camera2D") as Camera2D
	var area := house.get_bounds().grow(24.0)
	camera.limit_left = floori(area.position.x)
	camera.limit_top = floori(area.position.y)
	camera.limit_right = ceili(area.end.x)
	camera.limit_bottom = ceili(area.end.y)


## Places the ghost somewhere in its favourite room at the start of the game.
func _spawn_ghost() -> void:
	ghost_type = GhostBehavior.random_type()
	ghost = GhostScene.instantiate() as Ghost
	ghost.player = player
	ghost.house = house
	ghost.set_type(ghost_type)
	ghost.favorite_room = house.get_room_names().pick_random()
	ghost.debug_reveal = debug_show_ghost
	# Don't start the ghost right on top of the player.
	var start := house.random_point_in_room(ghost.favorite_room)
	for i in 20:
		if start.distance_to(player.global_position) > 48.0:
			break
		start = house.random_point_in_room(ghost.favorite_room)
	ghost.global_position = start
	ghost.hunt_started.connect(_on_ghost_hunt_started)
	ghost.hunt_ended.connect(_on_ghost_hunt_ended)
	ghost.caught_player.connect(_on_ghost_caught_player)
	ghost.interacted.connect(_on_ghost_interacted)
	world.add_child(ghost)
	if OS.is_debug_build():
		print("[debug] This house is haunted by a %s whose favourite room is the %s" % [
			GhostBehavior.type_name(ghost_type), ghost.favorite_room.to_lower()])


func _on_ghost_hunt_started() -> void:
	hunts += 1
	_flicker_lights()


func _on_ghost_hunt_ended() -> void:
	_show_message("It's gone... for now.", 2.0)


func _on_ghost_interacted(item: GhostInteractable) -> void:
	if OS.is_debug_build():
		print("[debug] The ghost %s" % item.describe_last_interaction())


## Being caught costs a big chunk of sanity (the ghost ends its hunt). If it
## empties their sanity, the game is over.
func _on_ghost_caught_player() -> void:
	times_caught += 1
	_flash_hurt()
	_game_over_reason = "THE GHOST GOT YOU"
	player.lose_sanity(player.max_sanity * catch_sanity_cost)
	if not is_game_over:
		_game_over_reason = ""
		_show_message("It got you... your mind is slipping.", 3.0)


func _on_player_sanity_depleted() -> void:
	if is_game_over:
		return
	is_game_over = true
	ghost.set_physics_process(false)
	journal_panel.close()
	player.die()
	message_label.visible = false
	game_over_title.text = _game_over_reason if _game_over_reason != "" else "YOUR SANITY RAN OUT"
	game_over_stats.text = "You survived %d seconds and were caught %d time%s." % [
		int(survived_time), times_caught, "" if times_caught == 1 else "s"]
	game_over_panel.visible = true


func _update_sanity_bar() -> void:
	var ratio := player.sanity_ratio
	sanity_bar.max_value = player.max_sanity
	sanity_bar.value = player.sanity
	if debug_show_sanity_number:
		sanity_text.text = "Sanity %.1f%%" % (ratio * 100.0)
	else:
		sanity_text.text = "Sanity"
	# Calm blue when full, through purple, to red when nearly gone.
	var calm := Color(0.45, 0.75, 0.95)
	var uneasy := Color(0.62, 0.4, 0.85)
	var panic := Color(0.85, 0.15, 0.18)
	var color := uneasy.lerp(calm, (ratio - 0.5) * 2.0) if ratio > 0.5 else panic.lerp(uneasy, ratio * 2.0)
	(sanity_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = color


func _flash_hurt() -> void:
	var tween := create_tween()
	hurt_flash.color.a = 0.55
	tween.tween_property(hurt_flash, "color:a", 0.0, 0.8)


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


## For the identification goal later: returns true if the player's guess
## matches this game's ghost type.
func is_correct_guess(guess: GhostBehavior.Type) -> bool:
	return guess == ghost_type
