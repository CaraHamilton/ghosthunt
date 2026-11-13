class_name HolyWaterItem
extends ItemInstance
## Holy water: a stack of flasks. Click (or F) throws one at the mouse
## pointer - anywhere within THROW_RANGE of the player. It's lobbed through
## the air, then shatters in a SPLASH_SIZE splash (see HolyWaterFlask). If it
## splashes the ghost while it's visible, ghost types that react to holy
## water freeze for a moment.
##
## While it's the selected item, a box on the floor shows where the flask
## would land. Past THROW_RANGE the box stops at the edge of the range. It
## turns red over a spot the flask can't land on - a wall, solid furniture,
## off the floor, or behind a wall - and clicking there does nothing.

## How far (px) from the player a flask can be thrown: 8 tiles.
const THROW_RANGE := 128.0
## The splash area (px), centred where the flask lands.
const SPLASH_SIZE := Vector2(32, 32)
## Where the flask leaves the player's hand.
const HAND_OFFSET := Vector2(0, -10)
const RETICLE_COLOR := Color(0.7, 0.9, 1.0, 0.6)
const BLOCKED_COLOR := Color(1.0, 0.3, 0.3, 0.7)
## The flask in the air (16x16 frames) and its splash (32x32 frames).
const FLASK_ART := preload("res://art/overworld/holy_water_overworld.png")
const SPLASH_ART := preload("res://art/overworld/holy_water_splash.png")
## Optional aiming box art, centred on the aim point. Either one 32x32 frame
## (tinted red when blocked) or two side by side, 64x32: frame 0 = can throw,
## frame 1 = blocked. Until the file exists, a plain outline is drawn.
const AIM_ART_PATH := "res://art/overworld/holy_water_aim.png"
## How solid the aiming art is drawn (1 = fully solid, 0 = invisible).
const AIM_OPACITY := 0.6

var _reticle: Node2D
var _aim_ok := true


func start_use() -> void:
	var player := holder
	if player == null or player.selected_item != self or player.is_dead:
		return
	var aim := aim_toward(player.get_global_mouse_position())
	if not aim.ok:
		return  # can't land there
	player.inventory.remove_from_slot(player.selected_slot, 1)
	var flask := HolyWaterFlask.new()
	flask.start = player.global_position + HAND_OFFSET
	flask.target = aim.position
	flask.flask_art = FLASK_ART
	flask.splash_art = SPLASH_ART
	Game.current.world.add_child(flask)
	Sfx.play("tools/holy_water_throw")
	if not player.inventory.items().has(self):
		_free_reticle()  # that was the last flask


## Where a flask thrown at `point` (world space) would land, and whether it
## can:
##   position - `point`, pulled in to THROW_RANGE if it's further away
##   ok       - false over a wall, solid furniture, off the floor, or with a
##              wall between the player and it
func aim_toward(point: Vector2) -> Dictionary:
	var from := holder.global_position
	var aim := point - from
	if aim.length() > THROW_RANGE:
		aim = aim.normalized() * THROW_RANGE
	var at := from + aim
	return {position = at, ok = _can_land_at(at) and not _wall_between(from, at)}


func _can_land_at(point: Vector2) -> bool:
	var house := Game.current.house
	var cell := house.tile_at(point)
	if house.floor_layer.get_cell_source_id(cell) == -1 or house.is_wall_at(point):
		return false
	for obstacle: Node2D in holder.get_tree().get_nodes_in_group("nav_obstacles"):
		if obstacle.get_footprint().has_point(point):
			return false
	return true


func _wall_between(from: Vector2, to: Vector2) -> bool:
	var house := Game.current.house
	var steps := maxi(int(from.distance_to(to) / 2.0), 1)
	for i in range(1, steps + 1):
		if house.is_wall_at(from.lerp(to, float(i) / steps)):
			return true
	return false


func process_always(_delta: float) -> void:
	var showing := holder != null and holder.selected_item == self \
		and not holder.is_dead and not holder.in_menu
	if not showing:
		if is_instance_valid(_reticle):
			_reticle.visible = false
		return
	if not is_instance_valid(_reticle):
		_reticle = Node2D.new()
		_reticle.z_index = 5
		var art: Texture2D = load(AIM_ART_PATH) if ResourceLoader.exists(AIM_ART_PATH) else null
		_reticle.draw.connect(func() -> void:
			var color := RETICLE_COLOR if _aim_ok else BLOCKED_COLOR
			var r := Rect2(-SPLASH_SIZE / 2.0, SPLASH_SIZE)
			if art:
				var two_frames := art.get_width() >= SPLASH_SIZE.x * 2.0
				var frame := 0 if _aim_ok or not two_frames else 1
				var tint := Color.WHITE if _aim_ok or two_frames else Color(1.0, 0.4, 0.4)
				tint.a = AIM_OPACITY
				_reticle.draw_texture_rect_region(art, r,
					Rect2(Vector2(frame * SPLASH_SIZE.x, 0), SPLASH_SIZE), tint)
				return
			_reticle.draw_rect(r, color, false, 1.0)
			_reticle.draw_circle(Vector2.ZERO, 1.5, color))
		Game.current.world.add_child(_reticle)
	var aim := aim_toward(holder.get_global_mouse_position())
	if aim.ok != _aim_ok:
		_aim_ok = aim.ok
		_reticle.queue_redraw()
	_reticle.visible = true
	_reticle.global_position = (aim.position as Vector2).round()


func on_dropped(_node: Node2D) -> void:
	_free_reticle()


func _free_reticle() -> void:
	if is_instance_valid(_reticle):
		_reticle.queue_free()
	_reticle = null
