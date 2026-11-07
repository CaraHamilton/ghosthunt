class_name PlaceHighlight
extends CanvasLayer
## While Q is held, outlines the tile the selected item will be placed on
## when it's let go: white if it can go there, red if not (a wall,
## furniture, or another item is in the way). On a table, the outline sits
## up on the table's top.
##
## It's on its own canvas layer that follows the camera, so the house's
## darkness doesn't hide it.

const OK_COLOR := Color(1, 1, 1, 0.35)
const BLOCKED_COLOR := Color(1, 0.3, 0.3, 0.45)
## How long (seconds) the outline flashes after trying to place on a
## blocked tile.
const FLASH_TIME := 0.3

## True while the player holds Q: the outline shows (it also shows briefly
## after a blocked try, to flash red).
var aiming := false

var _canvas := Node2D.new()
var _spot := {}
var _flash := 0.0


func _ready() -> void:
	follow_viewport_enabled = true
	_canvas.draw.connect(_draw_outline)
	add_child(_canvas)


## Briefly brightens the outline (placing there didn't work).
func flash_blocked() -> void:
	_flash = FLASH_TIME


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta)
	var player := get_parent() as Player
	var game := Game.current
	var active := game != null and (aiming or _flash > 0.0) and player.selected_item != null \
		and not player.is_dead and not player.in_menu
	_spot = player.place_spot() if active else {}
	_canvas.queue_redraw()


func _draw_outline() -> void:
	if _spot.is_empty():
		return
	var color := OK_COLOR if _spot.ok else BLOCKED_COLOR
	if _flash > 0.0:
		color.a = 0.9
	var r: Rect2 = _spot.rect
	draw_corners(r.grow(-0.5), color)


## Stardew-style corner brackets (lighter than a full box).
func draw_corners(r: Rect2, color: Color) -> void:
	var l := 4.0
	for corner: Vector2 in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		var sx := 1.0 if corner.x == r.position.x else -1.0
		var sy := 1.0 if corner.y == r.position.y else -1.0
		_canvas.draw_line(corner, corner + Vector2(sx * l, 0), color, 1.0)
		_canvas.draw_line(corner, corner + Vector2(0, sy * l), color, 1.0)
