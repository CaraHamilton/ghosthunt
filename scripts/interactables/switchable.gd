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
##   "<facing>_played" (e.g. "right_played"): an animation, like a rocking
##       chair rocking. The ghost or the player sets it going and it plays
##       for `play_time` seconds, then stops by itself. Same rules as "_on"
##       (the ghost does it at any sanity, EMF 1-2).
##   "<facing>_lit" (e.g. "down_lit"): a fire. Only the player can light it
##       and put it out, with the lantern (F) standing next to it - not E.
##       The ghost leaves it alone.
##   "<facing>_broken" (e.g. "down_broken"): a breakable, like a jar. Only
##       the ghost can break it (once sanity is below 70% - see
##       Ghost.break_sanity_threshold), and nobody can fix it. The player can't use it at all.
##       Breaking it always makes the ghost appear for 2-3 seconds, and
##       gives off EMF 4 (or 5 for ghost types that show EMF 5).
## A tag with several frames loops as an animation. A facing with no tag of
## its own uses the one for the frame it shows (a "left" one showing "right"
## uses "right_knocked").
## `show_while_changed` (e.g. a fire's light) is only shown in the other look.
##
## Placing it: with `snap_to_tile` on (small decor), just drop it on a tile,
## on the floor or on a table. When the game starts it snaps to that tile
## the same way a placed tool does: standing on the floor (bottom-centre of
## the tile, solid), or up on the table's top if a table covers the tile.
## The editor shows where it will be: a white box on the floor, blue on a
## table, red if it can't go there (a wall, solid furniture, off the floor) -
## then it stays where you put it. A snapped one takes its tile, so the
## player can't place a tool on top of it.
##
## With `snap_to_tile` off (furniture bigger than a tile, like a sink),
## place it by hand like a Prop: the origin is the bottom-centre of its
## footprint, and `raise` lifts the art if it needs to sit on something.
## Raised, it doesn't block anything (what's under it does).

## True while it shows its other look (knocked over, switched on...).
@export var changed := false:
	set(value):
		changed = value
		_update_art()
		_update_loop_sound()
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
## A child (e.g. a fire's PointLight2D) shown only while `changed` - lit,
## switched on... Hidden the rest of the time.
@export var show_while_changed: Node2D:
	set(value):
		show_while_changed = value
		_update_art()
## For a "_played" animation: how long (seconds) it plays each time.
@export var play_time := 5.0
@export_group("Sound")
## Plays when it changes to its other look: switched on, knocked over, broken,
## set going, lit. Empty uses the default sound for its tag (see
## DEFAULT_SOUNDS), so every sink shares one sound unless it has its own.
@export var change_sound: AudioStream
## Plays when it changes back: switched off, set right, put out. Empty uses
## the default for its tag.
@export var change_back_sound: AudioStream
## Loops the whole time it shows its other look - water running, a fire
## crackling, a chair creaking while it rocks. None if empty.
@export var loop_sound: AudioStream
## How loud the change sounds are (dB; 0 = as exported, -6 = about half).
@export var sound_volume_db := 0.0
## How loud the loop is.
@export var loop_volume_db := -6.0
@export_group("UV Residue")
## Where the centre of the UV residue goes, relative to the origin (before
## `raise`): on the top of the object in the art (a sink's counter, the top
## of a stack of books). The green cross in the editor shows it.
@export var residue_position := Vector2(0, -12):
	set(value):
		residue_position = value
		queue_redraw()
## The residue picture for this object (bright green on transparent). Empty
## uses the default, res://art/uv_residue/handprint_default.png. Previewed
## faintly in the editor.
@export var residue_art: Texture2D:
	set(value):
		residue_art = value
		queue_redraw()
## Mirror the residue picture left-right.
@export var residue_flip := false:
	set(value):
		residue_flip = value
		queue_redraw()
## Show the residue preview in the editor.
@export var preview_residue := true:
	set(value):
		preview_residue = value
		queue_redraw()
@export_group("")
## Snap to the floor tile it's dropped on (or onto the table there), like a
## placed tool. Turn off to place it by hand (furniture bigger than a tile).
@export var snap_to_tile := true:
	set(value):
		snap_to_tile = value
		_update_art()
## Only with `snap_to_tile` off: how far (px) the art is drawn above the
## origin - e.g. to sit on a counter. 0 on the floor.
@export var raise := 0.0:
	set(value):
		raise = value
		_update_art()

