class_name EMFReader
extends ItemInstance
## Electromagnetic field reader, 0-5. Usually reads 0. The EMF comes from
## things the ghost did, never from the ghost itself (see EMFSource):
##   1-2  next to something the ghost switched on (a sink)
##   2-3  next to something the ghost knocked over (a stack of books)
##   4    where the ghost appeared
##   5    only ghosts that show EMF 5 (Poltergeist, Sentry, Demon): sometimes
##        instead of the above - 10% of 1-2s, 30% of 2-3s, 50% of 4s
## During a hunt it goes haywire everywhere, flashing 1-4 at random (never 5).

## How close (px) the reader must be to an object (its footprint) or a spot
## to pick up its EMF.
var reach := 32.0
## Seconds between reading updates.
var sample_interval := 0.2

var level := 0

var _sample_timer := 0.0


## Keeps sampling wherever it is (pocket or floor), so it always has a live
## reading for wherever it is.
func process_always(delta: float) -> void:
	_sample_timer -= delta
	if _sample_timer > 0.0:
		return
	_sample_timer = sample_interval
	var game := Game.current
	if game == null:
		return
	if game.ghost and game.ghost.is_hunting:
		level = randi_range(1, 4)  # as if broken
		return
	level = _source_level(game)


## The strongest EMF source in reach (0 if none). Drops the ones that
## have faded.
func _source_level(game: Game) -> int:
	var now := Game.game_time()
	game.emf_sources = game.emf_sources.filter(func(s: EMFSource) -> bool: return s.is_active(now))
	var pos := get_world_position()
	var best := 0
	for source: EMFSource in game.emf_sources:
		if source.reaches(pos, reach):
			best = maxi(best, source.level)
	return best
