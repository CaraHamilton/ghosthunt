class_name MenuWindow
extends CenterContainer
## The base for the game's pop-up windows (PotionMenu, ConfirmMenu): a
## bordered panel in the middle of the screen, built in code as a
## placeholder (Game adds them to the HUD). Subclasses fill `content` in
## _build.
##
## While a window is open the player can't move or use items, but the game
## keeps running (the ghost carries on - even hunting). Esc closes it, and so
## does the player dying.

## The panel's column: subclasses add their labels and buttons here.
var content: VBoxContainer
var _player: Player


func _ready() -> void:
	visible = false
	# Covers the screen (so clicks don't reach the game) with the window in
	# the middle.
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.07, 0.11, 0.95)
	style.border_color = Color(0.86, 0.8, 0.68)
	style.set_border_width_all(3)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	content = VBoxContainer.new()
	panel.add_child(content)
	_build()


## Override to add the window's contents to `content`.
func _build() -> void:
	pass


## Override to forget anything the window was opened with (called by close).
func _on_closed() -> void:
	pass


## Subclasses' open() calls this to show the window and freeze `player`.
func _show_for(player: Player) -> void:
	_player = player
	visible = true
	player.set_in_menu(true)


func close() -> void:
	if not visible:
		return
	visible = false
	if is_instance_valid(_player):
		_player.set_in_menu(false)
	_player = null
	_on_closed()


## A text label for `content`, centred.
func _make_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	return label


## A button that doesn't steal keyboard focus (so Space/E keep working).
func _make_button(text: String, size: Vector2, font_size: int, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = size
	button.add_theme_font_size_override("font_size", font_size)
	button.pressed.connect(on_pressed)
	return button


func _process(_delta: float) -> void:
	if visible and _player.is_dead:
		close()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
