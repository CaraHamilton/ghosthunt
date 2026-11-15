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
## Physics layer 3 ("placed_tools"): placed tools. The player's collision
## mask includes it, the ghost's doesn't.
const PLACED_TOOLS_LAYER := 4

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
	# The tile outline shown when it was placed (lifted onto the table top for
	# a table) - right click shows the same one to pick it up.
	node.set_meta("place_rect", spot.rect)
	node.add_to_group(House.PLACED_GROUP)
	if spot.surface == null:
		_add_blocker(node, item.data.footprint)
	return node


## Makes a tool placed on the floor solid for the player: a box of the
## item's `footprint` size (ItemData, at most 16x16) in the middle of the
## tile, on the "placed_tools" physics layer. The player collides with that
## layer, the ghost doesn't, so ghosts pass straight over it. It's a child of
## the item's node, so it goes when the item is picked up. (Tools on tables
## don't need one - the table already blocks.)
static func _add_blocker(node: Node2D, footprint: Vector2) -> void:
	var size := footprint.clamp(Vector2.ZERO, Vector2(16, 16))
	if size.x <= 0.0 or size.y <= 0.0:
		return  # no footprint: the player walks over it too
	var body := StaticBody2D.new()
	body.name = "Blocker"
	body.collision_layer = PLACED_TOOLS_LAYER
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = Vector2(0, -8)  # the tile's middle (the node sits on its bottom edge)
	body.add_child(shape)
	node.add_child(body)


func _physics_process(delta: float) -> void:
	item.process_always(delta)


## Called by the player pressing E. (Nothing happens if the toolbar is full.)
func player_interact(player: Player) -> void:
	if player.pick_up(item):
		queue_free()


## Where the item's picture is drawn, in global coordinates (clicking on it
## picks it up - see Player.right_click_target).
func get_art_rect() -> Rect2:
	var up := global_position + Vector2(0, -elevation)
	var art := item.data.floor_sprite
	if art:
		return Rect2(up + Vector2(-art.get_width() / 2, -art.get_height()), art.get_size())
	return Rect2(up + Vector2(-FLOOR_ICON_SIZE / 2.0, -FLOOR_ICON_SIZE), Vector2.ONE * FLOOR_ICON_SIZE)


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
