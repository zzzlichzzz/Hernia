class_name Item_Id_Registry extends Resource

const size_block = 65536 + 1

@export var temp_id: Dictionary[int, String]
@export var list_id: Dictionary[String, int]


var errors: Dictionary[String, int]


var item_id: int
var item_string: String
var list_id_null: Dictionary[int, String]

var temp_file: Item_Id_Registry


func registry_id(array: ItemLibrary):
	var path = get_newest_file("res://src/data/items/tres_build/temp")
	if path == "res://src/data/items/tres_build/temp/temp.tres":
		temp_file = load(path) 
		temp_id = temp_file.temp_id
	
	
	var s = array.getArray("consumble_item")
	var z = array.getArray("block_item").duplicate()

	
	var count_new_item = count_new_element(s)
	check_items(s)
	
	if count_new_item.size() != 0:
		var count = count_item()
		for i in count_new_item.size():
			if temp_id.get(list_id.get(count_new_item.get(i).id)) != null: 
				count += 1
				continue
			list_id.set(count_new_item.get(i).id, i + count + size_block)
			temp_id.set(i + count + size_block, count_new_item.get(i).id)

	var count_new_block = count_new_element(z)
	var without_element = without_new_element(z)
	
	check_blocks(without_element)
	
	if count_new_block.size() != 0:
		var count = count_block()
		for a in count_new_block.size():
			if temp_id.get(list_id.get(count_new_block.get(a).id)) != null: 
				count += 1
				continue 
			list_id.set(count_new_block.get(a).id, a + count)
			temp_id.set(count + a, count_new_block.get(a).id)
		
		
	save_resource()

func count_item() -> int:
	var count = 0
	for v in list_id.keys():
		if list_id.get(v) < size_block: continue
		count += 1
	return count

func count_block() -> int:
	var count = 0
	for v in list_id.keys():
		if list_id.get(v) >= size_block: continue
		count += 1
	return count
	

func test_check_items(s: Array[ItemData]) ->  void:
	for a in list_id.keys():
		if list_id.get(a) < size_block: continue
		if s.any(func(obj): return obj.id == a): continue
		push_error("Ошибка, данный предмет был удалён, с помощью интерфейса вручную измените. Id:{id}, Id Item:{item}".format({"id": list_id.get(a), "item": a}))
		errors.set(a, list_id.get(a))


func test_check_blocks(without_element: Array[ItemData]) ->  void:
	for a in list_id.keys():
		if list_id.get(a) >= size_block: continue
		if without_element.any(func(obj): return obj.id == a): continue
		push_error("Ошибка, данный предмет был удалён, с помощью интерфейса вручную измените Id:{id}, Id Block:{block}".format({"id": list_id.get(a), "block": a}))
		errors.set(a, list_id.get(a))


func check_items(s: Array[ItemData]) -> void:
	test_check_items(s)

func check_blocks(without_element: Array[ItemData]) -> void:
	test_check_blocks(without_element)

func without_new_element(array: Array[ItemData]) -> Array[ItemData]:
	var count: Array[ItemData] = []
	for a in array:
		if list_id.get(a.id, null) != null: count.append(a)
	return count

func count_new_element(array: Array[ItemData]) -> Array[ItemData]:
	var count: Array[ItemData] = []
	for a in array:
		if list_id.get(a.id, null) == null: count.append(a)
	return count
	
func is_element_array(element: ItemData) -> bool:
	var c = ""
	for a in list_id.keys():
		if list_id.get(a) >= size_block: continue
		if a == element.id: 
			return true
		c = a
	push_error("Ошибка, данный предмет был удалён, с помощью интерфейса вручную измените Id:{id}, Id Block:{block}".format({"id": list_id.get(c), "block": c}))
	return false	

func save_resource():

	var new_res = Item_Id_Registry.new()

	new_res.temp_id = temp_id
	new_res.list_id = list_id

	var count = get_file_count("res://src/data/items/tres_build/temp") + 1
	var resultD = ResourceSaver.save(new_res, "res://src/data/items/tres_build/temp/temp.tres")
	#var result = ResourceSaver.save(new_res, "res://src/data/items/tres_build/temp/temp%s.tres" % [count])
	#var result = ResourceSaver.save(new_res, "res://src/data/items/tres_build/temp/temp.tres")

	#if result == OK:
		#print("Ресурс успешно сохранен!")
	#else:
		#print("Ошибка сохранения: ", result)
	
func get_newest_file(path: String) -> String:
	var dir = DirAccess.open(path)
	var newest_file = ""
	var last_mod_time = 0

	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if not dir.current_is_dir():
				var full_path = path + "/" + file_name
				var mod_time = FileAccess.get_modified_time(full_path)
		
				if mod_time > last_mod_time:
					last_mod_time = mod_time
					newest_file = full_path
					
			file_name = dir.get_next()
	else:
		print("Ошибка: не удалось открыть директорию.")

	return newest_file

func get_file_count(path: String) -> int:
	var file_count = 0
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				file_count += 1
			file_name = dir.get_next()
	else:
		print("Ошибка доступа к папке")
	return file_count

func get_list_id() -> Dictionary[String, int]:
	return list_id
