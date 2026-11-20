class_name PotionMenu
extends MenuWindow
## The craft table's window: one button per ghost type's potion. Each
## click puts that potion in the player's toolbar; the window stays open so
## they can take several (as many as the toolbar holds). Close with Esc or
## Close. (The window itself - and freezing the player - is MenuWindow.)

var _table: CraftTable
var _note: Label


func _build() -> void:
	content.add_theme_constant_override("separation", 10)
	content.add_child(_make_label("Craft Table", 28))
	_note = _make_label("", 16)
	content.add_child(_note)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	content.add_child(grid)
	for type: GhostBehavior.Type in GhostBehavior.Type.values():
		var button := _make_button(PotionItem.name_for(type), Vector2(200, 44), 18,
			_on_potion_pressed.bind(type))
		button.add_theme_color_override("font_color", PotionItem.color_for(type).lightened(0.35))
		grid.add_child(button)

	var cancel := _make_button("Close", Vector2(140, 36), 16, close)
	cancel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(cancel)


func open(table: CraftTable, player: Player) -> void:
	_table = table
	_note.text = "Use a potion in the ghost's favourite room."
	_note.add_theme_color_override("font_color", Color(0.8, 0.78, 0.9))
	_show_for(player)


func _on_closed() -> void:
	_table = null


func _on_potion_pressed(type: GhostBehavior.Type) -> void:
	if _table.take_potion(type, _player):
		_note.text = "Took the %s." % PotionItem.name_for(type)
		_note.add_theme_color_override("font_color", PotionItem.color_for(type).lightened(0.35))
	else:
		_note.text = "Your toolbar is full - put something down first."
		_note.add_theme_color_override("font_color", Color(0.95, 0.45, 0.45))
		Sfx.play("ui/blocked")
