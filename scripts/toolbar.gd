extends Control
## Stardew-style toolbar along the bottom of the screen. Draws one slot per
## toolbar slot, highlights the selected one, and shows the active tool's
## readout (e.g. the thermometer's temperature) above it while in use.

const SLOT_SIZE := 56.0
const SLOT_GAP := 6.0

var player: Player:
	set(value):
		player = value
		player.tools_changed.connect(queue_redraw)
		queue_redraw()

@onready var readout: Label = $Readout


func _process(_delta: float) -> void:
	if player == null:
		return
	var text := player.selected_tool.get_readout() if player.is_using_tool else ""
	readout.text = text
	readout.visible = text != ""


func _draw() -> void:
	if player == null:
		return
	for i in Player.TOOLBAR_SLOTS:
		var rect := Rect2(Vector2(i * (SLOT_SIZE + SLOT_GAP), 0), Vector2(SLOT_SIZE, SLOT_SIZE))
		var selected := i == player.selected_slot
		draw_rect(rect, Color("3b2a1e") if not selected else Color("6b4a2e"))
		draw_rect(rect.grow(-3), Color("d9b98a"))
		draw_rect(rect, Color("f2d36b") if selected else Color("1e140d"), false, 3.0 if selected else 2.0)
		var tool := player.tools[i]
		if tool:
			tool.draw_icon(self, rect.grow(-6))
		draw_string(get_theme_default_font(), rect.position + Vector2(5, 15), str(i + 1),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("5e3a25"))
