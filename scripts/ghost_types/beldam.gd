class_name BeldamBehavior
extends GhostBehavior
## Beldam. Override GhostBehavior hooks here to give it its own behaviour.


## Beldams can leave EMF 5 on what they touch and where they appear.
func shows_emf_5() -> bool:
	return true


## Beldams possess the doll when it's near them.
func possesses_doll() -> bool:
	return true


## Beldams show up as a figure in the fog machine's fog.
func shows_in_fog() -> bool:
	return true
