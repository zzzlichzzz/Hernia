class_name DropsModule extends BlockModule

@export var drop_item: String = "Dirt"
@export var amount: int = 1

func on_break(block, by):
	print("[DropsModule]: Dropped", drop_item, "x", amount)
	# Позже здесь будет генерация предметов в мир
