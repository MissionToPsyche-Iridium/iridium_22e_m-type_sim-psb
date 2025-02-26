extends Node

var difficulty: int = 0
var asteroid_scale: int = 0

func _set_difficulty(n: int) -> void:
	Globals.difficulty = n

func _get_difficulty() -> int:
	return Globals.difficulty
