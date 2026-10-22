extends Node2D
## Main game loop: places the house's ghost, reacts to its hunts, tracks
## survival time and handles game over / restart.

const GhostScene := preload("res://scenes/ghost.tscn")

@export var base_ghost_speed := 60.0
## Each hunt the ghost gets a little faster.
@export var ghost_speed_per_hunt := 4.0
## Debug: draw the ghost faintly while it's invisible.
@export var debug_show_ghost := false

@onready var house: House = $House
@onready var world: Node2D = $World
@onready var player: Player = $World/Player
@onready var darkness: CanvasModulate = $Darkness
@onready var temperatures: RoomTemperatures = $RoomTemperatures
@onready var toolbar: Control = $HUD/Toolbar
@onready var time_label: Label = $HUD/TimeLabel
@onready var message_label: Label = $HUD/MessageLabel
@onready var hide_overlay: ColorRect = $HUD/HideOverlay
@onready var game_over_panel: Control = $HUD/GameOver
@onready var game_over_stats: Label = $HUD/GameOver/Box/Stats

var survived_time := 0.0
var hunts := 0
var is_game_over := false
## The ghost haunting the house. It exists for the whole game.
var ghost: Ghost
## The type of ghost haunting the house this game. The player's goal is to
## work this out from how the ghost behaves.
var ghost_type: GhostBehavior.Type
var _base_darkness: Color


func _ready() -> void:
	randomize()
	_base_darkness = darkness.color
	player.global_position = house.PLAYER_START
	var furniture: Array[Rect2] = []
	for obstacle in get_tree().get_nodes_in_group("nav_obstacles"):
		furniture.append(obstacle.get_footprint())
	house.build_navigation(furniture)
	player.hidden_changed.connect(_on_player_hidden_changed)
	game_over_panel.visible = false
	hide_overlay.visible = false
	_spawn_ghost()
	temperatures.setup(house, ghost)
	player.give_tool(Thermometer.new(house, temperatures))
	player.give_tool(EMFReader.new(house, ghost))
	player.give_tool(TennisBallTool.new(house, world))
	player.give_tool(UVLight.new())
	toolbar.player = player
	_show_message("Something feels wrong in this house...", 3.0)


func _process(delta: float) -> void:
	if is_game_over:
		if Input.is_action_just_pressed("restart"):
			get_tree().reload_current_scene()
		return
	survived_time += delta
	time_label.text = "Survived: %ds" % int(survived_time)


## Places the ghost somewhere in its favourite room at the start of the game.
func _spawn_ghost() -> void:
	ghost_type = GhostBehavior.random_type()
	ghost = GhostScene.instantiate() as Ghost
	ghost.player = player
	ghost.house = house
	ghost.set_type(ghost_type)
	ghost.favorite_room = House.ROOMS.keys().pick_random()
	ghost.chase_speed = base_ghost_speed
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
	ghost.chase_speed = minf(base_ghost_speed + ghost_speed_per_hunt * (hunts - 1), player.run_speed - 8.0)
	_flicker_lights()


func _on_ghost_hunt_ended() -> void:
	_show_message("It's gone... for now.", 2.0)


func _on_ghost_interacted(item: GhostInteractable) -> void:
	if OS.is_debug_build():
		print("[debug] The ghost %s" % item.describe_last_interaction())


func _on_ghost_caught_player() -> void:
	is_game_over = true
	player.die()
	hide_overlay.visible = false
	message_label.visible = false
	game_over_stats.text = "You survived %d seconds." % int(survived_time)
	game_over_panel.visible = true


func _on_player_hidden_changed(is_hidden: bool) -> void:
	hide_overlay.visible = is_hidden
	toolbar.visible = not is_hidden


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
