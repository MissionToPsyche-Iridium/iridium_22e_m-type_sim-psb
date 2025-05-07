extends Button
@onready var disclaimerBox = $"../../../PsycheDisclaimer"
@onready var creditsBox = $"../../../Credits"

func _on_pressed() -> void:
	disclaimerBox.visible = !disclaimerBox.visible
	creditsBox.visible = false


func _on_credits_pressed() -> void:
	creditsBox.visible = !creditsBox.visible
	disclaimerBox.visible = false
