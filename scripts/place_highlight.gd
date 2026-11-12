class_name PlaceHighlight
extends CanvasLayer
## Corner brackets showing what the player is about to act on:
##   - While Q is held: the tile the selected item will be placed on when
##     it's let go (white if it can go there, red if not).
##   - While right click is held: what letting go will act on under the
##     mouse (see Player.right_click_target): a placed tool to pick up
##     (gold), or an empty tile next to the player to place
##     the held item on (white, or red if it can't go there). Red over a
##     tile too far away, or the player's own tile while holding something.
## On a table, the outline sits up on the table's top. After a blocked try it
## flashes red for a moment.
##
## It's on its own canvas layer that follows the camera, so the house's
## darkness doesn't hide it.

const OK_COLOR := Color(1, 1, 1, 0.35)
const BLOCKED_COLOR := Color(1, 0.3, 0.3, 0.45)
const TARGET_COLOR := Color(1.0, 0.85, 0.4, 0.55)
## How long (seconds) the outline flashes after a blocked try.
const FLASH_TIME := 0.3

## True while the player holds Q: the outline shows the tile in front of them.
var aiming := false
## True while the player holds right click: the outline shows what letting
## go will act on, under the mouse.
var mouse_aiming := false

var _canvas := Node2D.new()
var _rect := Rect2()
var _color := Color.TRANSPARENT
var _flash := 0.0
var _flash_rect := Rect2()


func _ready() -> void:
	follow_viewport_enabled = true
	_canvas.draw.connect(_draw_outline)
	add_child(_canvas)


## Flashes red (placing or picking up there didn't work): over `rect`, or
## over the Q tile if no rect is given.
func flash_blocked(rect := Rect2()) -> void:
	_flash = FLASH_TIME
	_flash_rect = rect
	Sfx.play("ui/blocked")


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta)
	var player := get_parent() as Player
	var game := Game.current
	_rect = Rect2()
	if game != null and not player.is_dead and not player.in_menu:
		if _flash > 0.0 and _flash_rect.has_area():
			_rect = _flash_rect
			_color = BLOCKED_COLOR
		elif (aiming or _flash > 0.0) and player.selected_item != null:
			var spot := player.place_spot()
			_rect = spot.rect
			_color = OK_COLOR if spot.ok else BLOCKED_COLOR
		elif mouse_aiming:
			var target := player.right_click_target(player.get_global_mouse_position())
			match target.kind:
				&"pick_up":
					_rect = target.rect
					_color = TARGET_COLOR
				&"place":
					_rect = target.rect
					_color = OK_COLOR if target.spot.ok else BLOCKED_COLOR
				&"blocked":
					_rect = target.rect
					_color = BLOCKED_COLOR
	if _flash > 0.0:
		_color.a = 0.9
	_canvas.queue_redraw()


func _draw_outline() -> void:
	if _rect.has_area():
		draw_corners(_rect.grow(-0.5), _color)


## Stardew-style corner brackets (lighter than a full box).
func draw_corners(r: Rect2, color: Color) -> void:
	var l := 4.0
	for corner: Vector2 in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		var sx := 1.0 if corner.x == r.position.x else -1.0
		var sy := 1.0 if corner.y == r.position.y else -1.0
		_canvas.draw_line(corner, corner + Vector2(sx * l, 0), color, 1.0)
		_canvas.draw_line(corner, corner + Vector2(0, sy * l), color, 1.0)
