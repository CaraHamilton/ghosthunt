class_name BansheeBehavior
extends GhostBehavior
## Banshee. Override GhostBehavior hooks here to give it its own behaviour.


## Banshees leave UV residue on everything they touch.
func leaves_uv_residue() -> bool:
	return true
