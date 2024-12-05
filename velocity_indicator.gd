extends VSplitContainer

@export var target_node: RigidBody3D
@export var max_offset: float
@export var max_vel: float

@export var shake_intensity: float = 3.0  # Maximum shake in pixels
@export var shake_speed: float = 20.0     # How fast it shakes

var initial_position: Vector2
var time: float = 0

func _ready() -> void:
	initial_position = position

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var vel = target_node.linear_velocity.length()
	var meter = vel / max_vel
	self.split_offset = max_offset - max_offset * meter
	
	$Label.text = str(snapped(vel, 0.01)) + " m/s"
	
	time += delta
	
	if(vel > max_vel):
		var diff = clamp((vel / max_vel) - 1, 0, 1)  # Clamp the difference to 0-1
		var style = $Panel2.get_theme_stylebox("panel").duplicate()  # Duplicate the style
		style.bg_color = Color("#999999").lerp(Color.RED, diff)  # Lerp between gray and red
		$Panel2.add_theme_stylebox_override("panel", style)
		
		var shake_amount = shake_intensity * diff
		position = initial_position + Vector2(
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount)
		)
	else:
		$Panel2.get_theme_stylebox("panel").bg_color = Color("#999999")
