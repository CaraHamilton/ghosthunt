extends Control
## The map select menu: a button for every house scene in res://scenes/houses/.
## To add a map, save another house scene in that folder - it shows up here
## automatically ("house_2.tscn" becomes "House 2").

const HOUSES_DIR := "res://scenes/houses/"
const GAME_SCENE := "res://scenes/main.tscn"

@onready var buttons: VBoxContainer = $Box/Buttons


func _ready() -> void:
	for path in _find_houses():
		var button := Button.new()
		button.text = path.get_file().get_basename().capitalize()
		button.pressed.connect(_play.bind(path))
		buttons.add_child(button)
	if buttons.get_child_count() > 0:
		(buttons.get_child(0) as Button).grab_focus()  # so arrow keys + Enter work


## F11 switches between fullscreen and a window (same as in the game).
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
		get_viewport().set_input_as_handled()


## Every house scene in HOUSES_DIR, in name order.
func _find_houses() -> Array[String]:
	var paths: Array[String] = []
	for file in ResourceLoader.list_directory(HOUSES_DIR):
		if file.get_extension() == "tscn":
			paths.append(HOUSES_DIR + file)
	paths.sort()
	return paths


func _play(house_path: String) -> void:
	Game.selected_house = house_path
	get_tree().change_scene_to_file(GAME_SCENE)
