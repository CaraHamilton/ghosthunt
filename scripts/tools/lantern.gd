class_name LanternItem
extends ItemInstance
## The lantern: the player's only light. It glows on its own (no need to hold
## F) whenever it's the selected toolbar item, or lying on the floor. Carried
## but not selected, it's off and the player is in the dark.
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
		_attach(world_node, FLOOR_OFFSET, true)


## Move the light over straight away, before the floor node is freed or a
## frame passes in the dark.
func on_dropped(node: Node2D) -> void:
	_attach(node, FLOOR_OFFSET, true)


func on_picked_up(player: Player) -> void:
	_attach(player, HELD_OFFSET, player.selected_item == self)


func _attach(parent: Node2D, offset: Vector2, on: bool) -> void:
	if not is_instance_valid(_light):
		_light = LIGHT_SCENE.instantiate()
		# Light the world and the player's sprite (she's on her own light layer).
		_light.range_item_cull_mask = 1 | 1 << (Player.LIGHT_LAYER - 1)
	if _light.get_parent() != parent:
		if _light.get_parent():
			_light.reparent(parent, false)
		else:
			parent.add_child(_light)
	_light.position = offset
	_light.visible = on


func draw_icon(canvas: CanvasItem, rect: Rect2) -> void:
	if data.icon:
		super(canvas, rect)
		return
	var c := rect.get_center()
	var w := rect.size.x
	canvas.draw_circle(c + Vector2(0, 1), w * 0.24, Color(1.0, 0.8, 0.4, 0.35))  # glow
	canvas.draw_arc(c - Vector2(0, w * 0.2), w * 0.1, PI, TAU, 8, Color("2a2a30"), 2.0)  # handle
	var glass := Rect2(c.x - w * 0.12, c.y - w * 0.14, w * 0.24, w * 0.3)
	canvas.draw_rect(glass, Color("ffd27a"))
	canvas.draw_rect(glass, Color("2a2a30"), false, 2.0)
	canvas.draw_rect(Rect2(c.x - w * 0.16, glass.end.y, w * 0.32, w * 0.06), Color("2a2a30"))  # base
	canvas.draw_rect(Rect2(c.x - w * 0.16, glass.position.y - w * 0.04, w * 0.32, w * 0.05), Color("2a2a30"))  # top
