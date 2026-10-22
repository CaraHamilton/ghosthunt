class_name TennisBallItem
extends ItemInstance
## The tennis ball as an item. Using it (F / left mouse) drops it on the
## floor, same as the drop key. On the floor it becomes a TennisBall node
## (scenes/tennis_ball.tscn) that some ghost types roll around.
##
## The ball's ghost traces live here, on the item, so they stay with this
## ball when it's picked up and put down again.

## True once a residue-leaving ghost has touched this ball (UV-visible).
var has_residue := false
## Game time the ghost last touched it (for the EMF reader and cooldown).
var last_ghost_touch_time := -INF


func start_use() -> void:
	holder.drop_selected()


func draw_icon(canvas: CanvasItem, rect: Rect2) -> void:
	if data.icon:
		super(canvas, rect)
		return
	var c := rect.get_center()
	var r := rect.size.x * 0.3
	canvas.draw_circle(c, r, Color("d8f040"))
	canvas.draw_arc(c + Vector2(-r * 0.9, 0), r * 0.75, -PI * 0.4, PI * 0.4, 10, Color.WHITE, 2.0)
	canvas.draw_arc(c + Vector2(r * 0.9, 0), r * 0.75, PI * 0.6, PI * 1.4, 10, Color.WHITE, 2.0)
	canvas.draw_arc(c, r, 0.0, TAU, 24, Color("8a9a20"), 1.5)
