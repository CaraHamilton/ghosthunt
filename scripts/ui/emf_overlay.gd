extends ToolOverlay
## The big EMF reader on the right edge of the screen, shown while the player
## is using one (see ToolOverlay). Its lights show the reader's level, 0-5.
##
## Each level is its own picture, exported from res://art/emf_overlay.aseprite
## at 3x: emf_overlay1.png is all lights off (level 0), up to emf_overlay6.png
## with all five lit (level 5).

const FRAMES: Array[Texture2D] = [
	preload("res://art/emf_overlay1.png"),
	preload("res://art/emf_overlay2.png"),
	preload("res://art/emf_overlay3.png"),
	preload("res://art/emf_overlay4.png"),
	preload("res://art/emf_overlay5.png"),
	preload("res://art/emf_overlay6.png"),
]

var _level := 0


func _is_for(item: ItemInstance) -> bool:
	return item is EMFReader


func _read(item: ItemInstance) -> void:
	_level = clampi((item as EMFReader).level, 0, FRAMES.size() - 1)


func _art_size() -> Vector2:
	return FRAMES[0].get_size()


func _draw() -> void:
	draw_texture(FRAMES[_level], Vector2.ZERO)
