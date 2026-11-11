class_name ItemPickup
extends Node2D
## An item lying on the floor. Shows the item's floor_sprite (or a small
## version of its icon); E picks it up. Holds the very same ItemInstance that
## was dropped, so picking it back up returns it with its state intact (and the
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
## How far (px) above its position the item is drawn - e.g. on a table, the
## node sits at the table's front edge (to Y-sort in front of it) and the
## item is drawn up on its top. 0 on the floor. Set before adding the node.
var elevation := 0.0


## Puts `item` on the floor at `at` in `world` and returns the node
## representing it (an ItemPickup, or the item's own world scene). Its world
## scene needs an `elevation` property to be placed on tables.
static func drop(item: ItemInstance, world: Node2D, at: Vector2, raise := 0.0) -> Node2D:
	var scene: PackedScene = item.data.world_scene if item.data.world_scene else load(DEFAULT_SCENE_PATH)
	var node: Node2D = scene.instantiate()
	node.item = item
	node.position = at
	if "elevation" in node:
		node.elevation = raise
	world.add_child(node)
	item.holder = null
	item.world_node = node
	item.on_dropped(node)
	return node


## Places `item` on a tile: `spot` is from House.get_place_spot (and must be
## ok). The tile then counts as taken until the item is picked up.
static func place(item: ItemInstance, world: Node2D, spot: Dictionary) -> Node2D:
	var node := drop(item, world, spot.position, spot.elevation)
	node.set_meta("place_tile", spot.cell)
	node.add_to_group(House.PLACED_GROUP)
	return node


func _ready() -> void:
	var zone := Area2D.new()
	zone.collision_layer = 0
	zone.collision_mask = 2  # player
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	# Stretched up to cover the item when it's raised onto a table, so it can
	# be picked up from the table's front or from beside the item.
	rect.size = Vector2.ONE * (FLOOR_ICON_SIZE + PICKUP_REACH * 2.0) + Vector2(0, elevation)
	shape.shape = rect
	shape.position = Vector2(0, -FLOOR_ICON_SIZE / 2.0 - elevation / 2.0)
	zone.add_child(shape)
	add_child(zone)
	zone.body_entered.connect(func(body):
		if body is Player: body.register_interactable(self))
	zone.body_exited.connect(func(body):
		if body is Player: body.unregister_interactable(self))


func _physics_process(delta: float) -> void:
	item.process_always(delta)


## Called by the player pressing E. (Nothing happens if the toolbar is full.)
func player_interact(player: Player) -> void:
	if player.pick_up(item, self):
		queue_free()


func _draw() -> void:
	var size := FLOOR_ICON_SIZE
	var up := Vector2(0, -elevation)  # raised onto a table
	var art := item.data.floor_sprite
	if art:
		draw_texture(art, up + Vector2(-art.get_width() / 2, -art.get_height()))
	else:
		# The item's own icon, shrunk down. Icons are drawn for a 44px toolbar
		# slot, so scale that down to floor size.
		var s := size / 44.0
		draw_set_transform(up + Vector2(0, -size / 2.0), 0.0, Vector2(s, s))
		item.draw_icon(self, Rect2(-22, -22, 44, 44))
		draw_set_transform(Vector2.ZERO)
	if item.count > 1:
		draw_string(ThemeDB.fallback_font, up + Vector2(size * 0.3, 0), str(item.count),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color.WHITE)