## The sounds used when change_sound / change_back_sound are empty, by tag:
## [changing to the other look, changing back]. Names of files in
## res://audio/sfx/ (see Sfx). "" = no sound.
## The footprint of snapped decor (snap_to_tile): one whole tile.
const TILE_FOOTPRINT := Vector2(16, 16)

const DEFAULT_SOUNDS := {
	"_on": ["objects/switch_on", "objects/switch_off"],
	"_knocked": ["objects/knock_over", "objects/set_right"],
	"_broken": ["objects/break", ""],
	"_played": ["objects/start_playing", ""],
	"_lit": ["objects/light_fire", "objects/put_out_fire"],
}

## Draws `art` (a Prop just for its drawing). Not saved in the scene.
var _art_node: Prop
## How far (px) the art is actually drawn above the origin (from snapping,
## or `raise`).
var _lift := 0.0
## In the editor: from the node to where it will snap to (the node itself
## only moves there when the game starts).
var _shift := Vector2.ZERO
## In the editor: whether its tile can take it (red box if not).
var _snap_ok := true
## In the editor: draws the residue preview over the art.
var _residue_preview: Node2D
## Seconds left of a "_played" animation (0 when it isn't playing).
var _play_time_left := 0.0
## Plays loop_sound while it shows its other look (made when first needed).
var _loop_player: AudioStreamPlayer2D
## Snapped decor: the tile it sits on as drawn (up on the table's top if it's
## on one). Clicking anywhere on it uses the decor, not just its art.
var _tile_click_rect := Rect2()


func _ready() -> void:
	if Engine.is_editor_hint():
		set_notify_transform(true)
	else:
		_lift = raise
		if snap_to_tile:
			var spot := snap_spot()
			if spot.get("ok", false):
				global_position = spot.position
				_lift = spot.elevation
				_tile_click_rect = spot.rect
				# Its tile is taken: no tools placed on top of it.
				set_meta("place_tile", spot.cell)
				add_to_group(House.PLACED_GROUP)
			else:
				push_warning("%s can't snap to its tile (wall, furniture or no floor)" % name)
		footprint = current_footprint()
		# Up on a table it's out of the way; the table blocks instead.
		solid = solid and _lift == 0.0
		residue_offset = residue_position - Vector2(0, _lift)
		residue_texture = residue_art
		residue_flip_h = residue_flip
		# Up on a table, its light (a candle's flame) goes up with the art.
		if is_instance_valid(show_while_changed):
			show_while_changed.position.y -= _lift
		# Breakables are the ghost's alone: no E or click zone for the player.
		_update_art()
		if is_breakable():
			player_can_use = false
	super()
	_update_art()
	_update_loop_sound()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_update_art()


## Where it snaps to (see House.get_place_spot): on a table if one covers
## its tile, else standing on the floor with its origin at the bottom-centre
## of the tile. Empty if it isn't in a house.
func snap_spot() -> Dictionary:
	var house := _house()
	if house == null or house.floor_layer == null:
		return {}
	# 2px up: an origin on a tile's bottom edge (like furniture's), or
	# just below it, means that tile, not the one below.
	var cell := house.tile_at(global_position - Vector2(0, 2))
	# The house's furniture, straight from the scene (furniture only
	# registers itself as an obstacle once the game runs).
	var props := house.find_children("*", "Prop", true, false).filter(
		func(p: Prop) -> bool: return p.solid and not p.flat)
	# ...and hand-placed Switchables (a sink, a fireplace).
	for other: Switchable in house.find_children("*", "Switchable", true, false):
		if other != self and other.solid and not other.snap_to_tile and other.raise == 0.0:
			props.append(other)
	var spot := house.get_place_spot(cell, true, props)
	return spot


func _house() -> House:
	var node := get_parent()
	while node and not node is House:
		node = node.get_parent()
	return node as House


## The footprint for the way it's facing. Snapped decor (snap_to_tile) always
## takes exactly one tile, TILE_FOOTPRINT, whatever size its art is.
func current_footprint() -> Vector2:
	if snap_to_tile:
		return TILE_FOOTPRINT
	if (facing == Prop.Facing.RIGHT or facing == Prop.Facing.LEFT) and side_footprint != Vector2.ZERO:
		return side_footprint
	return footprint


## The tag for the other look ("down_knocked", "down_on", "down_lit"), or
## "" if the sheet has none of them.
func change_tag() -> String:
	if _art_node == null:
		return ""
	var base := _art_node.facing_tag()
	for kind: String in ["_knocked", "_on", "_lit", "_broken", "_played"]:
		if _art_node.has_tag(base + kind):
			return base + kind
	return ""


