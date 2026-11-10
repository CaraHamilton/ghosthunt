class_name FaeBehavior
extends GhostBehavior
## Fae. Override GhostBehavior hooks here to give it its own behaviour.


## Fae leave UV residue on everything they touch.
func leaves_uv_residue() -> bool:
	return true


## Fae show up as a figure in the fog machine's fog.
func shows_in_fog() -> bool:
	return true


## Fae freeze for a moment when holy water splashes them.
func reacts_to_holy_water() -> bool:
	return true
