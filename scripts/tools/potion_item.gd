class_name PotionItem
extends ItemInstance
## A potion for capturing one type of ghost, taken from the cabinet in the
## trailer (see PotionCabinet). Using it (F / left mouse) anywhere in the
## house starts the ritual (see Game.start_ritual): if it matches the ghost,
## the ghost is captured; if not, the ghost attacks.
##
## Placeholder art: a little flask drawn in code, a different colour for each
## ghost type, until there's a toolbar icon.

## Placeholder liquid colour for each ghost type.
const COLORS := {
	GhostBehavior.Type.BANSHEE: Color("b94e9c"),
	GhostBehavior.Type.POLTERGEIST: Color("e08a2e"),
	GhostBehavior.Type.SENTRY: Color("8a8f9e"),
	GhostBehavior.Type.MARIONETTE: Color("c23b3b"),
	GhostBehavior.Type.DEMON: Color("6b1a1a"),
	GhostBehavior.Type.PHANTOM: Color("7c6fd6"),
	GhostBehavior.Type.FOX: Color("d9662b"),
	GhostBehavior.Type.COLD: Color("7fd3f0"),
	GhostBehavior.Type.FAE: Color("6fcf6a"),
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


func draw_icon(canvas: CanvasItem, rect: Rect2) -> void:
	draw_flask(canvas, rect, color_for(ghost_type))


## Placeholder flask art filling `rect` (also used by the cabinet menu).
static func draw_flask(canvas: CanvasItem, rect: Rect2, liquid: Color) -> void:
	var u := rect.size.x / 16.0  # one art pixel
	var o := rect.position
	var glass := Color(0.85, 0.9, 0.95)
	var outline := Color(0.1, 0.08, 0.12)
	# Cork, neck, round body.
	canvas.draw_rect(Rect2(o + Vector2(6, 1) * u, Vector2(4, 2) * u), Color("8b5a2b"))
	canvas.draw_rect(Rect2(o + Vector2(6, 3) * u, Vector2(4, 4) * u), glass)
	var centre := o + Vector2(8, 10.5) * u
	canvas.draw_circle(centre, 5.5 * u, outline)
	canvas.draw_circle(centre, 4.8 * u, glass)
	canvas.draw_circle(centre + Vector2(0, 0.8) * u, 4.0 * u, liquid)
	canvas.draw_circle(centre + Vector2(-1.8, -1.6) * u, 1.0 * u, Color(1, 1, 1, 0.7))
