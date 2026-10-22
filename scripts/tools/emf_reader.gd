class_name EMFReader
extends ItemInstance
## Electromagnetic field reader, 0-5. Usually reads 0.
##   1-3  the ghost is in the same room (stronger the closer it is), or the
##        player is next to something the ghost touched recently
##   4    the ghost is within a few tiles, or a hunt is happening anywhere
##   5    only a Demon or Wraith: whenever another ghost would read 4
## The 5 rule lives in each type's get_emf_level() (Demon, Wraith), so ghost types
## decide their own EMF quirks.

## Within this distance (px) of the ghost the reader shows 4 (~3.5 tiles).
var close_range := 56.0
## Distance bands (px) for 3 and 2 while the ghost is in the same room;
## anywhere else in the room reads 1.
var room_level_3_range := 100.0
var room_level_2_range := 160.0
## How close (px) to a touched object the reader must be to pick it up.
var trace_range := 32.0
## How long (s) a ghost's touch keeps showing on the reader. It fades:
## 3 at first, then 2, then 1.
var trace_duration := 20.0
## Chance per update that a 1-3 reading wobbles by one (never into 4/5).
var flicker_chance := 0.2
## Seconds between reading updates.
var sample_interval := 0.2

var level := 0

var _sample_timer := 0.0


## Keeps sampling wherever it is (pocket or floor), so it always has a live
## reading for wherever it is.
func process_always(delta: float) -> void:
	_sample_timer -= delta
	if _sample_timer > 0.0:
		return
	_sample_timer = sample_interval
	var game := Game.current
	if game == null:
		return
	level = clampi(game.ghost.behavior.get_emf_level(_base_level(game)), 0, 5)


func _base_level(game: Game) -> int:
	var ghost := game.ghost
	var house := game.house
	if ghost.is_hunting:
		return 4
	var pos := get_world_position()
	var dist := pos.distance_to(ghost.global_position)
	if dist <= close_range:
		return 4

	var result := 0
	var player_room := house.room_at(pos)
	if player_room != "" and player_room == house.room_at(ghost.global_position):
		if dist <= room_level_3_range:
			result = 3
		elif dist <= room_level_2_range:
			result = 2
		else:
			result = 1
	result = maxi(result, _trace_level(game, pos))

	if result > 0 and randf() < flicker_chance:
		result = clampi(result + (1 if randf() < 0.5 else -1), 1, 3)
	return result


## 1-3 if the reader is next to something the ghost touched recently.
func _trace_level(game: Game, pos: Vector2) -> int:
	var best := 0
	for obj: GhostInteractable in game.get_tree().get_nodes_in_group("ghost_interactables"):
		if not obj.get_footprint().grow(trace_range).has_point(pos):
			continue
		var age := obj.seconds_since_ghost_interaction()
		if age >= trace_duration:
			continue
		best = maxi(best, 3 - int(age / (trace_duration / 3.0)))
	return best


func get_readout() -> String:
	return "EMF  %s%s  %d" % ["●".repeat(level), "·".repeat(5 - level), level]


func draw_icon(canvas: CanvasItem, rect: Rect2) -> void:
	var body := Rect2(rect.position + rect.size * Vector2(0.2, 0.1), rect.size * Vector2(0.6, 0.8))
	canvas.draw_rect(body, Color("2e3440"))
	canvas.draw_rect(body, Color("101418"), false, 2.0)
	# Five LEDs, green to red
	var colors := [Color("4cd964"), Color("a8e04c"), Color("f2d24c"), Color("f29a3c"), Color("e8443a")]
	var led_w := body.size.x / 6.0
	for i in 5:
		var led := Rect2(body.position.x + led_w * (i + 0.5), body.position.y + 5, led_w * 0.7, 6)
		canvas.draw_rect(led, colors[i])
	# Antenna-ish screen
	canvas.draw_rect(Rect2(body.position + Vector2(5, 16), Vector2(body.size.x - 10, body.size.y - 22)), Color("1c2430"))
