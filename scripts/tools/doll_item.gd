class_name DollItem
extends ItemInstance
## The doll as an item. Using it (F / left mouse) places it on the tile in
## front of you, same as tapping Q. On the floor it becomes a Doll node
## (scenes/doll.tscn) that some ghost types possess.
##
## When the ghost last touched the doll is kept here, on the item, so it
## stays with this doll when it's picked up and put down again.

## Game time the ghost last touched it (for its cooldown).
var last_ghost_touch_time := -INF


func start_use() -> void:
	holder.place_selected()
