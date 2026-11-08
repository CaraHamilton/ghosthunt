class_name EMFSource
extends RefCounted
## Something the EMF reader picks up: an object the ghost touched, or the
## spot where it appeared. The EMF never comes from the ghost itself.
##
## Each source rolls its level once when it's made, from its range (e.g. 1-2
## for a sink the ghost switched on). Ghost types that show EMF 5 (see
## GhostBehavior.shows_emf_5) may roll a 5 instead, with the source's own
## chance. Sources fade after `duration` seconds.
##
## Make them with Game.add_emf_source().

## The level the reader shows near it (1-5).
var level := 0
## The object giving it off (follows it around), or null for a spot.
var node: Node2D = null
## The spot giving it off, when there's no node.
var position := Vector2.ZERO
## Game time it was made, and how long (s) it lasts.
var created := 0.0
var duration := 20.0


## Rolls a level between `min_level` and `max_level`, or 5 with `chance_5`
## if the ghost type shows EMF 5.
static func roll_level(min_level: int, max_level: int, chance_5: float, behavior: GhostBehavior) -> int:
	if behavior and behavior.shows_emf_5() and randf() < chance_5:
		return 5
	return randi_range(min_level, max_level)


func is_active(now: float) -> bool:
	if node != null and not is_instance_valid(node):
		return false  # the object's gone (e.g. the doll was picked up)
	return now - created < duration


## True if `point` is within `reach` px of it (of the object's footprint, or
## of the spot).
func reaches(point: Vector2, reach: float) -> bool:
	if node == null:
		return point.distance_to(position) <= reach
	if node.has_method("get_footprint"):
		var area: Rect2 = node.get_footprint()
		return area.grow(reach).has_point(point)
	return point.distance_to(node.global_position) <= reach
