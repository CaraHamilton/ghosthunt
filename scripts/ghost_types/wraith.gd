class_name WraithBehavior
extends GhostBehavior
## Wraith. Override GhostBehavior hooks here to give it its own behaviour.


## Like a Demon, a Wraith can leave EMF 5 on what it touches and where it
## appears.
func shows_emf_5() -> bool:
	return true


## Freezing ghost: its favourite room drops below 0 °C. Rooms it only passes
## through cool as normal.
func get_cold_temperature(base_temperature: float, is_favorite_room: bool) -> float:
	return FREEZING_TEMPERATURE if is_favorite_room else base_temperature
