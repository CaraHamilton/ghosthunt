@tool
class_name Sink
extends GhostInteractable
## A sink the ghost can turn on (or off, if it's already running). The
## player can turn it on and off too, with E.

signal toggled(is_on: bool)

@export var is_on := false:
	set(value):
		is_on = value
		queue_redraw()

const HEIGHT := 12.0  # how tall the cabinet front is drawn

var _t := 0.0


func _init() -> void:
	footprint = Vector2(28, 14)
	player_can_use = true
	prompt_height = footprint.y + HEIGHT + 14.0


func _process(delta: float) -> void:
	if is_on:
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
