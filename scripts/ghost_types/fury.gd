class_name FuryBehavior
extends GhostBehavior
## Fury. Override GhostBehavior hooks here to give it its own behaviour.


## Freezing ghost: its favourite room drops below 0 °C. Rooms it only passes
## through cool as normal.
func get_cold_temperature(base_temperature: float, is_favorite_room: bool) -> float:
	return FREEZING_TEMPERATURE if is_favorite_room else base_temperature


## Furies can leave EMF 5 on what they touch and where they appear.
func shows_emf_5() -> bool:
	return true


## Furies freeze for a moment when holy water splashes them.
func reacts_to_holy_water() -> bool:
	return true
