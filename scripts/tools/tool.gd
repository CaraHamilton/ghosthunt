class_name Tool
extends RefCounted
## Base class for items in the player's toolbar. A tool is "used" while the
## player holds the use button (F / left mouse). Override the hooks below to
## make a new tool, then give it to the player with `player.give_tool()`.

var display_name := "Tool"
## If true, the player stands still while using this tool.
var blocks_movement := false
## The player holding this tool (set by Player.give_tool).
var player: Player


## Called when the player starts using the tool.
func start_use() -> void:
	pass


## Called when the player stops using the tool (or switches away from it).
func stop_use() -> void:
	pass


## Called every frame while the tool is being used.
func process_use(_delta: float) -> void:
	pass


## Called every frame while the tool is in the toolbar, whether or not it's
## selected or in use (e.g. a sensor that keeps measuring in your pocket).
func process_always(_delta: float) -> void:
	pass


## Text shown on screen while the tool is in use ("" for nothing).
func get_readout() -> String:
	return ""


## Placeholder icon for the toolbar slot. Swap for a texture later.
func draw_icon(canvas: CanvasItem, rect: Rect2) -> void:
	canvas.draw_rect(rect.grow(-rect.size.x * 0.25), Color.GRAY)
