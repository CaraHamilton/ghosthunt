class_name UVLight
extends ItemInstance
## A UV flashlight. While held (F / left mouse) it shines a purple beam about
## 3 tiles in front of the holder, replacing their normal lantern glow. Any
## ghost residue (left by some ghost types on things they touch) inside the
## beam glows green.

## How far the beam reaches (px, ~3 tiles).
var beam_range := 50.0
## Half the beam's spread, in degrees.
var beam_half_angle := 28.0

var _beam: UVBeam
var _lit: Array[GhostInteractable] = []


func start_use() -> void:
	if _beam == null:
		_beam = UVBeam.new()
		_beam.beam_range = beam_range
		_beam.beam_half_angle = beam_half_angle
		holder.add_child(_beam)
	_beam.visible = true
	_set_lantern(false)


func stop_use() -> void:
	if _beam:
		_beam.visible = false
	_set_lantern(true)
	for item in _lit:
		if is_instance_valid(item):
			item.uv_lit = false
	_lit.clear()


func process_use(_delta: float) -> void:
	_beam.rotation = holder.facing.angle()
	var now_lit: Array[GhostInteractable] = []
	for item: GhostInteractable in holder.get_tree().get_nodes_in_group("ghost_interactables"):
		if _in_beam(item):
			now_lit.append(item)
	for item in _lit:
		if is_instance_valid(item) and item not in now_lit:
			item.uv_lit = false
	for item in now_lit:
		item.uv_lit = true
	_lit = now_lit


func _in_beam(item: GhostInteractable) -> bool:
	var origin := holder.global_position
	var target := item.get_footprint().get_center()
	var to_item := target - origin
	if to_item.length() > beam_range:
		return false
	if to_item.length() > 4.0 and absf(rad_to_deg(holder.facing.angle_to(to_item))) > beam_half_angle:
		return false
	# Walls (and other furniture) block the beam.
	var query := PhysicsRayQueryParameters2D.create(origin, target, 1)
	query.exclude = [item.get_rid()]
	return holder.get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _set_lantern(on: bool) -> void:
	var lantern := holder.get_node_or_null("Lantern")
	if lantern:
		lantern.visible = on


func draw_icon(canvas: CanvasItem, rect: Rect2) -> void:
	var c := rect.get_center()
	var body := Rect2(c.x - rect.size.x * 0.32, c.y - 4, rect.size.x * 0.45, 8)
	canvas.draw_rect(body, Color("3a3050"))
	canvas.draw_rect(body, Color("15101e"), false, 1.5)
	var head := PackedVector2Array([
		Vector2(body.end.x, body.position.y - 1), Vector2(body.end.x + 9, body.position.y - 5),
		Vector2(body.end.x + 9, body.end.y + 5), Vector2(body.end.x, body.end.y + 1)])
	canvas.draw_colored_polygon(head, Color("4a3e66"))
	canvas.draw_line(Vector2(body.end.x + 9, body.position.y - 4), Vector2(body.end.x + 9, body.end.y + 4), Color("b070ff"), 3.0)
