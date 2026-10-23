class_name WraithBehavior
extends GhostBehavior
## Wraith. Override GhostBehavior hooks here to give it its own behaviour.


## Like a Demon, a Wraith pushes the EMF reader to 5: whenever any other
## ghost would read 4 (player close by, or during a hunt), a wraith reads 5.
func get_emf_level(base_level: int) -> int:
	return 5 if base_level >= 4 else base_level


## Freezing ghost: its favourite room drops below 0 °C. Rooms it only passes
## through cool as normal.
func get_cold_temperature(base_temperature: float, is_favorite_room: bool) -> float:
	return FREEZING_TEMPERATURE if is_favorite_room else base_temperature
