class_name Game
extends Node2D
## Main game loop: places the house's ghost, reacts to its hunts, tracks
## survival time and handles game over / restart.

const GhostScene := preload("res://scenes/ghost.tscn")
## Items the player starts with, by id (see res://items/). Stackable ones
## (holy water) start as a full stack.
const STARTING_ITEMS: Array[StringName] = [&"lantern", &"thermometer", &"emf_reader", &"doll", &"uv_light", &"fog_machine", &"holy_water", &"journal"]

## The running game, so items can find the house, ghost, etc.
static var current: Game

@export_group("Debug")
# (Also handy for testing: Player -> Sanity -> Start Sanity.)
## Debug: draw the ghost faintly while it's invisible.
@export var debug_show_ghost := false
## Debug: show the exact sanity percentage on the sanity bar (players
## normally have to estimate it from the bar).
@export var debug_show_sanity_number := false
## Debug: start the game with sanity right at the point where the ghost is
## allowed to hunt (its hunt_sanity_threshold), to test hunts without waiting.
@export var debug_start_at_hunt_threshold := false
@export_group("")

## How long (s) EMF from something the ghost did lasts (see EMFSource).
@export var emf_duration := 60.0

@export_group("Sound")
## Untick to turn the background song/ambience off.
@export var play_background_ambience := true
## Background song or ambience, looped the whole game. Empty uses
## res://audio/ambience/background (.ogg, .mp3 or .wav), if there is one.
@export var background_ambience: AudioStream
## How loud it is (dB; 0 = as exported, -6 = about half, -12 = about a quarter).
@export var background_volume_db := -10.0
@export_group("")

@onready var house: House = $House
@onready var world: Node2D = $World
@onready var player: Player = $World/Player
@onready var darkness: CanvasModulate = $Darkness
@onready var temperatures: RoomTemperatures = $RoomTemperatures
@onready var toolbar: Control = $HUD/Toolbar
@onready var journal_panel: JournalPanel = $HUD/JournalPanel
@onready var thermometer_overlay: ToolOverlay = $HUD/ThermometerOverlay
@onready var emf_overlay: ToolOverlay = $HUD/EmfOverlay
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
## The ghost haunting the house. It exists for the whole game.
var ghost: Ghost
## The type of ghost haunting the house this game. The player's goal is to
## work this out from how the ghost behaves.
var ghost_type: GhostBehavior.Type
## What the EMF reader can pick up right now (see EMFSource).
var emf_sources: Array[EMFSource] = []

## How long (s) the screen takes to fade out (and back in) going through a
## door.
const DOOR_FADE_TIME := 0.3
## Doors do nothing for this long (s) after the game starts - the player may
## start standing on one.
const DOOR_START_GRACE := 0.5

## How long (s) the ritual's cutscene lasts, from starting it to the outcome.
const RITUAL_TIME := 5.0
## When (s into the ritual) the ghost appears in front of the player.
const RITUAL_GHOST_TIME := 1.5
## How far (px) from the player the ghost appears during the ritual.
const RITUAL_GHOST_DISTANCE := 36.0

## The potion cabinet's window (see PotionCabinet), built in _ready.
var potion_menu: PotionMenu
## True from starting the ritual on (it can only happen once).
var ritual_started := false
## The ghost type the ritual's potion was for.
var _ritual_guess := GhostBehavior.Type.BANSHEE
var _ritual_circle: RitualCircle

var _fade: ColorRect
var _traveling := false
## The Darkness colour indoors (from the scene); outdoor areas have their own.
var _inside_darkness := Color.BLACK


## Something the ghost did now gives off EMF: `at` is the object (a Node2D,
## followed if it moves) or a spot (Vector2). The level is rolled from
## `min_level`-`max_level`, or 5 with `chance_5` for ghosts that show EMF 5.
func add_emf_source(at: Variant, min_level: int, max_level: int, chance_5: float) -> EMFSource:
	var source := EMFSource.new()
	source.level = EMFSource.roll_level(min_level, max_level, chance_5, ghost.behavior if ghost else null)
	if at is Node2D:
		source.node = at
		# A fresh touch replaces the object's old EMF.
		emf_sources = emf_sources.filter(func(s: EMFSource) -> bool: return s.node != at)
	else:
		source.position = at
	source.created = game_time()
	source.duration = emf_duration
	emf_sources.append(source)
	if OS.is_debug_build():
		print("[debug] EMF %d at %s" % [source.level, at.name if at is Node2D else str(at)])
	return source


## The strongest EMF within `reach` px of `point` right now (0 if none) - what
## an EMF reader there shows (see EMFReader).
func emf_level_at(point: Vector2, reach: float) -> int:
	var best := 0
	for source in emf_sources:
		if source.reaches(point, reach):
			best = maxi(best, source.level)
	return best


## Seconds of game time (stops while paused, follows Engine.time_scale).
static func game_time() -> float:
	return Engine.get_physics_frames() / float(Engine.physics_ticks_per_second)


