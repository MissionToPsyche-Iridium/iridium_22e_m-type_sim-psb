extends Node


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$PauseMenu.visible = false
	process_mode = PROCESS_MODE_ALWAYS

func toggle_pause() -> void:
	$PauseMenu.visible = !$PauseMenu.visible
	get_tree().paused = $PauseMenu.visible
	PhysicsServer3D.set_active(!$PauseMenu.visible)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("pause"):
		toggle_pause()

func _on_exit_pressed() -> void:
	toggle_pause()
	get_tree().change_scene_to_file("res://scene/title.tscn")

func _on_resume_pressed() -> void:
	toggle_pause()
