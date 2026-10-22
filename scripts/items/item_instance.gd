class_name ItemInstance
extends RefCounted
## One actual copy of an item (or one stack of a stackable item). It points
## at its shared ItemData and holds its own state. The same object moves
## between the inventory and the floor, so its state always comes along.
##
## To make a new item with behaviour: extend this, override the hooks below,
## then make an ItemData .tres in res://items/ pointing at the script.

## The shared definition (name, icon, stack size...).
var data: ItemData
## How many are in this stack (always 1 for unstackable items).
var count := 1
## The player carrying it, or null when it's lying on the floor.
var holder: Player
## Its node in the world while it's on the floor, otherwise null.
var world_node: Node2D
## If true, the player stands still while using this item.
var blocks_movement := false

var display_name: String:
	get:
		return data.display_name


## Where the item physically is: the holder's position, or where it lies.
func get_world_position() -> Vector2:
	if holder:
		return holder.global_position
	if is_instance_valid(world_node):
		return world_node.global_position
	return Vector2.ZERO


func can_stack_with(other: ItemInstance) -> bool:
	return data.max_stack > 1 and other.data == data


## Takes `amount` off this stack as a new instance (for dropping one of many).
func split(amount: int) -> ItemInstance:
	var piece := ItemDB.create_from_data(data)
	piece.count = amount
	count -= amount
	return piece


# --- Hooks: override these in an item's script ------------------------------

## Called when the player starts using the item (F / left mouse).
func start_use() -> void:
	pass


## Called when the player stops using it (or switches away / drops it).
func stop_use() -> void:
	pass


## Called every frame while the item is being used.
func process_use(_delta: float) -> void:
	pass


## Called every frame wherever the item is - in an inventory or on the
## floor (e.g. a sensor that keeps measuring).
func process_always(_delta: float) -> void:
	pass


## Text shown above the toolbar while the item is in use ("" for nothing).
func get_readout() -> String:
	return ""


## Called after the item is dropped and its world node is in the scene.
func on_dropped(_node: Node2D) -> void:
	pass


## Called after the player picks the item up.
func on_picked_up(_player: Player) -> void:
	pass


## Draws the item's icon. Uses ItemData.icon if set; items without art
## override this to draw a placeholder.
func draw_icon(canvas: CanvasItem, rect: Rect2) -> void:
	if data.icon:
		canvas.draw_texture_rect(data.icon, rect, false)
	else:
		canvas.draw_rect(rect.grow(-rect.size.x * 0.25), Color.GRAY)
