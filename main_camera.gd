extends Camera3D

# Camera settings
@export var min_zoom: float = 2.0
@export var max_zoom: float = 10.0
@export var zoom_speed: float = 0.5
@export var zoom_smoothing: float = 5.0

@export var orbit_speed: float = 0.5
@export var orbit_smoothing: float = 10.0

# Target to orbit around
@export var target_node: Node3D

# Internal variables
var _current_zoom: float = 5.0
var _target_zoom: float = 5.0

var _orbit_rotation: Vector2 = Vector2.ZERO
var _target_orbit_rotation: Vector2 = Vector2.ZERO

var _is_orbiting: bool = false
var _last_mouse_position: Vector2 = Vector2.ZERO

func _ready():
	# Initialize camera position
	_current_zoom = (max_zoom + min_zoom) / 2
	_target_zoom = _current_zoom

func _input(event):
	# Handle mouse wheel for zooming
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_zoom = clamp(_target_zoom - zoom_speed, min_zoom, max_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_zoom = clamp(_target_zoom + zoom_speed, min_zoom, max_zoom)
		# Handle middle mouse button for orbiting
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_is_orbiting = event.pressed
			_last_mouse_position = event.position
	
	# Handle mouse motion for orbiting
	elif event is InputEventMouseMotion and _is_orbiting:
		var delta = event.position - _last_mouse_position
		_target_orbit_rotation.x -= delta.y * orbit_speed * 0.01
		_target_orbit_rotation.y -= delta.x * orbit_speed * 0.01
		
		# Clamp vertical rotation to avoid flipping
		_target_orbit_rotation.x = clamp(_target_orbit_rotation.x, -1.5, 1.5)
		
		_last_mouse_position = event.position

func _process(delta):
	if not target_node:
		return
		
	# Smooth zoom
	_current_zoom = lerp(_current_zoom, _target_zoom, delta * zoom_smoothing)
	
	# Smooth orbit rotation
	_orbit_rotation = _orbit_rotation.lerp(_target_orbit_rotation, delta * orbit_smoothing)
	
	# Calculate new camera position
	var target_pos = target_node.global_position
	
	# Create rotation transform
	var rotation_transform = Transform3D()
	rotation_transform = rotation_transform.rotated(Vector3.RIGHT, _orbit_rotation.x)
	rotation_transform = rotation_transform.rotated(Vector3.UP, _orbit_rotation.y)
	
	# Calculate camera position based on rotation and zoom
	var camera_pos = rotation_transform.basis * Vector3(0, 0, _current_zoom)
	
	# Update camera transform
	global_transform = Transform3D(rotation_transform.basis, target_pos + camera_pos)
	look_at(target_pos)
