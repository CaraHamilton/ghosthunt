class_name DemonBehavior
extends GhostBehavior
## Demon. Override GhostBehavior hooks here to give it its own behaviour.


## Demons (and Wraiths) can leave EMF 5 on what they touch and where they
## appear.
func shows_emf_5() -> bool:
	return true


## Demons possess the doll when it's near them.
func possesses_doll() -> bool:
	return true
