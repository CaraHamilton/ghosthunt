@tool
class_name HidingSpot
extends StaticBody2D
## A piece of furniture the player can hide inside. The node's origin is the
## bottom-centre of the furniture's footprint (so Y-sorting works).
## Collision and the interaction zone are built from `kind` at runtime.

enum Kind { DRESSER, CLOSET, CUPBOARD }

@export var kind: Kind = Kind.DRESSER:
	set(value):
		kind = value
		queue_redraw()

const SIZES := {
	Kind.DRESSER: Vector2(28, 14),   # footprint (width, depth)
	Kind.CLOSET: Vector2(30, 12),
	Kind.CUPBOARD: Vector2(22, 12),
}
const HEIGHTS := {
	Kind.DRESSER: 14.0,   # how tall it is drawn above the footprint
	Kind.CLOSET: 30.0,
	Kind.CUPBOARD: 22.0,
}
const INTERACT_REACH := 14.0

var occupied := false
var _prompt: Label


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("hiding_spots")
	add_to_group("nav_obstacles")
	collision_layer = 1
	collision_mask = 0

	var size: Vector2 = SIZES[kind]
	var body_shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	body_shape.shape = rect
	body_shape.position = Vector2(0, -size.y / 2.0)
	add_child(body_shape)

	# Slightly larger zone around the furniture where the player can press E.
	var zone := Area2D.new()
	zone.collision_layer = 0
	zone.collision_mask = 2  # player
	var zone_shape := CollisionShape2D.new()
	var zone_rect := RectangleShape2D.new()
	zone_rect.size = size + Vector2.ONE * INTERACT_REACH * 2.0
	zone_shape.shape = zone_rect
	zone_shape.position = body_shape.position
	zone.add_child(zone_shape)
	add_child(zone)
	zone.body_entered.connect(_on_body_entered)
	zone.body_exited.connect(_on_body_exited)

	_prompt = Label.new()
	_prompt.text = "[E] Hide"
	_prompt.add_theme_font_size_override("font_size", 8)
	_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	_prompt.add_theme_constant_override("outline_size", 3)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.size = Vector2(60, 12)
	_prompt.position = Vector2(-30, -size.y - HEIGHTS[kind] - 14)
	_prompt.z_index = 20
	_prompt.visible = false
	add_child(_prompt)


func set_occupied(value: bool) -> void:
	occupied = value
	_prompt.text = "[E] Leave" if occupied else "[E] Hide"
	queue_redraw()


## The furniture's solid area on the floor, in global coordinates.
func get_footprint() -> Rect2:
	var size: Vector2 = SIZES[kind]
	return Rect2(global_position + Vector2(-size.x / 2.0, -size.y), size)


## Where the player reappears when leaving: just in front of the furniture.
func get_exit_position() -> Vector2:
	return global_position + Vector2(0, 8)


## The player shows the prompt only on the closest thing they can use.
func set_prompt_visible(value: bool) -> void:
	_prompt.visible = value


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		body.register_interactable(self)


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		body.unregister_interactable(self)


# --- Placeholder art ------------------------------------------------------

func _draw() -> void:
	var size: Vector2 = SIZES[kind]
	var h: float = HEIGHTS[kind]
	var w := size.x
	var top := -size.y - h
	var wood := Color("8a5a3b")
	var wood_dark := Color("5e3a25")
	var wood_light := Color("a8724d")

	# Shadow on the floor
	draw_rect(Rect2(-w / 2.0 + 1, -2, w, 3), Color(0, 0, 0, 0.25))
	# Top surface (seen from above at a 3/4 angle)
	draw_rect(Rect2(-w / 2.0, top, w, size.y * 0.6), wood_light)
	# Front face
	var front := Rect2(-w / 2.0, top + size.y * 0.6, w, h + size.y * 0.4)
	draw_rect(front, wood)
	draw_rect(front, wood_dark, false, 1.0)

	match kind:
		Kind.DRESSER:
			# Three rows of drawers with knobs
			var rows := 3
			var row_h := front.size.y / rows
			for i in rows:
				var r := Rect2(front.position.x + 2, front.position.y + i * row_h + 1, w - 4, row_h - 2)
				draw_rect(r, wood_dark, false, 1.0)
				draw_rect(Rect2(r.get_center() - Vector2(1, 0.5), Vector2(2, 1)), Color("e0c070"))
		Kind.CLOSET, Kind.CUPBOARD:
			# Two doors; slightly ajar when someone is hiding inside
			var mid := 0.0
			var door_l := Rect2(front.position.x + 2, front.position.y + 2, w / 2.0 - 3, front.size.y - 3)
			var door_r := Rect2(mid + 1, front.position.y + 2, w / 2.0 - 3, front.size.y - 3)
			draw_rect(door_l, wood_dark, false, 1.0)
			draw_rect(door_r, wood_dark, false, 1.0)
			draw_rect(Rect2(mid - 3, front.get_center().y, 1, 3), Color("e0c070"))
			draw_rect(Rect2(mid + 2, front.get_center().y, 1, 3), Color("e0c070"))
			if occupied:
				draw_line(Vector2(mid, front.position.y + 2), Vector2(mid, front.end.y - 1), Color(0, 0, 0, 0.9), 1.5)

	if occupied:
		# A pair of nervous eyes peeking out
		var eye_y := front.position.y + front.size.y * 0.35
		draw_rect(Rect2(-3, eye_y, 1, 1), Color("fff6c0"))
		draw_rect(Rect2(2, eye_y, 1, 1), Color("fff6c0"))
