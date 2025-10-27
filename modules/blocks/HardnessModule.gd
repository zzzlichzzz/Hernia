extends BlockModule

@export var hardness_multiplier: float = 1.0

# Внешние системы вызывают этот метод
func attempt_break(block, tool_data = {}):
	# tool_data может быть наподобие: {"efficiency":2.0}
	var effective_hardness = block.hardness * hardness_multiplier

	if tool_data.has("efficiency"):
		effective_hardness /= tool_data.efficiency

	if effective_hardness <= 1.0:
		block.break_block(tool_data)
	else:
		print("[Hardness]: Too hard. Effective hardness:", effective_hardness)
