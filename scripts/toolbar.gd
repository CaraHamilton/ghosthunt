extends Control
## Stardew-style toolbar along the bottom of the screen. Shows the first
## slots of the player's inventory, highlights the selected one, and shows
## the active item's text readout, if it has one, above it
## while in use. Stacks show their count in the corner.
##
## The bar (slot numbers included) is res://art/toolbar.png and the selection
## res://art/toolbar_select.png, both exported at 3x. The constants below say
## where the slots are in the bar art, in its 1x pixels.

const BAR := preload("res://art/toolbar.png")
const SELECT := preload("res://art/toolbar_select.png")
## How much bigger the art is drawn than its Aseprite pixels.
const ART_SCALE := 3.0
## Top-left of the first slot's box.
const FIRST_SLOT := Vector2(4, 4)
## Distance from one slot to the next (box + gap).
const SLOT_STEP := 22.0
## Width/height of a slot's box. Icons (16px) sit in the middle.
const SLOT_SIZE := 20.0
const ICON_SIZE := 16.0

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


## Slot `i`'s box, in screen pixels relative to the toolbar.
func slot_rect(i: int) -> Rect2:
	var pos := FIRST_SLOT + Vector2(i * SLOT_STEP, 0)
	return Rect2(pos * ART_SCALE, Vector2.ONE * SLOT_SIZE * ART_SCALE)


func _draw() -> void:
	if player == null:
		return
	draw_texture(BAR, Vector2.ZERO)
	var font := get_theme_default_font()
	for i in Player.TOOLBAR_SLOTS:
		var rect := slot_rect(i)
		var item := player.inventory.get_item(i)
		if item:
			item.draw_icon(self, rect.grow(-(SLOT_SIZE - ICON_SIZE) / 2.0 * ART_SCALE))
			if item.count > 1:
				draw_string(font, rect.end - Vector2(18, 6), str(item.count),
					HORIZONTAL_ALIGNMENT_RIGHT, 14, 13, Color("2a1a10"))
	# The highlight is centred on the selected slot (it can be bigger than it).
	var selected := slot_rect(player.selected_slot)
	draw_texture(SELECT, selected.get_center() - SELECT.get_size() / 2.0)
