@tool
class_name ItemRegistry extends Node

const size_block = 65536 + 1

@export var auto_build: bool = true
@export var debug_mode: bool = true


var ITEM_LIBRARY = "res://src/data/items/item_library.tres"
var ITEM_ARRAY = "res://src/data/items/registry/items.tres"
var BLOCK_REGISTRY = "res://src/data/blocks/blocks_registry.gd"

var ITEM_REGISTRY_ID = "res://src/data/items/tres_build/temp/temp.tres"

var ITEM_BLOCK: Dictionary[int, ItemData]
var ITEM: Dictionary[int, ItemData]
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
	var item_registry_id: Item_Id_Registry = load(ITEM_REGISTRY_ID)
	if item_registry_id == null:
		item_registry_id = Item_Id_Registry.new()
		ResourceSaver.save(item_registry_id, ITEM_REGISTRY_ID)
		item_registry_id = load(ITEM_REGISTRY_ID)
	
	var consumble_item = item_library.getArray("consumble_item")
	var block_item: Array = item_library.getArray("block_item")
	var block_logic: Array = item_library.getArray("block_logic")
	block_item.append_array(block_logic)
	
	
	item_registry_id.registry_id(item_library)


	if item_registry_id.errors.size() != 0:
		var block_empty: ItemBlock = ItemBlock.new()
		block_empty.id = "empty"
		for d in item_registry_id.errors.keys():
			if item_registry_id.get_list_id().get(d) >= size_block: 
				ITEM.set(item_registry_id.get_list_id().get(d), null)
				continue
			ITEM_BLOCK.set(item_registry_id.get_list_id().get(d), block_empty)

	for items in block_item:
		var int_id = item_registry_id.get_list_id().get(items.id)
		if items.id == "empty" and int_id == 0: continue
		items.set_id_int(int_id)
		ITEM_BLOCK.set(item_registry_id.get_list_id().get(items.id), items)

	for items in consumble_item:
		var int_id = item_registry_id.get_list_id().get(items.id)
		items.set_id_int(int_id)
		ITEM.set(item_registry_id.get_list_id().get(items.id), items)


	var block_registry = load(BLOCK_REGISTRY)
	var registry = block_registry.new()
	registry._build_library(ITEM_BLOCK)
	
	item_array = ItemArrayRegistry.new()
	
	item_array.item_array.resize(500000)
	
	for v in ITEM_BLOCK.keys():
		item_array.items.set(ITEM_BLOCK.get(v).id, ITEM_BLOCK.get(v).get_id_int())
		item_array.addItem(ITEM_BLOCK.get(v).get_id_int(), ITEM_BLOCK.get(v))

	print("Начало сборки блоков")
	
	for c in ITEM.keys():
		if ITEM.get(c) == null: continue
		item_array.items.set(ITEM.get(c).id, ITEM.get(c).get_id_int())
		item_array.addItem(ITEM.get(c).get_id_int(), ITEM.get(c))
	
	is_icon_items(item_registry_id.list_id)
	
	ResourceSaver.save(item_array, ITEM_ARRAY)

func count_errors(list: Dictionary[String, int]) -> int:
	
	return 0

func is_icon_items(list: Dictionary[String, int]) -> void:
	var png: Array = find_png_files("res://src/assets/textures/gui/icons/items/")
	for v in list.keys():
		if list.get(v) < size_block: continue
		if png.any(func(obj): return obj.name == v): continue
		push_error("У данного предмета нет текстурки: {name}, закиньте в res://src/assets/textures/gui/icons/items/ ".format({"name": v}))
	

func find_png_files(folder: String) -> Array:
	"""Ищет все PNG файлы в папке и подпапках"""
	var files = []
	_find_png_files_recursive(folder, files)
	files.sort_custom(func(a, b): return a.name < b.name)
	return files

func _find_png_files_recursive(folder: String, files: Array):
	var dir = DirAccess.open(folder)
	if not dir:
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue
		
		var full_path = folder.path_join(file_name)
		
		if dir.current_is_dir():
			_find_png_files_recursive(full_path, files)
		else:
			if file_name.ends_with(".png") and not file_name.ends_with(".png.import"):
				var block_name = file_name.get_basename()
				files.append({
					"name": block_name,
					"path": full_path
				})
				print("    Найден PNG: " + block_name)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
