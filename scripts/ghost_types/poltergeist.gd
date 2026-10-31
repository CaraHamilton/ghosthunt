class_name PoltergeistBehavior
extends GhostBehavior
## Poltergeist. Override GhostBehavior hooks here to give it its own behaviour.


## Poltergeists possess the doll when it's near them.
func possesses_doll() -> bool:
	return true


## Poltergeists leave UV residue on everything they touch.
func leaves_uv_residue() -> bool:
	return true
