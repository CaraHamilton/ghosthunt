class_name PlaceOnUseItem
extends ItemInstance
## For tools with no use of their own in hand (the fog machine): using it
## (F / left mouse) places it on the tile in front of you, exactly like
## tapping Q. Give an item this as its instance_script to get that.


func start_use() -> void:
	holder.place_selected()
