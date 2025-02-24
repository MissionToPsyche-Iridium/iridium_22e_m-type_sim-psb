extends Node

func _ready() -> void:
	$Settings/Difficulty/Option.selected = Globals.difficulty

func _on_exit_pressed() -> void:
	get_tree().quit()

func _on_play_pressed():
	get_tree().change_scene_to_file("res://scene/game.tscn")# Replace with function body.
	
func _on_settings_pressed() -> void:
	$Settings.visible = true
	$Title.visible = false

func _on_settings_back_pressed() -> void:
	$Settings.visible = false
	$Title.visible = true

func _on_difficulty_selected(index: int) -> void:
	Globals.difficulty = index
