class_name Inventory
extends RefCounted
## A fixed number of slots, each empty (null) or holding one ItemInstance
## (which may be a stack). The toolbar shows the first slots of the player's
## inventory.

signal changed

var slots: Array[ItemInstance] = []
## Who carries this inventory (items in it get this as their holder).
var holder: Player


func _init(size: int, owner_player: Player = null) -> void:
	slots.resize(size)
	holder = owner_player


func get_item(slot: int) -> ItemInstance:
	return slots[slot] if slot >= 0 and slot < slots.size() else null


## Puts an item in, topping up matching stacks first, then the first empty
## slot. Returns false if it (or part of a stack) didn't fit; whatever didn't
## fit stays in `item`.
func add_item(item: ItemInstance) -> bool:
	for existing in slots:
		if item.count == 0:
			break
		if existing and existing.can_stack_with(item):
			var moved := mini(item.count, existing.data.max_stack - existing.count)
			existing.count += moved
			item.count -= moved
	if item.count > 0:
		var empty := slots.find(null)
		if empty < 0:
			changed.emit()
			return false
		slots[empty] = item
		_take(item)
	changed.emit()
	return true


## True if `item` would fit completely.
func has_room_for(item: ItemInstance) -> bool:
	if slots.has(null):
		return true
	var space := 0
	for existing in slots:
		if existing.can_stack_with(item):
			space += existing.data.max_stack - existing.count
	return space >= item.count


## Removes `amount` from a slot (the whole stack if amount < 0) and returns
## it as its own instance, or null if the slot is empty.
func remove_from_slot(slot: int, amount := -1) -> ItemInstance:
	var item := get_item(slot)
	if item == null:
		return null
	var removed := item
	if amount > 0 and amount < item.count:
		removed = item.split(amount)
	else:
		slots[slot] = null
	removed.holder = null
	changed.emit()
	return removed


## Every item instance currently in the inventory.
func items() -> Array[ItemInstance]:
	var result: Array[ItemInstance] = []
	for item in slots:
		if item:
			result.append(item)
	return result


func _take(item: ItemInstance) -> void:
	item.holder = holder
	item.world_node = null
