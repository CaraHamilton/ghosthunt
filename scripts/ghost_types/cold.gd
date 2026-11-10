class_name ColdBehavior
extends GhostBehavior
## Cold. Override GhostBehavior hooks here to give it its own behaviour.


## Freezing ghost: its favourite room drops below 0 °C. Rooms it only passes
## through cool as normal.
func get_cold_temperature(base_temperature: float, is_favorite_room: bool) -> float:
	return FREEZING_TEMPERATURE if is_favorite_room else base_temperature


## Cold ghosts show up as a figure in the fog machine's fog.
func shows_in_fog() -> bool:
	return true


## Cold ghosts freeze for a moment when holy water splashes them.
func reacts_to_holy_water() -> bool:
	return true
