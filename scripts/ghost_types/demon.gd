class_name DemonBehavior
extends GhostBehavior
## Demon. Override GhostBehavior hooks here to give it its own behaviour.


## Freezing ghost: its favourite room drops below 0 °C. Rooms it only passes
## through cool as normal.
func get_cold_temperature(base_temperature: float, is_favorite_room: bool) -> float:
	return FREEZING_TEMPERATURE if is_favorite_room else base_temperature


## Demons can leave EMF 5 on what they touch and where they appear.
func shows_emf_5() -> bool:
	return true


## Demons possess the doll when it's near them.
func possesses_doll() -> bool:
	return true
