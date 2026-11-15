@tool
class_name PotionCabinet
extends StaticBody2D
## The potion cabinet in the trailer. Clicking it (or E next to it) opens the
## potion list (see PotionMenu); picking one puts that potion in the toolbar.
## Only one potion can be taken per game - after that the cabinet is empty.
##
## The node's origin is the bottom-middle of its footprint (where it stands
## on the floor). Until there's real art it draws a placeholder cabinet.

## The floor it stands on (width, depth) in px - this part blocks the player.
@export var footprint := Vector2(32, 16):
	set(value):
		footprint = value
		_update_shape()
		queue_redraw()
## How tall the placeholder art is (its bottom is the footprint's bottom).
@export var art_height := 32.0:
	set(value):
		art_height = value
		queue_redraw()

## True once the player has taken their potion.
var is_empty := false

var _shape: CollisionShape2D
## Seconds left showing "Empty" above it.
var _empty_note_left := 0.0


func _ready() -> void:
	_update_shape()
	queue_redraw()
	if Engine.is_editor_hint():
		return
	add_to_group("player_clickables")
	collision_layer = 1  # the world: blocks the player
	collision_mask = 0


## Its footprint, in global coordinates - the player must be within reach of
## this to use it.
func get_reach_area() -> Rect2:
	return Rect2(global_position + Vector2(-footprint.x / 2.0, -footprint.y), footprint)


## True if a click at `point` (global) is on it.
func is_clicked_at(point: Vector2) -> bool:
	var art := Rect2(global_position + Vector2(-footprint.x / 2.0, -art_height), Vector2(footprint.x, art_height))
	return art.has_point(point)


func player_interact(player: Player) -> void:
	if is_empty:
		_empty_note_left = 1.5
		queue_redraw()
		return
	Game.current.potion_menu.open(self, player)


## Called by the menu: gives the player the potion for `type` and empties
## the cabinet. Returns false (and gives nothing) if their toolbar is full.
func take_potion(type: GhostBehavior.Type, player: Player) -> bool:
	var potion := ItemDB.create(&"potion") as PotionItem
	potion.ghost_type = type
	if not player.inventory.has_room_for(potion):
		return false
	player.inventory.add_item(potion)
	player.select_slot(player.inventory.slots.find(potion))
	is_empty = true
	Sfx.play("tools/pick_up")
	if OS.is_debug_build():
		print("[debug] Took the %s" % PotionItem.name_for(type))
	queue_redraw()
	return true


func _process(delta: float) -> void:
	if _empty_note_left > 0.0:
		_empty_note_left -= delta
		if _empty_note_left <= 0.0:
			queue_redraw()


func _update_shape() -> void:
	if _shape == null:
		_shape = CollisionShape2D.new()
		add_child(_shape, false, INTERNAL_MODE_FRONT)
	var rect := RectangleShape2D.new()
	rect.size = footprint
	_shape.shape = rect
	_shape.position = Vector2(0, -footprint.y / 2.0)


# --- Placeholder art ------------------------------------------------------------

func _draw() -> void:
	var w := footprint.x
	var body := Rect2(-w / 2.0, -art_height, w, art_height)
	var wood := Color("6b4a2f")
	var dark := Color("3d2a1b")
	draw_rect(body, wood)
	draw_rect(body, dark, false, 1.0)
	# Two glass doors with shelves of potions (gone once it's empty).
	var door_w := (w - 6.0) / 2.0
	for i in 2:
		var door := Rect2(body.position.x + 2.0 + i * (door_w + 2.0), body.position.y + 2.0, door_w, art_height - 10.0)
		draw_rect(door, Color("2a2f3a"))
		for shelf in 2:
			var y := door.position.y + 4.0 + shelf * 10.0
			draw_line(Vector2(door.position.x, y + 4.0), Vector2(door.end.x, y + 4.0), wood, 1.0)
			if not is_empty:
				for b in 3:
					var type := ((i * 6 + shelf * 3 + b) % GhostBehavior.Type.size()) as GhostBehavior.Type
					draw_rect(Rect2(door.position.x + 1.5 + b * 4.0, y, 2.0, 4.0), PotionItem.color_for(type))
		draw_rect(door, dark, false, 1.0)
	# Drawer along the bottom.
	draw_rect(Rect2(body.position.x + 2.0, body.end.y - 7.0, w - 4.0, 5.0), dark, false, 1.0)
	if _empty_note_left > 0.0:
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(-w / 2.0, -art_height - 3.0), "Empty", HORIZONTAL_ALIGNMENT_CENTER, w, 8, Color.WHITE)
