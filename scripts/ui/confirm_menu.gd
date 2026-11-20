class_name ConfirmMenu
extends MenuWindow
## A yes/no question window, e.g. "Use the Banshee Potion?" (see
## Game.ask_to_use_potion). Yes runs the callback it was opened with; No, Esc
## or the player dying just closes it. (The window itself - and freezing the
## player - is MenuWindow.)

var _on_yes: Callable
var _question: Label


func _build() -> void:
	content.add_theme_constant_override("separation", 14)
	_question = _make_label("", 24)
	content.add_child(_question)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	content.add_child(buttons)
	buttons.add_child(_make_button("Yes", Vector2(120, 40), 18, _answer.bind(true)))
	buttons.add_child(_make_button("No", Vector2(120, 40), 18, _answer.bind(false)))


## Shows `question` (in `color`); `on_yes` is called if the player picks Yes.
func open(question: String, player: Player, on_yes: Callable, color := Color.WHITE) -> void:
	_question.text = question
	_question.add_theme_color_override("font_color", color)
	_on_yes = on_yes
	_show_for(player)


func _on_closed() -> void:
	_on_yes = Callable()


func _answer(yes: bool) -> void:
	var on_yes := _on_yes
	close()
	if yes and on_yes.is_valid():
		on_yes.call()
