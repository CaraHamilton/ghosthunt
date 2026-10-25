@tool
class_name Room
extends ReferenceRect
## One named room of the house - just a rectangle you drag and resize in the
## editor (it's invisible in the game). Used for room temperatures, the
## ghost's favourite room, the EMF reader, wandering, etc.
##
## Put Room nodes under House/Rooms. The room's name is `room_name`, or the
## node's name if that's left empty. Cover only the floor of the room, not
## its walls; doorways between rooms can be left outside every room.

## The name shown in debug output and used to tell rooms apart.
@export var room_name := "":
	set(value):
		room_name = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func get_room_name() -> String:
	return room_name if room_name != "" else String(name)


## The room's area in world coordinates.
func get_world_rect() -> Rect2:
	return get_global_rect()


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_string(ThemeDB.fallback_font, Vector2(4, 12), get_room_name(),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, border_color)
