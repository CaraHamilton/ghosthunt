class_name GhostBehavior
extends RefCounted
## Base class for type-specific ghost behaviour. Each ghost type (Demon, Wraith,
## Banshee, Poltergeist) extends this and overrides the hooks it cares about.
## The defaults do nothing, so every ghost currently acts the same.
##
## To add a behaviour: override a hook in the type's script. If you need a
## hook that doesn't exist yet, add it here with a do-nothing default and
## call it from ghost.gd.

enum Type { DEMON, BANSHEE, POLTERGEIST, WRAITH }

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
		Type.WRAITH:
			return WraithBehavior.new()
	push_error("Unknown ghost type: %s" % type)
	return GhostBehavior.new()


static func random_type() -> Type:
	return Type.values().pick_random()


static func type_name(type: Type) -> String:
	return Type.keys()[type].capitalize()


## The evidence a ghost type shows (for the journal).
static func evidence_for(type: Type) -> Array[Evidence.Type]:
	return create(type).get_evidence()


## Which evidence this ghost type shows. Worked out from its own behaviour
## hooks, so the journal always matches how the ghost really acts. Override
## only if a type needs evidence the hooks can't express.
func get_evidence() -> Array[Evidence.Type]:
	var result: Array[Evidence.Type] = []
	if get_cold_temperature(3.0, true) < 0.0:
		result.append(Evidence.Type.FREEZING)
	if get_emf_level(4) >= 5:
		result.append(Evidence.Type.EMF_5)
	if plays_with_ball():
		result.append(Evidence.Type.TOY_INTERACTION)
	if leaves_uv_residue():
		result.append(Evidence.Type.UV_RESIDUE)
	return result


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


## Called during a hunt when the ghost loses sight of the player it was
## chasing (it then goes to investigate where it last saw them).
func on_lost_sight_of_player() -> void:
	pass


## Called when the ghost catches the player, just before game over.
func on_caught_player() -> void:
	pass


## Chance (0-1) of starting a hunt on each check once off cooldown.
## Return 0 to stop this ghost hunting on its own.
func get_hunt_chance(base_chance: float) -> float:
	return base_chance


## Hunts only start once the player's sanity is below this fraction (0-1).
## e.g. an aggressive ghost type could return 0.85 to hunt sooner.
func get_hunt_sanity_threshold(base_threshold: float) -> float:
	return base_threshold


## Seconds after a hunt (and at the start) before the ghost may hunt again.
func get_hunt_cooldown(base_cooldown: float) -> float:
	return base_cooldown


## Chance (0-1) that the ghost wanders out of its favourite room.
func get_roam_chance(base_chance: float) -> float:
	return base_chance


## Chance (0-1) that a ghost outside its favourite room heads back home.
func get_return_home_chance(base_chance: float) -> float:
	return base_chance


## What freezing ghost types (Banshee, Wraith) chill their favourite room
## towards, in °C - cold enough that it reliably reads below zero.
const FREEZING_TEMPERATURE := -8.0


## Temperature (°C) the ghost's current room cools towards. `base_temperature`
## is colder for the favourite room than for rooms it is just passing through.
func get_cold_temperature(base_temperature: float, _is_favorite_room: bool) -> float:
	return base_temperature


## Chance (0-1) per check that the ghost interacts with `item` while near it
## (e.g. a Poltergeist could mess with things far more often).
func get_interaction_chance(_item: GhostInteractable, base_chance: float) -> float:
	return base_chance


## Whether this ghost type plays with the tennis ball (rolls it around).
func plays_with_ball() -> bool:
	return false


## Whether this ghost type leaves UV residue (a green glow only visible under
## the UV light) on the things it interacts with.
func leaves_uv_residue() -> bool:
	return false


## Called right after the ghost interacts with something (e.g. a sink).
func on_interacted(_item: GhostInteractable) -> void:
	pass


## Final say on what the EMF reader shows (0-5). `base_level` is worked out
## from distance, rooms and hunts, and never exceeds 4.
func get_emf_level(base_level: int) -> int:
	return base_level


## Speed during a hunt while it can see the player and goes straight for
## them. `base_speed` already includes the chase ramp-up (slower than the
## player at first, faster after keeping sight of them for a while).
func get_chase_speed(base_speed: float) -> float:
	return base_speed


## Speed during a hunt while heading to where it last saw the player.
## `base_speed` is the player's walking speed.
func get_investigate_speed(base_speed: float) -> float:
	return base_speed


## Speed while searching around the last place it saw the player.
func get_search_speed(base_speed: float) -> float:
	return base_speed


## How long the ghost searches before giving up and ending the hunt.
func get_search_time(base_time: float) -> float:
	return base_time
