class_name Evidence
extends RefCounted
## The kinds of evidence a ghost can show. Each ghost type has a set of these
## (see GhostBehavior.get_evidence); the player records what they've found in
## the journal to narrow down which ghost it is.

enum Type { FREEZING, EMF_5, TOY_INTERACTION, UV_RESIDUE }

const NAMES := {
	Type.FREEZING: "Freezing",
	Type.EMF_5: "EMF 5",
	Type.TOY_INTERACTION: "Toy interaction",
	Type.UV_RESIDUE: "UV Residue",
}


static func name_of(type: Type) -> String:
	return NAMES[type]
