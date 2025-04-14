extends Camera3D

@export var mouse_sensitivity = 0.05
@export var move_speed = 5.0
@export var fast_speed = 10.0

var _velocity = Vector3.ZERO
var _current_speed = move_speed
@export var enableCamera = false

signal enable

func handleStateChange():
	if enableCamera:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		enableCamera = false
		self.clear_current()
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		enableCamera = true
		self.make_current()

func _ready():
	enable.connect(handleStateChange)

func _input(event):
	if enableCamera:
		if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
			rotate_object_local(Vector3.RIGHT, deg_to_rad(-event.relative.y * mouse_sensitivity))
		
		if event.is_action_pressed("ui_cancel"):
			if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _process(delta):
	if enableCamera and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var input_dir = Vector3.ZERO
		
		if Input.is_action_pressed("debug_move_forward"):
			input_dir += -global_transform.basis.z
		if Input.is_action_pressed("debug_move_backward"):
			input_dir += global_transform.basis.z
		if Input.is_action_pressed("debug_move_left"):
			input_dir += -global_transform.basis.x
		if Input.is_action_pressed("debug_move_right"):
			input_dir += global_transform.basis.x
		if Input.is_action_pressed("debug_move_up"):
			input_dir += Vector3.UP
		if Input.is_action_pressed("debug_move_down"):
			input_dir += Vector3.DOWN
		
		_current_speed = fast_speed if Input.is_action_pressed("debug_move_fast") else move_speed
		
		_velocity = input_dir.normalized() * _current_speed
		global_translate(_velocity * delta)
