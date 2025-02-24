extends Control

@onready var prograde_button: Button = $MarginContainer/VBoxContainer/Prograde
@onready var retrograde_button: Button = $MarginContainer/VBoxContainer/Retrograde
@onready var radial_out_button: Button = $MarginContainer/VBoxContainer/RadialOut
@onready var stabilize_button: Button = $MarginContainer/VBoxContainer/Stabilize
@onready var craft: Node3D = $"../Craft"

func _ready() -> void:
	prograde_button.pressed.connect(func(): craft.setAlignTarget("prograde"))
	retrograde_button.pressed.connect(func(): craft.setAlignTarget("retrograde"))
	radial_out_button.pressed.connect(func(): craft.setAlignTarget("radial_out"))
	stabilize_button.pressed.connect(func(): craft.setAlignTarget("stabilize"))

	craft.alignTargetChanged.connect(handle_align_target_change)

func handle_align_target_change(new_val: String) -> void:
	prograde_button.button_pressed = false
	retrograde_button.button_pressed = false
	radial_out_button.button_pressed = false
	stabilize_button.button_pressed = false

	match new_val:
		"prograde":
			prograde_button.button_pressed = true
		"retrograde":
			retrograde_button.button_pressed = true
		"radial_out":
			radial_out_button.button_pressed = true
		"stabilize":
			stabilize_button.button_pressed = true
