extends Control
## Stardew-style toolbar along the bottom of the screen. Shows the first
## slots of the player's inventory, highlights the selected one, and shows
## the active item's readout (e.g. the thermometer's temperature) above it
## while in use. Stacks show their count in the corner.

const SLOT_SIZE := 60.0  # icons get SLOT_SIZE - 12 = 48px: 16px art at 3x, like the world
const SLOT_GAP := 6.0

var player: Player:
	set(value):
		player = value
		player.inventory.changed.connect(queue_redraw)
		queue_redraw()

@onready var readout: Label = $Readout


func _process(_delta: float) -> void:
	if player == null:
		return
	var item := player.selected_item
	var text := item.get_readout() if player.is_using_item and item else ""
	readout.text = text
	readout.visible = text != ""


func _draw() -> void:
	if player == null:
		return
	var font := get_theme_default_font()
	for i in Player.TOOLBAR_SLOTS:
		var rect := Rect2(Vector2(i * (SLOT_SIZE + SLOT_GAP), 0), Vector2(SLOT_SIZE, SLOT_SIZE))
		var selected := i == player.selected_slot
		draw_rect(rect, Color("3b2a1e") if not selected else Color("6b4a2e"))
		draw_rect(rect.grow(-3), Color("d9b98a"))
		draw_rect(rect, Color("f2d36b") if selected else Color("1e140d"), false, 3.0 if selected else 2.0)
		var item := player.inventory.get_item(i)
		if item:
			item.draw_icon(self, rect.grow(-6))
			if item.count > 1:
				draw_string(font, rect.end - Vector2(18, 6), str(item.count),
					HORIZONTAL_ALIGNMENT_RIGHT, 14, 13, Color("2a1a10"))
		draw_string(font, rect.position + Vector2(5, 15), str((i + 1) % 10),  # slot 10 is the 0 key
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("5e3a25"))
