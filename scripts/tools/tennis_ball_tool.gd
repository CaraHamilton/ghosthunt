class_name TennisBallTool
extends Tool
## Places a tennis ball on the floor in front of the player (F / left mouse).
## Walk up to it and press E to pick it back up. While it's on the floor the
## toolbar slot shows an empty outline.
##
## Tip for the player: some ghosts play with the ball, but only when it's
## close to them - so put it in the ghost's favourite room.

const BallScene := preload("res://scenes/tennis_ball.tscn")
## How far in front of the player the ball is placed (px).
const PLACE_DISTANCE := 10.0

var is_placed := false
var ball: TennisBall

var _house: House
var _world: Node2D


func _init(house: House, world: Node2D) -> void:
	display_name = "Tennis Ball"
	_house = house
	_world = world
	ball = BallScene.instantiate()
	ball.picked_up.connect(_on_ball_picked_up)


func start_use() -> void:
	if is_placed:
		return
	var spot := player.global_position + player.facing * PLACE_DISTANCE
	if not _house.is_walkable(spot):
		spot = player.global_position  # too close to a wall: drop it at our feet
	ball.global_position = spot
	_world.add_child(ball)
	is_placed = true
	player.tools_changed.emit()


## The ball isn't freed automatically while it's out of the scene (in the
## player's pocket), so clean it up along with the tool.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(ball) and not ball.is_inside_tree():
		ball.free()


func _on_ball_picked_up() -> void:
	player.unregister_interactable(ball)
	ball.set_prompt_visible(false)
	_world.remove_child(ball)
	is_placed = false
	player.tools_changed.emit()


func draw_icon(canvas: CanvasItem, rect: Rect2) -> void:
	var c := rect.get_center()
	var r := rect.size.x * 0.3
	if is_placed:
		# Out on the floor - just a faint outline in the slot
		canvas.draw_arc(c, r, 0.0, TAU, 24, Color(0.3, 0.25, 0.2, 0.6), 2.0)
		return
	canvas.draw_circle(c, r, Color("d8f040"))
	canvas.draw_arc(c + Vector2(-r * 0.9, 0), r * 0.75, -PI * 0.4, PI * 0.4, 10, Color.WHITE, 2.0)
	canvas.draw_arc(c + Vector2(r * 0.9, 0), r * 0.75, PI * 0.6, PI * 1.4, 10, Color.WHITE, 2.0)
	canvas.draw_arc(c, r, 0.0, TAU, 24, Color("8a9a20"), 1.5)
