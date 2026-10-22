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


## Chance (0-1) of starting a hunt on each check once off cooldown.
## Return 0 to stop this ghost hunting on its own.
func get_hunt_chance(base_chance: float) -> float:
	return base_chance


## Seconds after a hunt (and at the start) before the ghost may hunt again.
func get_hunt_cooldown(base_cooldown: float) -> float:
	return base_cooldown


## Chance (0-1) that the ghost wanders out of its favourite room.
func get_roam_chance(base_chance: float) -> float:
	return base_chance


## Chance (0-1) that a ghost outside its favourite room heads back home.
func get_return_home_chance(base_chance: float) -> float:
	return base_chance


## Temperature (°C) the ghost's current room cools towards. `base_temperature`
## is colder for the favourite room than for rooms it is just passing through.
func get_cold_temperature(base_temperature: float) -> float:
	return base_temperature


## Chance (0-1) per check that the ghost interacts with `item` while near it
## (e.g. a Poltergeist could mess with things far more often).
func get_interaction_chance(_item: GhostInteractable, base_chance: float) -> float:
	return base_chance


## Called right after the ghost interacts with something (e.g. a sink).
func on_interacted(_item: GhostInteractable) -> void:
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
