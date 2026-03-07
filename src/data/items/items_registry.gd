@tool
class_name ItemRegistry extends Node

@export var auto_build: bool = true
@export var debug_mode: bool = true


var ITEM_LIBRARY = "res://src/data/items/item_library.tres"
var ITEM_ARRAY = "res://src/data/items/items.tres"
var BLOCK_REGISTRY = "res://src/data/blocks/blocks_registry.gd"

var ITEM_BLOCK: Array[ItemData] = []
var ITEM: Array = []
var item_array: ItemArrayRegistry


func _ready() -> void:
	if Engine.is_editor_hint():
		if auto_build:
			call_deferred("_build_library")
	else:
		if auto_build:
			await get_tree().create_timer(1.0).timeout
			call_deferred("_build_library")


func _build_library() -> void:
	if debug_mode:
		print("Начало собирания предметов")
	

	print("Подгружаем предмет из библиотеки")

	var item_library = load(ITEM_LIBRARY)

	var s = item_library.getArray("consumble_item")
	var z = item_library.getArray("block_item")


	for items in z:
		ITEM_BLOCK.append(items)

	for items in s:
		ITEM.append(items)
	
	item_array = ItemArrayRegistry.new()
	
	for v in ITEM:
		item_array.addItem(v)

	var block_registry = load(BLOCK_REGISTRY)
	print("Начало сборки блоков")

	var registry = block_registry.new()
	
	registry._build_library(ITEM_BLOCK)

		
	var value = 0
	for c in ITEM_BLOCK:
		value += 1
		c.id_block += value
		item_array.addItem(c)
	
	ResourceSaver.save(item_array, ITEM_ARRAY)
