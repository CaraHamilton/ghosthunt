class_name ItemPickup
extends Node2D
## An item lying on the floor. Shows the item's floor_sprite (or a small
## version of its icon) and an "[E] Pick up ..." prompt. Holds the very same ItemInstance that was
## dropped, so picking it back up returns it with its state intact (and the
## item keeps working while it lies here, e.g. a thermometer keeps measuring).
##
## Items whose ItemData.world_scene is set use that scene instead (e.g. the
## doll, which ghosts possess); this is the default for everything else.

const DEFAULT_SCENE_PATH := "res://scenes/item_pickup.tscn"
## Width/height (px) of the item's icon when drawn on the floor.
const FLOOR_ICON_SIZE := 12.0
## How close (px) the player must be to pick it up.
const PICKUP_REACH := 12.0

## The item lying here (set before the node is added to the scene).
var item: ItemInstance

var _prompt: Label
var _player: Player


## Puts `item` on the floor at `at` in `world` and returns the node
## representing it (an ItemPickup, or the item's own world scene).
static func drop(item: ItemInstance, world: Node2D, at: Vector2) -> Node2D:
	var scene: PackedScene = item.data.world_scene if item.data.world_scene else load(DEFAULT_SCENE_PATH)
	var node: Node2D = scene.instantiate()
	node.item = item
	node.position = at
	world.add_child(node)
	item.holder = null
	item.world_node = node
	item.on_dropped(node)
	return node


func _ready() -> void:
	var zone := Area2D.new()
	zone.collision_layer = 0
	zone.collision_mask = 2  # player
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2.ONE * (FLOOR_ICON_SIZE + PICKUP_REACH * 2.0)
	shape.shape = rect
	shape.position = Vector2(0, -FLOOR_ICON_SIZE / 2.0)
	zone.add_child(shape)
	add_child(zone)
	zone.body_entered.connect(func(body):
		if body is Player:
			_player = body
			body.register_interactable(self))
	zone.body_exited.connect(func(body):
		if body is Player: body.unregister_interactable(self))

	_prompt = Label.new()
	_prompt.add_theme_font_size_override("font_size", 8)
	_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	_prompt.add_theme_constant_override("outline_size", 3)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.size = Vector2(100, 12)
	_prompt.position = Vector2(-50, -34)  # above the player's head
	_prompt.z_index = 20
	_prompt.visible = false
	add_child(_prompt)


func _physics_process(delta: float) -> void:
	item.process_always(delta)
	# Float the prompt above whichever is higher, the item or the player's
	# head, so it never covers their face.
	if _prompt.visible and _player:
		var top := minf(global_position.y, _player.global_position.y) - 34.0
		_prompt.global_position = Vector2(global_position.x - _prompt.size.x / 2.0, top)


## Called by the player when this is the closest thing they can use.
func set_prompt_visible(value: bool) -> void:
	_prompt.text = "[E] Pick up %s" % item.display_name
	_prompt.visible = value


## Called by the player pressing E.
func player_interact(player: Player) -> void:
	if player.pick_up(item, self):
		queue_free()
	else:
		_prompt.text = "Toolbar full"


func _draw() -> void:
	var size := FLOOR_ICON_SIZE
	# Shadow
	draw_set_transform(Vector2(0, 0.5), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, size * 0.45, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO)
	var art := item.data.floor_sprite
	if art:
		draw_texture(art, Vector2(-art.get_width() / 2, -art.get_height()))
	else:
		# The item's own icon, shrunk down. Icons are drawn for a 44px toolbar
		# slot, so scale that down to floor size.
		var s := size / 44.0
		draw_set_transform(Vector2(0, -size / 2.0), 0.0, Vector2(s, s))
		item.draw_icon(self, Rect2(-22, -22, 44, 44))
		draw_set_transform(Vector2.ZERO)
	if item.count > 1:
		draw_string(ThemeDB.fallback_font, Vector2(size * 0.3, 0), str(item.count),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color.WHITE)
