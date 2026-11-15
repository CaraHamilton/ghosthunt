class_name HighPriestBehavior
extends GhostBehavior
## High Priest. Override GhostBehavior hooks here to give it its own behaviour.


## High priests possess the doll when it's near them.
func possesses_doll() -> bool:
	return true


## High priests show up as a figure in the fog machine's fog.
func shows_in_fog() -> bool:
	return true


## High priests freeze for a moment when holy water splashes them.
func reacts_to_holy_water() -> bool:
	return true