func _ready() -> void:
	current = self
	randomize()
	# Always on in the game. (Hide the Darkness and HUD nodes in the editor
	# while painting the map - they cover/darken the editor view too.)
	darkness.visible = true
	$HUD.visible = true
	player.global_position = house.get_player_start()
	_inside_darkness = darkness.color
	_build_fade()
	potion_menu = PotionMenu.new()
	$HUD.add_child(potion_menu)
	$HUD.move_child(potion_menu, game_over_panel.get_index())  # under the end screen
	_enter_current_area()
	var furniture: Array[Rect2] = []
	for obstacle in get_tree().get_nodes_in_group("nav_obstacles"):
		furniture.append(obstacle.get_footprint())
	house.build_navigation(furniture)
	game_over_panel.visible = false
	_spawn_ghost()
	_start_background_ambience()
	if debug_start_at_hunt_threshold:
		# Just under the line where this ghost (type included) may start hunting.
		var threshold := ghost.behavior.get_hunt_sanity_threshold(ghost.hunt_sanity_threshold)
		player.sanity = player.max_sanity * threshold - 0.01
	temperatures.setup(house, ghost)
	for id in STARTING_ITEMS:
		player.inventory.add_item(ItemDB.create(id, ItemDB.get_data(id).max_stack))
	toolbar.player = player
	thermometer_overlay.player = player
	emf_overlay.player = player


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
	survived_time += delta  # shown on the game over screen
	# Faded EMF (and EMF from objects that are gone) stops showing.
	var now := game_time()
	emf_sources = emf_sources.filter(func(s: EMFSource) -> bool: return s.is_active(now))
	_update_sanity_bar()


## Stops the camera scrolling far past the edges of `bounds` (the house, or
## the outdoor area the player is in).
func _fit_camera_to(bounds: Rect2) -> void:
	var camera := player.get_node("Camera2D") as Camera2D
	var area := bounds.grow(24.0)
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
	ghost.caught_player.connect(_on_ghost_caught_player)
	ghost.interacted.connect(_on_ghost_interacted)
	world.add_child(ghost)
	if OS.is_debug_build():
		print("[debug] This house is haunted by a %s whose favourite room is the %s" % [
			GhostBehavior.type_name(ghost_type), ghost.favorite_room.to_lower()])


func _on_ghost_hunt_started() -> void:
	hunts += 1


func _on_ghost_interacted(item: GhostInteractable) -> void:
	if OS.is_debug_build():
		print("[debug] The ghost %s" % item.describe_last_interaction())


## Being caught by the ghost is game over. (Running out of sanity isn't -
## it just keeps the ghost hunting.)
func _on_ghost_caught_player() -> void:
	if is_game_over:
		return
	times_caught += 1
	_flash_hurt()
	ghost.set_physics_process(false)
	player.die()
	if ritual_started:
		if is_instance_valid(_ritual_circle):
			_ritual_circle.fade_out(0.5)
		_show_end_screen("THE RITUAL FAILED", "That wasn't a %s - it was a %s." % [
			GhostBehavior.type_name(_ritual_guess), GhostBehavior.type_name(ghost_type)], LOSE_COLOR)
	else:
		_show_end_screen("THE GHOST GOT YOU", "You survived %d seconds." % int(survived_time), LOSE_COLOR)


const LOSE_COLOR := Color(0.9, 0.3, 0.35)
const WIN_COLOR := Color(0.55, 0.9, 0.6)


## Ends the game with the end screen (R to play again).
func _show_end_screen(title: String, stats: String, color: Color) -> void:
	is_game_over = true
	journal_panel.close()
	potion_menu.close()
	game_over_title.text = title
	game_over_title.add_theme_color_override("font_color", color)
	game_over_stats.text = stats
	game_over_panel.visible = true


# --- The ritual -----------------------------------------------------------------

## Called when the player uses a potion. Starts the ritual if it can, and
## returns "" - or, if it can't, why not (shown above the toolbar). The
## ritual is a RITUAL_TIME second cutscene: the player stands in a glowing
## circle and the ghost is pulled in front of them. If the potion matches the
## ghost, it evaporates and the player wins; if not, it attacks - game over.
func start_ritual(potion: PotionItem) -> String:
	if is_game_over or ritual_started:
		return ""
	if not player.is_in_house():
		return "start the ritual inside the house"
	if ghost.is_hunting:
		return "not while the ghost is hunting"
	ritual_started = true
	_ritual_guess = potion.ghost_type
	journal_panel.close()
	potion_menu.close()
	player.inventory.remove_from_slot(player.inventory.slots.find(potion))
	player.set_in_menu(true)  # the player can't move or use things now
	ghost.begin_ritual()
	if OS.is_debug_build():
		print("[debug] Ritual started with the %s (the ghost is a %s)" % [
			PotionItem.name_for(_ritual_guess), GhostBehavior.type_name(ghost_type)])
	_run_ritual()
	return ""


