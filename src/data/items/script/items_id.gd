class_name Item_Id_Registry extends Resource

const size_block = 65536 + 1

@export var temp_id: Dictionary[int, String]
@export var list_id: Dictionary[String, int]


var it = [4, 3, 2, 5]
var v = [3,2,3]


var item_id: int
var item_string: String
var list_id_null: Dictionary[int, String]

var temp_file: Item_Id_Registry

func _ready() -> void:
	pass # Replace with function body.


func registry_id(array: ItemLibrary):
	var path = get_newest_file("res://src/data/items/tres_build/temp")
	if path == "res://src/data/items/tres_build/temp/temp.tres":
		temp_file = load(path) 
		temp_id = temp_file.temp_id
	
	
	var s = array.getArray("consumble_item")
	var z = array.getArray("block_item").duplicate()


	var size_item = s.size()
	
	
	for a in list_id.keys():
		if list_id.get(a) < size_block: continue
		if s.any(func(obj): return obj.id == a): continue
		push_error("Ошибка, данный предмет был удалён, с помощью интерфейса вручную измените. Id:{id}, Id Item:{item}".format({"id": list_id.get(a), "item": a}))
		

	
	for i in s.size():
		if list_id.get(s.get(i).id) != null: continue
		list_id.set(s.get(i).id, i + size_block)
		temp_id.set(i + size_block, s.get(i).id)

	
	var count_new = count_new_element(z)
	var without_element = without_new_element(z)
	
	
	for a in list_id.keys():
		if list_id.get(a) >= size_block: continue
		if without_element.any(func(obj): return obj.id == a): continue
		push_error("Ошибка, данный предмет был удалён, с помощью интерфейса вручную измените Id:{id}, Id Block:{block}".format({"id": list_id.get(a), "block": a}))

	if count_new.size() != 0:
		for a in count_new.size() + 1:
			if a == 0: a += 1
			list_id.set(count_new.get(a - 1).id, z.size() - count_new.size() + a - 1)
			temp_id.set(z.size() - count_new.size() + a - 1, count_new.get(a - 1).id)
		
		
	save_resource()
	
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
