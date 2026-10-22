class_name ItemDB
extends RefCounted
## Looks up item definitions by id and creates new copies of items.
##   ItemDB.create("thermometer")  -> a new Thermometer instance
## Definitions are the .tres files in res://items/, named after their id.

const ITEMS_DIR := "res://items/"

static var _cache := {}


static func get_data(id: StringName) -> ItemData:
	if not _cache.has(id):
		var path := "%s%s.tres" % [ITEMS_DIR, id]
		var data := load(path) as ItemData
		if data == null:
			push_error("No item definition at %s" % path)
			return null
		_cache[id] = data
	return _cache[id]


## A brand new copy of the item, with fresh state.
static func create(id: StringName, count := 1) -> ItemInstance:
	return create_from_data(get_data(id), count)


static func create_from_data(data: ItemData, count := 1) -> ItemInstance:
	var item: ItemInstance = data.instance_script.new() if data.instance_script else ItemInstance.new()
	item.data = data
	item.count = count
	return item
