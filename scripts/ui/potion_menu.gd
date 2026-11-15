class_name PotionMenu
extends CenterContainer
## The potion cabinet's window: one button per ghost type's potion. Picking
## one puts it in the player's toolbar and empties the cabinet - only one
## potion per game, so it says so. Built in code as a placeholder (Game adds
## it to the HUD); close with Esc or Cancel.
##
## While it's open the player can't move or use items (the game keeps
## running, so the ghost carries on in the house).

var _cabinet: PotionCabinet
var _player: Player
var _note: Label


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

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.text = "Potion Cabinet"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)
	_note = Label.new()
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.add_theme_font_size_override("font_size", 16)
	box.add_child(_note)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	for type: GhostBehavior.Type in GhostBehavior.Type.values():
		var button := Button.new()
		button.text = PotionItem.name_for(type)
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(200, 44)
		button.add_theme_font_size_override("font_size", 18)
		button.add_theme_color_override("font_color", PotionItem.color_for(type).lightened(0.35))
		button.pressed.connect(_on_potion_pressed.bind(type))
		grid.add_child(button)

	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.focus_mode = Control.FOCUS_NONE
	cancel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cancel.custom_minimum_size = Vector2(140, 36)
	cancel.pressed.connect(close)
	box.add_child(cancel)


func open(cabinet: PotionCabinet, player: Player) -> void:
	_cabinet = cabinet
	_player = player
	_note.text = "You can only take one. Choose carefully."
	_note.add_theme_color_override("font_color", Color(0.8, 0.78, 0.9))
	visible = true
	player.set_in_menu(true)


func close() -> void:
	if not visible:
		return
	visible = false
	if is_instance_valid(_player):
		_player.set_in_menu(false)
	_cabinet = null
	_player = null


func _process(_delta: float) -> void:
	if visible and _player.is_dead:
		close()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _on_potion_pressed(type: GhostBehavior.Type) -> void:
	if _cabinet.take_potion(type, _player):
		close()
	else:
		_note.text = "Your toolbar is full - put something down first."
		_note.add_theme_color_override("font_color", Color(0.95, 0.45, 0.45))
		Sfx.play("ui/blocked")
