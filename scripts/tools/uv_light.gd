class_name UVLight
extends ItemInstance
## A UV flashlight. While held (F / left mouse) it shines a purple beam of
## real light about 4 tiles in front of the holder, replacing their normal
## lantern glow. Ghost residue (left by some ghost types on things they
## touch) glows green wherever the beam falls on it - see UVBeam.
##
## The beam starts at the flashlight's lens in the held art: the brightest
## pixels of each frame of the held_sheet, so it follows the hand's bob and
## any redraw. Frames with no lens showing (facing up, the light is in front
## of her) use the facing-down lens, mirrored to her other side.

## Where the beam starts if the held art has no lens to find (player space).
const DEFAULT_LENS := Vector2(0, -6)
## Pixels at least this bright (0-1), and within LENS_TOLERANCE of the
## brightest pixel in the frame, count as the lens.
const MIN_LENS_BRIGHTNESS := 0.4
const LENS_TOLERANCE := 0.05

var _beam: UVBeam
var _held_image: Image
## Lens centre per frame, in frame pixels: Vector2i(row, frame) -> Vector2,
## or Vector2.INF if that frame has no lens.
var _lens_cache := {}


func start_use() -> void:
	if _beam == null:
		_beam = UVBeam.new()
		holder.add_child(_beam)
	_beam.visible = true
	_set_lantern(false)


func stop_use() -> void:
	if _beam:
		_beam.visible = false
	_set_lantern(true)


func process_use(_delta: float) -> void:
	_beam.position = _lens_position()
	_beam.rotation = holder.facing.angle()


## Where the lens is right now, in the holder's space.
func _lens_position() -> Vector2:
	var sprite := holder.sprite
	var row := Player.HELD_ROWS.find(sprite.animation)
	if row == -1 or data.held_sheet == null:
		return DEFAULT_LENS
	var lens := _find_lens(row, sprite.frame)
	var frame_width := float(data.held_sheet.get_width()) / holder.held_item.hframes
	if lens == Vector2.INF and Player.HELD_ROWS[row] == &"hold_up":
		lens = _find_lens(Player.HELD_ROWS.find(&"hold_down"), sprite.frame)
		if lens != Vector2.INF:
			lens.x = frame_width - lens.x  # the hand on her other side
	if lens == Vector2.INF:
		return DEFAULT_LENS
	if sprite.flip_h:
		lens.x = frame_width - lens.x
	var frame_size := Vector2(frame_width, float(data.held_sheet.get_height()) / holder.held_item.vframes)
	return sprite.position - frame_size / 2.0 + lens  # the sprite is centred


## The centre of the lens (brightest pixels) in one frame of the held sheet,
## in that frame's pixels, or INF if there's none.
func _find_lens(row: int, frame: int) -> Vector2:
	var key := Vector2i(row, frame)
	if _lens_cache.has(key):
		return _lens_cache[key]
	if _held_image == null:
		_held_image = data.held_sheet.get_image()
	var size := Vector2i(_held_image.get_width() / holder.held_item.hframes,
		_held_image.get_height() / holder.held_item.vframes)
	var corner := Vector2i(frame, row) * size
	var brightest := 0.0
	var pixels: Array[Vector2i] = []
	var levels: Array[float] = []
	for y in size.y:
		for x in size.x:
			var color := _held_image.get_pixelv(corner + Vector2i(x, y))
			if color.a < 0.5:
				continue
			pixels.append(Vector2i(x, y))
			levels.append(color.get_luminance())
			brightest = maxf(brightest, color.get_luminance())
	var result := Vector2.INF
	if brightest >= MIN_LENS_BRIGHTNESS:
		var sum := Vector2.ZERO
		var count := 0
		for i in pixels.size():
			if levels[i] >= brightest - LENS_TOLERANCE:
				sum += Vector2(pixels[i]) + Vector2(0.5, 0.5)  # pixel centres
				count += 1
		result = sum / count
	_lens_cache[key] = result
	return result


func _set_lantern(on: bool) -> void:
	var lantern := holder.get_node_or_null("Lantern")
	if lantern:
		lantern.visible = on


func draw_icon(canvas: CanvasItem, rect: Rect2) -> void:
	if data.icon:
		super(canvas, rect)
		return
	var c := rect.get_center()
	var body := Rect2(c.x - rect.size.x * 0.32, c.y - 4, rect.size.x * 0.45, 8)
	canvas.draw_rect(body, Color("3a3050"))
	canvas.draw_rect(body, Color("15101e"), false, 1.5)
	var head := PackedVector2Array([
		Vector2(body.end.x, body.position.y - 1), Vector2(body.end.x + 9, body.position.y - 5),
		Vector2(body.end.x + 9, body.end.y + 5), Vector2(body.end.x, body.end.y + 1)])
	canvas.draw_colored_polygon(head, Color("4a3e66"))
	canvas.draw_line(Vector2(body.end.x + 9, body.position.y - 4), Vector2(body.end.x + 9, body.end.y + 4), Color("b070ff"), 3.0)
