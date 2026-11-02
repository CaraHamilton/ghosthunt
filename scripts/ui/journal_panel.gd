class_name JournalPanel
extends PanelContainer
## The journal window. Lists every kind of evidence, each with a box the
## player clicks through empty -> found (tick) -> ruled out (X) -> empty, and
## below it every ghost type, grayed out once the marks rule it out. Marks
## are saved on the JournalItem that opened it, so each journal keeps its
## own notes.
##
## The page is res://art/journal_page.png drawn at 3x (468x504). Spacing is
## set in journal_panel.tscn: the page style's content margins, the VBoxes'
## separation, and the Gap node between the two lists.
##
## While it's open the player can't move or use items (the game keeps
## running, so the ghost can still hunt). Close with F, Esc or the button.

const INK := Color("000000")
## Ghost types that don't fit the marked evidence.
const GRAYED_INK := Color("adab8c")
## The box shown for each JournalItem.Mark.
const BOX_ICONS := {
	JournalItem.Mark.NONE: preload("res://art/journal_checkbox_empty.png"),
	JournalItem.Mark.FOUND: preload("res://art/journal_checkbox_check.png"),
	JournalItem.Mark.RULED_OUT: preload("res://art/journal_checkbox_x.png"),
}

## Look of an evidence row, and of one under the mouse.
@export var row_style: StyleBox
@export var row_hover_style: StyleBox

var _journal: JournalItem
var _player: Player
var _evidence_rows := {}   # Evidence.Type -> Button
var _ghost_rows := {}   # GhostBehavior.Type -> Label

@onready var evidence_list: VBoxContainer = %EvidenceList
@onready var ghost_list: VBoxContainer = %GhostList
@onready var close_button: Button = %CloseButton


func _ready() -> void:
	visible = false
	for evidence: Evidence.Type in Evidence.Type.values():
		var row := Button.new()
		row.text = Evidence.name_of(evidence)
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.focus_mode = Control.FOCUS_NONE
		row.add_theme_font_size_override("font_size", 20)
		row.add_theme_constant_override("h_separation", 8)
		for state in ["normal", "pressed", "focus"]:
			row.add_theme_stylebox_override(state, row_style)
		row.add_theme_stylebox_override("hover", row_hover_style)
		row.pressed.connect(_on_evidence_pressed.bind(evidence))
		evidence_list.add_child(row)
		_evidence_rows[evidence] = row
	for type: GhostBehavior.Type in GhostBehavior.Type.values():
		var row := Label.new()
		row.text = GhostBehavior.type_name(type)
		row.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_theme_font_size_override("font_size", 18)
		row.add_theme_color_override("font_color", INK)
		ghost_list.add_child(row)
		_ghost_rows[type] = row
	close_button.pressed.connect(close)


func open(journal: JournalItem, player: Player) -> void:
	_journal = journal
	_player = player
	_refresh()
	visible = true
	player.set_in_menu(true)


func close() -> void:
	if not visible:
		return
	visible = false
	if is_instance_valid(_player):
		_player.set_in_menu(false)
	_journal = null
	_player = null


func _process(_delta: float) -> void:
	# Close if the journal isn't in hand any more (dropped, caught...).
	if visible and (_player.selected_item != _journal or _player.is_dead):
		close()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var key_use := event is InputEventKey and event.is_action_pressed("use_tool")
	if event.is_action_pressed("ui_cancel") or key_use:
		close()
		get_viewport().set_input_as_handled()


## Clicking a row moves it on to the next mark: empty -> found -> ruled out.
func _on_evidence_pressed(evidence: Evidence.Type) -> void:
	var next := (_journal.get_mark(evidence) + 1) % JournalItem.Mark.size()
	_journal.set_mark(evidence, next)
	_refresh()


## Shows each row's mark, and grays out the ghosts that don't fit them.
func _refresh() -> void:
	for evidence in _evidence_rows:
		var mark := _journal.get_mark(evidence)
		var row: Button = _evidence_rows[evidence]
		row.icon = BOX_ICONS[mark]
		var ink := GRAYED_INK if mark == JournalItem.Mark.RULED_OUT else INK
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			row.add_theme_color_override(state, ink)
	var possible := _journal.possible_ghosts()
	for type in _ghost_rows:
		_ghost_rows[type].add_theme_color_override("font_color", INK if type in possible else GRAYED_INK)