func _run_ritual() -> void:
	_ritual_circle = RitualCircle.new()
	_ritual_circle.build_time = RITUAL_TIME
	_ritual_circle.global_position = player.global_position - Vector2(0, RitualCircle.FEET_OFFSET)
	add_child(_ritual_circle)
	Sfx.play("ritual/start")
	await get_tree().create_timer(RITUAL_GHOST_TIME, false, true).timeout
	ghost.appear_for_ritual(_ritual_ghost_spot(), player.global_position)
	await get_tree().create_timer(RITUAL_TIME - RITUAL_GHOST_TIME, false, true).timeout
	if is_game_over:
		return
	_ritual_circle.flash()
	if is_correct_guess(_ritual_guess):
		Sfx.play("ritual/success", ghost.global_position)
		ghost.evaporate(1.5)
		await get_tree().create_timer(2.0, false, true).timeout
		_ritual_circle.fade_out(1.0)
		_show_end_screen("YOU CAPTURED THE GHOST", "It was a %s. You caught it in %d seconds." % [
			GhostBehavior.type_name(ghost_type), int(survived_time)], WIN_COLOR)
	else:
		Sfx.play("ritual/fail", ghost.global_position)
		ghost.ritual_attack(player.global_position)  # caught_player -> game over


## Where the ghost appears during the ritual: RITUAL_GHOST_DISTANCE px from
## the player, on open floor they can see (above them if possible, then
## around them), closer if there's no room.
func _ritual_ghost_spot() -> Vector2:
	var from := player.global_position
	var space := get_world_2d().direct_space_state
	for distance in [RITUAL_GHOST_DISTANCE, RITUAL_GHOST_DISTANCE * 0.66, RITUAL_GHOST_DISTANCE * 0.4]:
		for i in 8:
			var dir := Vector2.UP.rotated(TAU * i / 8.0)
			var spot: Vector2 = from + dir * distance
			if not house.is_walkable(spot):
				continue
			var query := PhysicsRayQueryParameters2D.create(from, spot, Ghost.WORLD_LAYER)
			if space.intersect_ray(query).is_empty():
				return spot
	return from + Vector2(0, -16)


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


## True if the player's guess (the ritual's potion) matches this game's ghost
## type.
func is_correct_guess(guess: GhostBehavior.Type) -> bool:
	return guess == ghost_type


## Plays the background song/ambience on a loop, on the Ambience bus.
func _start_background_ambience() -> void:
	if not play_background_ambience:
		return
	var stream := background_ambience
	if stream == null:
		for ext in ["ogg", "mp3", "wav"]:
			var path := "res://audio/ambience/background.%s" % ext
			if ResourceLoader.exists(path):
				stream = load(path)
				break
	if stream == null:
		return
	# .ogg and .mp3 can loop seamlessly; a .wav without a loop starts over
	# when it ends (below).
	if "loop" in stream:
		stream.loop = true
	var music := AudioStreamPlayer.new()
	music.name = "BackgroundAmbience"
	music.stream = stream
	music.bus = &"Ambience"
	music.volume_db = background_volume_db
	music.finished.connect(music.play)
	add_child(music)
	music.play()


# --- Going outside ----------------------------------------------------------------

## The outdoor area (see Outside) that `point` is in, or null - e.g. in the
## house.
func outside_area_at(point: Vector2) -> Outside:
	for area: Outside in get_tree().get_nodes_in_group("outside_areas"):
		if area.get_bounds().has_point(point):
			return area
	return null


## Called by a Door when the player walks onto it: fades out, moves the player
## to the other door (the one with the same door_id), sets the camera and
## lighting up for where they are now, and fades back in. The house keeps
## running all the while.
func go_through(door: Door) -> void:
	if _traveling or is_game_over or game_time() < DOOR_START_GRACE:
		return
	var to := door.get_partner()
	if to == null:
		push_warning("Door %s has no other door with door_id \"%s\"" % [door.name, door.door_id])
		return
	_traveling = true
	player.set_in_menu(true)  # no walking or using things mid-fade
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, DOOR_FADE_TIME)
	await tween.finished
	player.global_position = to.get_exit_point()
	_enter_current_area()
	(player.get_node("Camera2D") as Camera2D).reset_smoothing()
	tween = create_tween()
	tween.tween_property(_fade, "color:a", 0.0, DOOR_FADE_TIME)
	await tween.finished
	if not is_game_over:
		player.set_in_menu(false)
	_traveling = false
	if OS.is_debug_build():
		var area := outside_area_at(player.global_position)
		print("[debug] The player went to the %s" % (area.name.to_lower() if area else "house"))


## Sets the camera limits and the darkness for wherever the player is: the
## house, or an outdoor area.
func _enter_current_area() -> void:
	var outside := outside_area_at(player.global_position)
	if outside:
		_fit_camera_to(outside.get_bounds())
		darkness.color = outside.darkness
	else:
		_fit_camera_to(house.get_bounds())
		darkness.color = _inside_darkness


## The black screen used to fade between areas (over everything, HUD too).
func _build_fade() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)
	add_child(layer)
