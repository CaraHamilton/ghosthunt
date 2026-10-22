class_name PoltergeistBehavior
extends GhostBehavior
## Poltergeist. Override GhostBehavior hooks here to give it its own behaviour.


## Poltergeists roll the tennis ball around when it's near them.
func plays_with_ball() -> bool:
	return true


## Poltergeists leave UV residue on everything they touch.
func leaves_uv_residue() -> bool:
	return true
