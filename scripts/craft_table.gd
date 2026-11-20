@tool
class_name CraftTable
extends Prop
## The craft table in the trailer (scenes/furniture/craft_table.tscn): a
## piece of furniture like any other Prop (art, footprint, facing...), that
## the player can also click (or press E next to) to open the potion list
## (see PotionMenu). Picking one puts that potion in the toolbar. It never
## runs out: take as many as the toolbar holds.


func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	add_to_group("player_clickables")


## Its footprint, in global coordinates - the player must be within reach of
## this to use it.
func get_reach_area() -> Rect2:
	return get_footprint()


## True if a click at `point` (global) is on its picture.
func is_clicked_at(point: Vector2) -> bool:
	return is_art_at(point)


func player_interact(player: Player) -> void:
	Game.current.potion_menu.open(self, player)


## Called by the menu: gives the player the potion for `type`. Returns false
## (and gives nothing) if their toolbar is full.
func take_potion(type: GhostBehavior.Type, player: Player) -> bool:
	var potion := ItemDB.create(&"potion") as PotionItem
	potion.ghost_type = type
	if not player.inventory.has_room_for(potion):
		return false
	player.inventory.add_item(potion)
	player.select_slot(player.inventory.slots.find(potion))
	Sfx.play("tools/pick_up")
	if OS.is_debug_build():
		print("[debug] Took the %s" % PotionItem.name_for(type))
	return true
