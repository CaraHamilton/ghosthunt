class_name ToolOverlay
extends Control
## Base for the big tool pictures on the right edge of the screen (the
## thermometer, the EMF reader). The overlay slides in while the player is
## using its kind of tool and slides back out when they stop. Subclasses say
## which tool they're for (_is_for) and copy what to show from it (_read).
## The node's size is set to `art_size`, and it stays centred vertically.

## Gap between the overlay and the right edge of the screen (screen px).
const EDGE_GAP := 16.0
## Seconds to slide in or out.
const SLIDE_TIME := 0.15

var player: Player

## 0 = hidden off the right edge, 1 = fully on screen.
var _shown := 0.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	size = _art_size()
	position.y = (get_parent_area_size().y - size.y) / 2.0


func _process(delta: float) -> void:
	var item := player.selected_item if player else null
	var using := player != null and player.is_using_item and item != null and _is_for(item)
	if using:
		_read(item)
	_shown = move_toward(_shown, 1.0 if using else 0.0, delta / SLIDE_TIME)
	visible = _shown > 0.0
	# Slide in from past the right edge.
	position.x = get_parent_area_size().x - (size.x + EDGE_GAP) * ease(_shown, 0.4)
	queue_redraw()


## True if this overlay shows `item`.
func _is_for(_item: ItemInstance) -> bool:
	return false


## Copies what to show from the item in use (called every frame while in use,
## so the overlay keeps showing the last reading while it slides out).
func _read(_item: ItemInstance) -> void:
	pass


## The size of the art on screen.
func _art_size() -> Vector2:
	return Vector2.ZERO
