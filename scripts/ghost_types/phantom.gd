class_name PhantomBehavior
extends GhostBehavior
## Phantom. Override GhostBehavior hooks here to give it its own behaviour.


## Phantoms leave UV residue on everything they touch.
func leaves_uv_residue() -> bool:
	return true


## Phantoms possess the doll when it's near them.
func possesses_doll() -> bool:
	return true


## Phantoms freeze for a moment when holy water splashes them.
func reacts_to_holy_water() -> bool:
	return true