## True if the ghost can only change it one way (a "_knocked" or "_broken"
## tag).
func is_one_way() -> bool:
	var tag := change_tag()
	return tag.ends_with("_knocked") or tag.ends_with("_broken")


## True for a breakable (a "_broken" tag): once the ghost breaks it, it stays
## broken.
func is_breakable() -> bool:
	return change_tag().ends_with("_broken")


## True if the player can switch it with a click or E: not fires (the
## lantern lights those) or breakables (only the ghost touches those).
func player_can_switch() -> bool:
	return not is_lit_type() and not is_breakable()


## True for a fire (a "_lit" tag): only the player's lantern lights it.
func is_lit_type() -> bool:
	return change_tag().ends_with("_lit")


## The ghost never touches fires. (When it may knock things over or break
## them - sanity, the break cooldown - is the ghost's call: see Ghost.may_use.)
func ghost_can_use(_ghost: Ghost) -> bool:
	return not is_lit_type()


## True if `player` can light it with the lantern: within Player.USE_REACH
## of her feet, like any house object (for decor up on a table, of its tile).
func in_lantern_reach(player: Player) -> bool:
	return player.can_reach(self)


## Up on a table, the ghost has to reach the tile it sits on (from the
## nearest open side of the table), not the table's front edge where its
## origin is.
func get_reach_area() -> Rect2:
	var house := _house()
	if _lift > 0.0 and has_meta("place_tile") and house:
		return house.tile_rect(get_meta("place_tile"))
	return super()


## Called by the lantern (F): lights it, or puts it out.
func light_with_lantern() -> void:
	changed = not changed
	_play_change_sound()


## Broken: EMF 4 (50% chance of a 5). Knocked over: 2-3 (30%). Switched on:
## 1-2 (10%). (The 5 only for ghost types that show EMF 5.)
func emf_levels() -> Vector2i:
	if is_breakable():
		return Vector2i(4, 4)
	return Vector2i(2, 3) if is_one_way() else Vector2i(1, 2)


func emf_5_chance() -> float:
	if is_breakable():
		return 0.5
	return 0.3 if is_one_way() else 0.1


func can_ghost_interact() -> bool:
	if is_one_way() and changed:
		return false  # already knocked over
	return super()


## The ghost switches it, knocks it over, breaks it or sets it going. (What
## the ghost itself does after breaking something - appearing - is in
## Ghost._after_using.)
func _on_ghost_interact(_ghost: Ghost) -> void:
	if is_played_type():
		_start_playing()
		return
	changed = not changed
	_play_change_sound()


## The way it faces, from `facing` (a sink facing left is used from its left).
func get_front_direction() -> Vector2:
	match facing:
		Prop.Facing.RIGHT:
			return Vector2.RIGHT
		Prop.Facing.LEFT:
			return Vector2.LEFT
		Prop.Facing.UP:
			return Vector2.UP
	return Vector2.DOWN


## The area its art's frame covers - and, for snapped decor, the whole tile
## it sits on.
func get_click_rect() -> Rect2:
	var rect := _art_node.get_art_rect() if _art_node else get_footprint()
	return rect.merge(_tile_click_rect) if _tile_click_rect.has_area() else rect


## Snapped decor: anywhere on the tile it sits on, or on its art. Everything
## else: only its drawn pixels, not the see-through parts of the frame.
func is_clicked_at(point: Vector2) -> bool:
	if _tile_click_rect.has_point(point):
		return true  # anywhere on its tile (snapped decor)
	return _art_node.is_art_at(point) if _art_node else get_footprint().has_point(point)


func _on_player_interact(_player: Player) -> void:
	if not player_can_switch():
		return  # fires are lit with the lantern; breakables stay broken
	if is_played_type():
		_start_playing()
		return
	changed = not changed
	_play_change_sound()


## True for an animation that plays for a while (a "_played" tag).
func is_played_type() -> bool:
	return change_tag().ends_with("_played")


## Plays its "_played" animation for `play_time` seconds (from the start
## again if it's already playing).
func _start_playing() -> void:
	changed = true
	_play_time_left = play_time
	_play_change_sound()


func _physics_process(delta: float) -> void:
	if _play_time_left <= 0.0:
		return
	_play_time_left -= delta
	if _play_time_left <= 0.0:
		changed = false


func describe_last_interaction() -> String:
	var thing := String(name).capitalize().to_lower()
	if is_breakable():
		return "broke the %s" % thing
	if is_played_type():
		return "set the %s going" % thing
	if is_one_way():
		return "knocked over the %s" % thing
	return "switched %s the %s" % ["on" if changed else "off", thing]


