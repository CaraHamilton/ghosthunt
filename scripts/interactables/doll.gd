@tool
class_name Doll
extends GhostInteractable
## A doll sitting on the floor - the world version of a DollItem. Spawned
## when the player puts the doll down; E picks it back up. Only some ghost
## types (see GhostBehavior.possesses_doll) bother with it: when one is close
## by, it (invisibly) goes and stands on the doll and possesses it, and the
## doll stands up and waves. When the possession ends the doll sits back
## down. Ghost traces (residue, last touch) are kept on `item` so they
## survive being picked up.

## The item this node represents (set before it's added to the scene).
var item: DollItem:
	set(value):
		item = value
		has_residue = item.has_residue
		_last_interaction_time = item.last_ghost_touch_time

## How long (seconds) a possession lasts, picked at random each time.
@export var min_possess_time := 5.0
@export var max_possess_time := 10.0

## The ghost possessing the doll right now (null when it's just a doll).
var possessed_by: Ghost = null
var is_possessed: bool:
	get:
		return possessed_by != null

@onready var sprite: AnimatedSprite2D = $Sprite


## Note: the doll's exported settings (footprint, solid, ghost_reach,
## cooldown, prompt_height...) are set in scenes/doll.tscn, not here, so the
## editor never copies stale values into other scenes.
func _init() -> void:
	residue_offset = Vector2(0, -6)


func _ready() -> void:
	super()
	if not Engine.is_editor_hint():
		# Always put down sitting, whichever animation the scene was saved on.
		sprite.play(&"sit")


func ghost_can_use(ghost: Ghost) -> bool:
	return ghost.behavior.possesses_doll()


## Not while it's already possessed (the cooldown counts from when the ghost
## lets go).
func can_ghost_interact() -> bool:
	return not is_possessed and super()


func _on_ghost_interact(ghost: Ghost) -> void:
	_save_traces()
	ghost.possess(self, randf_range(min_possess_time, max_possess_time))


## Called by the ghost once it's standing on the doll.
func on_possessed(ghost: Ghost) -> void:
	possessed_by = ghost
	sprite.play(&"stand_and_wave")


## Called by the ghost when the possession ends (or the doll is picked up).
func on_released() -> void:
	possessed_by = null
	sprite.play(&"sit")
	# The ghost was touching it until now: the EMF and cooldown count from here.
	_last_interaction_time = _game_time()
	_save_traces()


func describe_last_interaction() -> String:
	return "possessed the doll"


func _on_player_interact(player: Player) -> void:
	if not player.pick_up(item, self):
		return
	if possessed_by:
		possessed_by.end_possession()
	queue_free()


func get_player_prompt() -> String:
	return "[E] Pick up"


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if item:
		item.process_always(delta)


func _save_traces() -> void:
	if item:
		item.has_residue = has_residue
		item.last_ghost_touch_time = _last_interaction_time


func _draw() -> void:
	draw_set_transform(Vector2(0, 0), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 4.0, Color(0, 0, 0, 0.3))  # shadow
	draw_set_transform(Vector2.ZERO)
