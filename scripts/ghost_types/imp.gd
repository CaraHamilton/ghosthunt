class_name ImpBehavior
extends GhostBehavior
## Imp. Override GhostBehavior hooks here to give it its own behaviour.


## Imps leave UV residue on everything they touch.
func leaves_uv_residue() -> bool:
	return true


## Imps show up as a figure in the fog machine's fog.
func shows_in_fog() -> bool:
	return true


## Imps freeze for a moment when holy water splashes them.
func reacts_to_holy_water() -> bool:
	return true