func _update_art() -> void:
	queue_redraw()
	if not is_inside_tree():
		return  # _ready does it
	if Engine.is_editor_hint():
		_preview_snap()
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
	_art_node.position = _shift + art_offset - Vector2(0, _lift)
	# In the editor the node hasn't moved in front of the table yet, so lift
	# the preview over it to show it on top.
	_art_node.z_index = 1 if Engine.is_editor_hint() and _lift > 0.0 else 0
	var tag := change_tag()
	_art_node.animation = tag if changed and tag != "" else ""
	if is_instance_valid(show_while_changed):
		show_while_changed.visible = changed


## Editor: works out where it will snap to, for drawing it there.
func _preview_snap() -> void:
	_shift = Vector2.ZERO
	_lift = raise
	_snap_ok = true
	if not snap_to_tile:
		return
	var spot := snap_spot()
	if spot.is_empty():
		return
	_snap_ok = spot.ok
	if spot.ok:
		_shift = spot.position - global_position
		_lift = spot.elevation


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var size := current_footprint()
	var r := Rect2(_shift + Vector2(-size.x / 2.0, -size.y), size)
	if not _snap_ok:
		draw_rect(r, Color(1, 0.2, 0.2, 0.9), false, 1.0)  # can't go here
	elif _lift == 0.0:
		draw_rect(r, Color(1, 1, 1, 0.4), false, 1.0)  # what it blocks
	else:
		# Where it rests up on the table.
		draw_rect(Rect2(r.position - Vector2(0, _lift), r.size), Color(0.4, 0.8, 1, 0.7), false, 1.0)
		draw_line(_shift, _shift - Vector2(0, _lift), Color(0.4, 0.8, 1, 0.4), 1.0)
	if art == null:
		draw_rect(Rect2(r.position - Vector2(0, _lift + 8), Vector2(r.size.x, r.size.y + 8)),
			Color(0.6, 0.5, 0.4))
	# The residue preview goes on its own node, over the art.
	if _residue_preview == null:
		_residue_preview = Node2D.new()
		_residue_preview.z_index = 2
		_residue_preview.draw.connect(_draw_residue_preview)
		add_child(_residue_preview, false, INTERNAL_MODE_BACK)
	_residue_preview.queue_redraw()


## Editor: the residue art (faint) where it will glow, and a green cross on
## its centre.
func _draw_residue_preview() -> void:
	if is_lit_type():
		return  # the ghost never touches fires, so no residue
	var g := _shift + residue_position - Vector2(0, _lift)
	if preview_residue:
		var tex := residue_art
		if tex == null and ResourceLoader.exists(ResidueGlow.DEFAULT_ART):
			tex = load(ResidueGlow.DEFAULT_ART)
		if tex:
			ResidueGlow.draw_art(_residue_preview, tex, g, residue_flip, Color(1, 1, 1, 0.7))
	var c := Color(0.35, 1, 0.45, 0.9)
	_residue_preview.draw_line(g - Vector2(2, 0), g + Vector2(2, 0), c, 1.0)
	_residue_preview.draw_line(g - Vector2(0, 2), g + Vector2(0, 2), c, 1.0)


# --- Sound ----------------------------------------------------------------------

## Plays change_sound (or change_back_sound) where it stands - or its tag's
## default if that's empty. Call right after `changed` flips.
func _play_change_sound() -> void:
	var sound: Variant = change_sound if changed else change_back_sound
	if sound == null:
		var tag := change_tag()
		for kind: String in DEFAULT_SOUNDS:
			if tag.ends_with(kind):
				sound = DEFAULT_SOUNDS[kind][0 if changed else 1]
	Sfx.play(sound, global_position, sound_volume_db)


## Starts loop_sound while it shows its other look, and stops it after.
func _update_loop_sound() -> void:
	if Engine.is_editor_hint() or not is_inside_tree() or loop_sound == null:
		return
	if not changed:
		if _loop_player:
			_loop_player.stop()
		return
	if _loop_player == null:
		_loop_player = AudioStreamPlayer2D.new()
		_loop_player.stream = loop_sound
		_loop_player.bus = Sfx.BUS
		_loop_player.volume_db = loop_volume_db
		_loop_player.max_distance = Sfx.MAX_DISTANCE
		_loop_player.attenuation = Sfx.ATTENUATION
		# Starts over when it ends, for files exported without a loop.
		_loop_player.finished.connect(func():
			if changed: _loop_player.play())
		add_child(_loop_player)
	if not _loop_player.playing:
		_loop_player.play()
