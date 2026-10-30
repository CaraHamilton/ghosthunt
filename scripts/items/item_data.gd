class_name ItemData
extends Resource
## The definition of one *kind* of item - the facts every copy shares.
## There is one .tres file per kind in res://items/ (e.g. thermometer.tres).
##
## Never put anything that changes during play in here: Resources are shared,
## so every thermometer would see the same value. Per-copy state (a
## thermometer's reading, a ball's residue) lives on the ItemInstance.

## Unique id, also the .tres file name (e.g. "thermometer" -> thermometer.tres).
@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
## Toolbar/floor icon. If empty, the item's script draws a placeholder.
@export var icon: Texture2D
## This item in the player's hand, drawn on top of them while it's selected
## (they switch to their hold_ animations). Just the item, exported from its
## own layer: 4 frames of 16x32 per row, rows hold_down, hold_up, hold_side.
## Empty = the item isn't shown in hand and the player walks normally.
@export var held_sheet: Texture2D
## How many fit in one slot. Tools with their own state should stay at 1.
@export_range(1, 999) var max_stack := 1
## Script (extending ItemInstance) that gives this item its behaviour.
## Empty = a plain item with no special behaviour.
@export var instance_script: Script
## Scene spawned when the item is dropped. Empty = the generic floor pickup.
## Its root needs an `item` property (see ItemPickup, TennisBall).
@export var world_scene: PackedScene
