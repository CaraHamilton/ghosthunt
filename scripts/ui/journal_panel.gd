class_name JournalPanel
extends PanelContainer
## The journal window. Lists every kind of evidence as a checklist, and below
## it the ghost types that still fit what's been ticked. Ticks are saved on
## the JournalItem that opened it, so each journal keeps its own notes.
##
## While it's open the player can't move or use items (the game keeps
## running, so the ghost can still hunt). Close with F, Esc or the button.

const INK := Color("3a2618")
const FADED_INK := Color("8a7058")

var _journal: JournalItem
var _player: Player
var _checkboxes := {}   # Evidence.Type -> CheckBox
var _ghost_rows := {}   # GhostBehavior.Type -> Label

@onready var evidence_list: VBoxContainer = %EvidenceList
@onready var ghost_list: VBoxContainer = %GhostList
@onready var no_match: Label = %NoMatch
@onready var close_button: Button = %CloseButton


func _ready() -> void:
	visible = false
	for evidence: Evidence.Type in Evidence.Type.values():
		var box := CheckBox.new()
		box.text = Evidence.name_of(evidence)
		box.add_theme_font_size_override("font_size", 22)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			box.add_theme_color_override(state, INK)
		box.toggled.connect(_on_evidence_toggled.bind(evidence))
		evidence_list.add_child(box)
		_checkboxes[evidence] = box
	for type: GhostBehavior.Type in GhostBehavior.Type.values():
		var row := Label.new()
		var evidence_names := GhostBehavior.evidence_for(type).map(func(e): return Evidence.name_of(e))
		row.text = "%s  -  %s" % [GhostBehavior.type_name(type), ", ".join(evidence_names)]
		row.add_theme_font_size_override("font_size", 20)
		row.add_theme_color_override("font_color", INK)
		ghost_list.add_child(row)
		_ghost_rows[type] = row
	close_button.pressed.connect(close)


func open(journal: JournalItem, player: Player) -> void:
	_journal = journal
	_player = player
	for evidence in _checkboxes:
		_checkboxes[evidence].set_pressed_no_signal(journal.is_checked(evidence))
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


func _on_evidence_toggled(pressed: bool, evidence: Evidence.Type) -> void:
	_journal.set_checked(evidence, pressed)
	_refresh()


## Shows only the ghosts that fit every ticked piece of evidence.
func _refresh() -> void:
	var possible := _journal.possible_ghosts()
	for type in _ghost_rows:
		_ghost_rows[type].visible = type in possible
	no_match.visible = possible.is_empty()
