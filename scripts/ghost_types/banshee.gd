class_name BansheeBehavior
extends GhostBehavior
## Banshee. Override GhostBehavior hooks here to give it its own behaviour.


## Banshees leave UV residue on everything they touch.
func leaves_uv_residue() -> bool:
	return true


## Freezing ghost: its favourite room drops below 0 °C. Rooms it only passes
## through cool as normal.
func get_cold_temperature(base_temperature: float, is_favorite_room: bool) -> float:
	return FREEZING_TEMPERATURE if is_favorite_room else base_temperature
