@tool
class_name Switchable
extends GhostInteractable
## Furniture or decor with two looks the ghost and the player can switch
## between: a sink turned on, a stack of books knocked over... Every
## interactable like this uses this script; its art's tags decide the rules.
## It can stand on the floor (solid: it blocks the player like furniture) or,
## for small things, up on a table, counter or shelf.
##
## Give it `art` like furniture (see Prop): a sheet with "down", "right"...
## frames for its normal look, plus a tag for its other look that also says
## what the ghost can do:
##   "<facing>_knocked" (e.g. "down_knocked"): the ghost can only knock it
##       over. The player can knock it over and set it right again (E).
##   "<facing>_on" (e.g. "down_on"): the ghost and the player can both
##       switch it either way.
## A tag with several frames loops as an animation. A facing with no tag of
## its own uses the one for the frame it shows (a "left" one showing "right"
## uses "right_knocked").
##
## Placing it: the origin is the bottom-centre of its footprint, like
## furniture. On the floor, snap the origin to the bottom-centre of a tile.
## On a table, put the origin just below the table's front edge (so it's
## drawn in front of the table) and set `raise` until the art sits on the
## tabletop - the blue box shows where it rests. Raised, it doesn't block
## anything (the table does).

## True while it shows its other look (knocked over, switched on...).
@export var changed := false:
	set(value):
		changed = value
		_update_art()
## The object's picture or Aseprite sheet.
@export var art: Texture2D:
	set(value):
		art = value
		_update_art()
## Which way it faces (which frame of the sheet is shown).
@export var facing := Prop.Facing.DOWN:
	set(value):
		facing = value
		_update_art()
## Moves the art (px) relative to the origin, for art that isn't centred on
## its canvas (e.g. books knocked over that spill to one side).
@export var art_offset := Vector2.ZERO:
	set(value):
		art_offset = value
		_update_art()
## Area on the floor when facing right or left. Leave at (0, 0) to use
## `footprint`.
@export var side_footprint := Vector2.ZERO:
	set(value):
		side_footprint = value
		queue_redraw()
## Where the UV residue glows, relative to the origin (before `raise`):
## on the top of the object in the art (a sink's counter, the top of a
## stack of books). The green cross in the editor shows it.
@export var residue_position := Vector2(0, -12):
	set(value):
		residue_position = value
		queue_redraw()
## How far (px) the art is drawn above the origin: 0 on the floor. On a
## table, the table's surface height plus how far back on the top it sits.
@export var raise := 0.0:
	set(value):
		raise = value
		_update_art()

## Draws `art` (a Prop just for its drawing). Not saved in the scene.
var _art_node: Prop


func _ready() -> void:
	if not Engine.is_editor_hint():
		footprint = current_footprint()
		# Up on a table it's out of the way; the table blocks instead.
		solid = solid and raise == 0.0
		player_zone_raise = raise
		residue_offset = residue_position - Vector2(0, raise)
	super()
	_update_art()


## The footprint for the way it's facing.
func current_footprint() -> Vector2:
	if (facing == Prop.Facing.RIGHT or facing == Prop.Facing.LEFT) and side_footprint != Vector2.ZERO:
		return side_footprint
	return footprint


## The tag for the other look ("down_knocked", "down_on"), or "" if the
## sheet has neither.
func change_tag() -> String:
	if _art_node == null:
		return ""
	var base := _art_node.facing_tag()
	for kind: String in ["_knocked", "_on"]:
		if _art_node.has_tag(base + kind):
			return base + kind
	return ""


## True if the ghost can only change it one way (a "_knocked" tag).
func is_one_way() -> bool:
	return change_tag().ends_with("_knocked")


func can_ghost_interact() -> bool:
	if is_one_way() and changed:
		return false  # already knocked over
	return super()


func _on_ghost_interact(_ghost: Ghost) -> void:
	changed = not changed


func _on_player_interact(_player: Player) -> void:
	changed = not changed


func describe_last_interaction() -> String:
	var thing := String(name).capitalize().to_lower()
	if is_one_way():
		return "knocked over the %s" % thing
	return "switched %s the %s" % ["on" if changed else "off", thing]


func _update_art() -> void:
	queue_redraw()
	if not is_inside_tree():
		return  # _ready does it
	if art == null:
		if _art_node:
			_art_node.queue_free()
			_art_node = null
		return
	if _art_node == null:
		_art_node = Prop.new()
		_art_node.solid = false
		_art_node.footprint = Vector2.ZERO
		add_child(_art_node, false, INTERNAL_MODE_FRONT)
	_art_node.art = art
	_art_node.facing = facing
	_art_node.position = art_offset - Vector2(0, raise)
	var tag := change_tag()
	_art_node.animation = tag if changed and tag != "" else ""


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var size := current_footprint()
	var r := Rect2(-size.x / 2.0, -size.y, size.x, size.y)
	if raise == 0.0:
		draw_rect(r, Color(1, 1, 1, 0.4), false, 1.0)  # what it blocks
	else:
		# Where it rests up on the table.
		draw_rect(Rect2(r.position - Vector2(0, raise), r.size), Color(0.4, 0.8, 1, 0.7), false, 1.0)
		draw_line(Vector2.ZERO, Vector2(0, -raise), Color(0.4, 0.8, 1, 0.4), 1.0)
	if art == null:
		draw_rect(Rect2(r.position - Vector2(0, raise + 8), Vector2(r.size.x, r.size.y + 8)),
			Color(0.6, 0.5, 0.4))
	# Where UV residue would glow.
	var g := residue_position - Vector2(0, raise)
	draw_line(g - Vector2(2, 0), g + Vector2(2, 0), Color(0.35, 1, 0.45, 0.9), 1.0)
	draw_line(g - Vector2(0, 2), g + Vector2(0, 2), Color(0.35, 1, 0.45, 0.9), 1.0)
