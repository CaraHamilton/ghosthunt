class_name GhostBehavior
extends RefCounted
## Base class for type-specific ghost behaviour. Each ghost type (Demon,
## Banshee, Poltergeist) extends this and overrides the hooks it cares about.
## The defaults do nothing, so every ghost currently acts the same.
##
## To add a behaviour: override a hook in the type's script. If you need a
## hook that doesn't exist yet, add it here with a do-nothing default and
## call it from ghost.gd.

enum Type { DEMON, BANSHEE, POLTERGEIST }

## The ghost this behaviour drives. Set before `on_spawned()` is called.
var ghost: Ghost


## Creates the behaviour object for a ghost type.
static func create(type: Type) -> GhostBehavior:
	match type:
		Type.DEMON:
			return DemonBehavior.new()
		Type.BANSHEE:
			return BansheeBehavior.new()
		Type.POLTERGEIST:
			return PoltergeistBehavior.new()
	push_error("Unknown ghost type: %s" % type)
	return GhostBehavior.new()


static func random_type() -> Type:
	return Type.values().pick_random()


static func type_name(type: Type) -> String:
	return Type.keys()[type].capitalize()


# --- Hooks: override these in a ghost type -------------------------------

## Called once, right after the ghost is added to the scene (it is still
## invisible and starting to fade in).
func on_spawned() -> void:
	pass


## Called every physics frame, before the ghost runs its normal state logic.
func process(_delta: float) -> void:
	pass


## Called whenever the ghost changes state (see Ghost.State).
func on_state_changed(_old_state: Ghost.State, _new_state: Ghost.State) -> void:
	pass


## Called the moment the ghost notices the player has hidden.
func on_player_hid() -> void:
	pass


## Called when the ghost catches the player, just before game over.
func on_caught_player() -> void:
	pass


## Speed used while chasing. `base_speed` already includes wave difficulty.
func get_chase_speed(base_speed: float) -> float:
	return base_speed


## Speed used while searching for a hidden player.
func get_search_speed(base_speed: float) -> float:
	return base_speed


## How long the ghost searches for a hidden player before giving up.
func get_search_time(base_time: float) -> float:
	return base_time
