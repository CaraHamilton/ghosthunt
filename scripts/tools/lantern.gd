class_name LanternItem
extends ItemInstance
## The lantern: the player's only light. It glows on its own (no need to hold
## F) whenever it's the selected toolbar item, or lying on the floor. Carried
## but not selected, it's off and the player is in the dark. F (or left click)
## within reach of a fireplace or candle lights it or puts it out.
##
## The light itself is res://scenes/lantern_light.tscn (tweak its colour and
## size there). It moves between the player and the lantern's floor node.

const LIGHT_SCENE := preload("res://scenes/lantern_light.tscn")
## Where the light sits on the player (about hand height).
const HELD_OFFSET := Vector2(0, -10)
## Where the light sits on the lantern lying on the floor.
const FLOOR_OFFSET := Vector2(0, -6)

var _light: PointLight2D


## Keeps the light on the player while the lantern is selected, off while
## it's in a pocket, and on its floor node while it lies on the floor.
func process_always(_delta: float) -> void:
	if holder:
		_attach(holder, HELD_OFFSET, holder.selected_item == self)
	elif is_instance_valid(world_node):
		_attach(world_node, _floor_offset(world_node), true)


## Move the light over straight away, before the floor node is freed or a
## frame passes in the dark.
func on_dropped(node: Node2D) -> void:
	_attach(node, _floor_offset(node), true)


## F (or left click) within reach of a fireplace or candle (a Switchable with
## a "_lit" tag - see Switchable.in_lantern_reach) lights it or puts it out.
## The closest one, if several.
func start_use() -> void:
	if holder == null:
		return
	var best: Switchable = null
	var best_dist := INF
	for thing in holder.get_tree().get_nodes_in_group("ghost_interactables"):
		var fire := thing as Switchable
		if fire == null or not fire.is_lit_type() or not fire.in_lantern_reach(holder):
			continue
		var d := holder.global_position.distance_squared_to(fire.get_footprint().get_center())
		if d < best_dist:
			best_dist = d
			best = fire
	if best:
		best.light_with_lantern()


## On a table, the light sits up on the table top with the lantern.
func _floor_offset(node: Node2D) -> Vector2:
	var raised: float = node.get("elevation") if "elevation" in node else 0.0
	return FLOOR_OFFSET - Vector2(0, raised)


func on_picked_up(player: Player) -> void:
	_attach(player, HELD_OFFSET, player.selected_item == self)


func _attach(parent: Node2D, offset: Vector2, on: bool) -> void:
	if not is_instance_valid(_light):
		# It lights the world; PlayerLight lights her from it (it's in the
		# "world_lights" group).
		_light = LIGHT_SCENE.instantiate()
	if _light.get_parent() != parent:
		if _light.get_parent():
			_light.reparent(parent, false)
		else:
			parent.add_child(_light)
	_light.position = offset
	_light.visible = on
