class_name JournalItem
extends ItemInstance
## The player's journal. Using it (F / left mouse) opens the journal window,
## where the player ticks off the evidence they've found and sees which ghost
## types still fit. Each journal remembers its own ticks.

## The evidence ticked in this journal.
var checked: Array[Evidence.Type] = []


func is_checked(evidence: Evidence.Type) -> bool:
	return evidence in checked


func set_checked(evidence: Evidence.Type, value: bool) -> void:
	if value and evidence not in checked:
		checked.append(evidence)
	elif not value:
		checked.erase(evidence)


## Ghost types whose evidence includes everything ticked so far.
func possible_ghosts() -> Array[GhostBehavior.Type]:
	var result: Array[GhostBehavior.Type] = []
	for type: GhostBehavior.Type in GhostBehavior.Type.values():
		var evidence := GhostBehavior.evidence_for(type)
		if checked.all(func(e): return e in evidence):
			result.append(type)
	return result


func start_use() -> void:
	Game.current.journal_panel.open(self, holder)


func draw_icon(canvas: CanvasItem, rect: Rect2) -> void:
	if data.icon:
		super(canvas, rect)
		return
	var book := Rect2(rect.position + rect.size * Vector2(0.2, 0.12), rect.size * Vector2(0.6, 0.76))
	canvas.draw_rect(Rect2(book.position + Vector2(3, 3), book.size), Color("f0e6cc"))  # pages
	canvas.draw_rect(book, Color("7a3b2a"))  # cover
	canvas.draw_rect(book, Color("3a1a10"), false, 2.0)
	canvas.draw_rect(Rect2(book.position.x + 3, book.position.y, 3, book.size.y), Color("5a2a1c"))  # spine
	canvas.draw_rect(Rect2(book.get_center() - Vector2(5, 3), Vector2(12, 6)), Color("e0c070"))  # label
