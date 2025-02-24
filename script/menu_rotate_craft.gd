extends RigidBody3D

@export var max = 1.0

var rng = RandomNumberGenerator.new()
var spin: Vector3
func _ready() -> void:
	spin = Vector3(
		rng.randf_range(0, max),
		rng.randf_range(0, max),
		rng.randf_range(0, max)
	)
	self.gravity_scale = 0.0
	self.angular_damp = 0.0


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	self.angular_velocity = spin
