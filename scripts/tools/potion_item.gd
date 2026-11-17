class_name PotionItem
extends ItemInstance
## A potion for capturing one type of ghost, taken from the craft table in the
## trailer (see CraftTable). Using it (F / left mouse) in the ghost's
## favourite room starts the ritual (see Game.start_ritual): if it matches the
## ghost, the ghost is captured; if not, the ghost attacks. In any other room
## the ritual fizzles out and the potion is wasted.
##
## Every type shows the same toolbar icon: ItemData.icon in items/potion.tres
## (art/toolbar_icons/potion.png).

## A colour for each ghost type's potion, used for the potion menu's button
## text and its "Took the X." note.
const COLORS := {
	GhostBehavior.Type.BANSHEE: Color("b94e9c"),
	GhostBehavior.Type.POLTERGEIST: Color("e08a2e"),
	GhostBehavior.Type.SENTRY: Color("8a8f9e"),
	GhostBehavior.Type.MARIONETTE: Color("c23b3b"),
	GhostBehavior.Type.WRAITH: Color("6b1a1a"),
	GhostBehavior.Type.PHANTOM: Color("7c6fd6"),
	GhostBehavior.Type.HELL_HOUND: Color("d9662b"),
	GhostBehavior.Type.WENDIGO: Color("7fd3f0"),
	GhostBehavior.Type.FAE: Color("6fcf6a"),
	GhostBehavior.Type.BELDAM: Color("b8b04a"),
	GhostBehavior.Type.HIGH_PRIEST: Color("e8d9a8"),
	GhostBehavior.Type.FURY: Color("e0303a"),
	GhostBehavior.Type.IMP: Color("9b3fd1"),
}

## Which ghost this potion captures.
var ghost_type := GhostBehavior.Type.BANSHEE
## Why the ritual couldn't start the last time it was used ("" if it could).
var _problem := ""


## "Banshee Potion", etc.
static func name_for(type: GhostBehavior.Type) -> String:
	return "%s Potion" % GhostBehavior.type_name(type)


static func color_for(type: GhostBehavior.Type) -> Color:
	return COLORS.get(type, Color.WHITE)


func start_use() -> void:
	_problem = Game.current.start_ritual(self)


## Shown above the toolbar while the button is held: which potion it is, and
## why the ritual didn't start, if it didn't.
func get_readout() -> String:
	if _problem != "":
		return "%s - %s" % [name_for(ghost_type), _problem]
	return name_for(ghost_type)
