class_name Sfx
extends Object
## Plays sound effects by name, from anywhere: `Sfx.play(...)`.
##
##   Sfx.play("player/footstep")                  # heard at full volume
##   Sfx.play("objects/break", global_position)   # in the world: quieter far
##                                                # away, panned left/right
##
## A name is a file under res://audio/sfx/, without the extension:
## "objects/break" plays res://audio/sfx/objects/break.wav (or .ogg / .mp3).
## For variety, export a few takes numbered from 1 - break_1.wav,
## break_2.wav, break_3.wav... - and a random one plays each time. Every play
## is also nudged a little higher or lower in pitch, so even one file doesn't
## sound robotic.
##
## A name with no file yet plays nothing, so sounds can be hooked up before
## they're made (see res://audio/sfx/README.md for every name).
##
## Anything can also pass an AudioStream instead of a name (e.g. a sound set
## in the Inspector) - including an AudioStreamRandomizer, Godot's own
## "pick one of these" sound.

const SFX_DIR := "res://audio/sfx/"
const EXTENSIONS: Array[String] = ["wav", "ogg", "mp3"]
## The most numbered takes looked for (name_1 ... name_N).
const MAX_VARIANTS := 8
## Every play's pitch is randomly up to this much higher or lower (0.06 = 6%).
const PITCH_VARIATION := 0.06
## Bus all sound effects go through (see the Audio tab at the bottom of the
## editor: Master <- SFX, Ambience, Music).
const BUS := &"SFX"
## How far (px) away a world sound can still be heard. The house is roughly
## 40 tiles across, so a sink running a room or two away is faint but there.
const MAX_DISTANCE := 480.0
## How fast world sounds fade with distance (1 = linear, higher = drops off
## sooner).
const ATTENUATION := 1.5

## name -> AudioStream, or null if it has no file.
static var _cache := {}


## Plays `sound` (a name or an AudioStream). With `at` (a global position) it
## plays in the world there; without, at full volume (UI, the player's own
## footsteps). Returns the player node, or null if there's nothing to play.
static func play(sound: Variant, at: Variant = null, volume_db := 0.0, pitch_variation := PITCH_VARIATION) -> Node:
	var stream := get_stream(sound)
	if stream == null:
		return null
	var player: Node
	if at is Vector2:
		var p2d := AudioStreamPlayer2D.new()
		p2d.max_distance = MAX_DISTANCE
		p2d.attenuation = ATTENUATION
		p2d.position = at
		player = p2d
	else:
		player = AudioStreamPlayer.new()
	player.stream = stream
	player.bus = BUS
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	player.finished.connect(player.queue_free)
	# World sounds go in the game's world so they share its 2D space (and the
	# camera that hears them); the rest go on the scene tree's root.
	var parent: Node = (Engine.get_main_loop() as SceneTree).root
	if at is Vector2 and Game.current and is_instance_valid(Game.current.world):
		parent = Game.current.world
	parent.add_child(player)
	player.play()
	return player


## The stream for `sound` (a name or an AudioStream), or null if there's no
## file for that name.
static func get_stream(sound: Variant) -> AudioStream:
	if sound is AudioStream:
		return sound
	if sound == null or String(sound) == "":
		return null
	var key := String(sound)
	if not _cache.has(key):
		_cache[key] = _load(key)
	return _cache[key]


## True if `sound` has a file (or is a stream).
static func has_sound(sound: Variant) -> bool:
	if sound is AudioStream:
		return true
	if sound == null or String(sound) == "":
		return false
	var key := String(sound)
	if not _cache.has(key):
		_cache[key] = _load(key)
	return _cache[key] != null


## Loads name.wav, or the numbered takes name_1, name_2... as one
## AudioStreamRandomizer that picks a random one each time.
static func _load(key: String) -> AudioStream:
	var single := _find_file(SFX_DIR + key)
	if single:
		return single
	var takes: Array[AudioStream] = []
	for i in range(1, MAX_VARIANTS + 1):
		var take := _find_file("%s%s_%d" % [SFX_DIR, key, i])
		if take == null:
			break
		takes.append(take)
	if takes.is_empty():
		return null
	if takes.size() == 1:
		return takes[0]
	var randomizer := AudioStreamRandomizer.new()
	randomizer.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
	randomizer.random_pitch = 1.0  # we vary the pitch ourselves
	for take in takes:
		randomizer.add_stream(-1, take)
	return randomizer


static func _find_file(path_without_ext: String) -> AudioStream:
	for ext in EXTENSIONS:
		var path := "%s.%s" % [path_without_ext, ext]
		if ResourceLoader.exists(path):
			return load(path) as AudioStream
	return null
