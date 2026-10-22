@tool
class_name TennisBall
extends GhostInteractable
## A tennis ball lying on the floor - the world version of a TennisBallItem.
## Spawned when the player drops the ball; E picks it back up. Only some
## ghost types play with it: when one is close by, it (invisibly) knocks the
## ball rolling a couple of tiles. Rolling balls bounce off walls and
## furniture. Ghost traces (residue, last touch) are kept on `item` so they
## survive being picked up.

## The item this node represents (set before it's added to the scene).
var item: TennisBallItem:
	set(value):
		item = value
		has_residue = item.has_residue
		_last_interaction_time = item.last_ghost_touch_time

## How far (px) a ghost's nudge rolls the ball.
@export var min_roll_distance := 28.0
@export var max_roll_distance := 52.0
## How quickly a rolling ball slows down (px/s²).
@export var friction := 70.0

const RADIUS := 3.0

var is_rolling: bool:
	get:
		return _velocity != Vector2.ZERO

var _velocity := Vector2.ZERO
var _spin := 0.0


## Note: the ball's exported settings (footprint, solid, ghost_reach,
## cooldown, prompt_height...) are set in scenes/tennis_ball.tscn, not here,
## so the editor never copies stale values into other scenes.
func _init() -> void:
	residue_offset = Vector2(0, -RADIUS)


func ghost_can_use(ghost: Ghost) -> bool:
	return ghost.behavior.plays_with_ball()


func _on_ghost_interact(_ghost: Ghost) -> void:
	if item:
		item.has_residue = has_residue
		item.last_ghost_touch_time = _last_interaction_time
	var distance := randf_range(min_roll_distance, max_roll_distance)
	var direction := Vector2.RIGHT.rotated(randf() * TAU)
	# Start fast enough that friction brings it to rest after `distance`.
	_velocity = direction * sqrt(2.0 * friction * distance)


func describe_last_interaction() -> String:
	return "rolled the tennis ball"


func _on_player_interact(player: Player) -> void:
	if player.pick_up(item, self):
		_velocity = Vector2.ZERO
		queue_free()


func get_player_prompt() -> String:
	return "[E] Pick up"


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if item:
		item.process_always(delta)
	if _velocity == Vector2.ZERO:
		return
	var motion := _velocity * delta
	var direction := _velocity.normalized()
	var query := PhysicsRayQueryParameters2D.create(
		global_position, global_position + motion + direction * RADIUS, 1)  # world layer
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit:
		# Bounce off walls/furniture, losing some speed.
		_velocity = _velocity.bounce(hit.normal) * 0.5
	else:
		global_position += motion
	_spin += motion.length() / RADIUS
	var speed := maxf(0.0, _velocity.length() - friction * delta)
	_velocity = Vector2.ZERO if speed < 1.0 else _velocity.normalized() * speed
	queue_redraw()


# --- Placeholder art ------------------------------------------------------

func _draw() -> void:
	var center := Vector2(0, -RADIUS)
	draw_set_transform(Vector2(0, 0.5), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, RADIUS + 0.5, Color(0, 0, 0, 0.3))  # shadow
	draw_set_transform(Vector2.ZERO)
	draw_circle(center, RADIUS, Color("d8f040"))
	# The white seam turns as the ball rolls
	draw_arc(center, RADIUS - 1.0, _spin, _spin + PI * 0.8, 6, Color(1, 1, 1, 0.9), 0.8)
