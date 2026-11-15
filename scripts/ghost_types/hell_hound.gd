class_name HellHoundBehavior
extends GhostBehavior
## Hell Hound. Override GhostBehavior hooks here to give it its own behaviour.


## Hell hounds can leave EMF 5 on what they touch and where they appear.
func shows_emf_5() -> bool:
	return true


## Hell hounds leave UV residue on everything they touch.
func leaves_uv_residue() -> bool:
	return true


## Hell hounds freeze for a moment when holy water splashes them.
func reacts_to_holy_water() -> bool:
	return true
