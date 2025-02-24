extends PanelContainer

@export var max_split: float = 10.0

var fuel = 100.0
var dv = 0.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var meter: HSplitContainer = $MarginContainer/VBoxContainer/HSplitContainer
	
	meter.split_offset = max_split * (fuel/100.0)
	
	$MarginContainer/VBoxContainer/Label.text = "Fuel: %.1f/100.0\n(Δv = %.1fm/s)" % [fuel, dv]

func _on_craft_fuel_update(fuel: float, dv: float) -> void:
	self.fuel = fuel
	self.dv = dv
