class_name DollItem
extends ItemInstance
## The doll as an item. Using it (F / left mouse) puts it down on the floor,
## same as the drop key. On the floor it becomes a Doll node
## (scenes/doll.tscn) that some ghost types possess.
##
## The doll's ghost traces live here, on the item, so they stay with this
## doll when it's picked up and put down again.

## True once a residue-leaving ghost has touched this doll (UV-visible).
var has_residue := false
## Game time the ghost last touched it (for the EMF reader and cooldown).
var last_ghost_touch_time := -INF


func start_use() -> void:
	holder.drop_selected()
