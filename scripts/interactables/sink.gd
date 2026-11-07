@tool
class_name Sink
extends GhostInteractable
## A sink the ghost can turn on (or off, if it's already running). The
## player can turn it on and off too, with E.
##
## Give it `art` like any furniture (see Prop): a sheet with "down", "right"...
## frames for when it's off, plus a "<facing>_on" tag (e.g. "down_on") that
## loops while it's running. A facing with no "_on" tag of its own uses the
## one for the frame it shows (a "left" sink showing "right" uses "right_on").
## Without art it draws a placeholder sink.

signal toggled(is_on: bool)

@export var is_on := false:
	set(value):
		is_on = value
		_update_art()
## The sink's picture or Aseprite sheet. Empty = placeholder.
@export var art: Texture2D:
	set(value):
		art = value
		_update_art()
## Which way the sink faces (which frame of the sheet is shown).
@export var facing := Prop.Facing.DOWN:
	set(value):
		facing = value
		_update_art()
## Area on the floor when facing right or left. Leave at (0, 0) to use
## `footprint`.
@export var side_footprint := Vector2.ZERO:
	set(value):
		side_footprint = value
		_update_art()
## How tall (px) the front of the cabinet is in the art: the UV residue is
## drawn this far above the middle of the footprint, on the counter.
@export var front_height := 13.0

const HEIGHT := 12.0  # how tall the placeholder's cabinet front is drawn

var _t := 0.0
## Draws `art` (a Prop just for its drawing - the sink itself is the solid
## part). Not saved in the scene.
var _art_node: Prop


## Note: the sink's exported settings (footprint, player_can_use,
## prompt_height...) are set in scenes/sink.tscn, not here. Setting exported
## values in code makes the editor copy them into every scene that uses a
## sink, where they can get out of date.
func _init() -> void:
	residue_offset = Vector2(0, -HEIGHT - 7.0)  # on the counter


func _ready() -> void:
	if not Engine.is_editor_hint():
		footprint = current_footprint()
		if art:
			residue_offset = Vector2(0, -footprint.y / 2.0 - front_height)
	super()
	_update_art()


## The footprint for the way the sink is facing.
func current_footprint() -> Vector2:
	if (facing == Prop.Facing.RIGHT or facing == Prop.Facing.LEFT) and side_footprint != Vector2.ZERO:
		return side_footprint
	return footprint


## Shows the art's frame for `facing`, or its "_on" animation while running.
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
		add_child(_art_node, false, INTERNAL_MODE_FRONT)
	_art_node.art = art
	_art_node.facing = facing
	_art_node.footprint = footprint
	_art_node.side_footprint = side_footprint
	var on_tag := _art_node.facing_tag() + "_on"
	_art_node.animation = on_tag if is_on and _art_node.has_tag(on_tag) else ""


func _process(delta: float) -> void:
	if is_on and art == null:
		_t += delta
		queue_redraw()


func _on_ghost_interact(_ghost: Ghost) -> void:
	_toggle()


func _on_player_interact(_player: Player) -> void:
	_toggle()


func get_player_prompt() -> String:
	return "[E] Turn off" if is_on else "[E] Turn on"


func _toggle() -> void:
	is_on = not is_on
	_refresh_prompt()
	toggled.emit(is_on)


func describe_last_interaction() -> String:
	return "turned %s the %s" % ["on" if is_on else "off", String(name).capitalize().to_lower()]


# --- Placeholder art ------------------------------------------------------

func _draw() -> void:
	if art:
		return  # _art_node draws it
	var w := footprint.x
	var d := footprint.y
	var top := Rect2(-w / 2.0, -d - HEIGHT, w, d)  # counter top
	var front := Rect2(-w / 2.0, -HEIGHT, w, HEIGHT)  # cabinet
	var counter := Color("c8c4bc")
	var cabinet := Color("6e8a9a")
	var outline := Color("3a3a48")

	draw_rect(Rect2(-w / 2.0 + 1, -2, w, 3), Color(0, 0, 0, 0.25))  # shadow
	draw_rect(front, cabinet)
	draw_rect(front, outline, false, 1.0)
	# Cabinet doors
	draw_line(Vector2(0, front.position.y + 2), Vector2(0, front.end.y - 1), outline, 1.0)
	draw_rect(Rect2(-3, front.get_center().y - 1, 1, 2), Color("e0c070"))
	draw_rect(Rect2(2, front.get_center().y - 1, 1, 2), Color("e0c070"))

	draw_rect(top, counter)
	draw_rect(top, outline, false, 1.0)
	# Basin
	var basin := Rect2(-9, top.position.y + 4, 18, d - 6)
	draw_rect(basin, Color("8a96a0"))
	draw_rect(basin, outline, false, 1.0)
	# Faucet at the back
	var spout := Vector2(0, top.position.y + 5)
	draw_rect(Rect2(-1.5, top.position.y + 1, 3, 3), Color("b8c0c8"))
	draw_line(Vector2(0, top.position.y + 2), spout, Color("b8c0c8"), 1.5)
	draw_rect(Rect2(-5, top.position.y + 1, 2, 2), Color("d84040"))  # hot tap
	draw_rect(Rect2(3, top.position.y + 1, 2, 2), Color("4070d8"))   # cold tap

	if is_on:
		var water := Color(0.55, 0.8, 1.0, 0.85)
		# Pool of water in the basin
		draw_rect(basin.grow(-1.5), Color(0.45, 0.7, 0.95, 0.6))
		# Falling stream with drifting droplets
		draw_line(spout, Vector2(0, basin.end.y - 2), water, 1.5)
		for i in 3:
			var y := fposmod(_t * 18.0 + i * 3.0, basin.size.y - 2.0)
			draw_rect(Rect2(-0.5, spout.y + y, 1, 1), Color.WHITE)
		# Little splash ripples
		var r := 2.0 + fposmod(_t * 6.0, 4.0)
		draw_arc(Vector2(0, basin.end.y - 3), r, PI, TAU, 8, Color(1, 1, 1, 0.6 - r * 0.1), 1.0)
