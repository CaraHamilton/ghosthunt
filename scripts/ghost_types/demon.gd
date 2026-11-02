class_name DemonBehavior
extends GhostBehavior
## Demon. Override GhostBehavior hooks here to give it its own behaviour.


## Demons (and Wraiths) push the EMF reader to 5: whenever any
## other ghost would read 4 (player close by, or during a hunt), a demon reads 5.
func get_emf_level(base_level: int) -> int:
	return 5 if base_level >= 4 else base_level


## Demons possess the doll when it's near them.
func possesses_doll() -> bool:
	return true
