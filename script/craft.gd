extends RigidBody3D

@export var lateralThrust: float = 2
@export var lateralUpwardThrust: float = 3
@export var angularThrust: float = 20
@export var gravity: float = 0.06

@export_range(0.0, 100.0) var fuel = 100.0
@export var fuelConsumption: float = 0.1 # fuel:dv ratio

@export var stopping_angle: float = 5  # Degrees threshold
@export var stopping_velocity: float = 0.1  # Angular velocity threshold

var crash_acceleration: float = 10

signal fuelUpdate(fuel: float, dv: float)
signal alignTargetChanged(new_val: String)
signal crash()
var alignTarget: String = "none"
var alignTargetStabilize: Vector3 = Vector3.ZERO

var integral: Vector3 = Vector3.ZERO
var prev_error: Vector3 = Vector3.ZERO

var prev_velocity: Vector3 = Vector3.ZERO
var lock_controls: bool = false

func _ready() -> void:
	fuelConsumption = 0.1 * (Globals.difficulty+1)

func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	
	self.apply_force(-self.position.normalized() * 0.06)
	
	if (linear_velocity - prev_velocity).length() > crash_acceleration:
		lock_controls = true
		$"../SamplePopup".visible = true
		$"../SamplePopup/MarginContainer/VBoxContainer/Label".text = "Crashed!"
		$"../SamplePopup/MarginContainer/VBoxContainer/Label2".text = "You have damaged the craft, and can no longer control it."
		crash.emit()
	
	if lock_controls:
		return

	var lateralAccel = Vector3.ZERO
	
	if Input.is_action_pressed("craft_lateral_up"):
		lateralAccel += transform.basis.y * (lateralUpwardThrust)
	if Input.is_action_pressed("craft_lateral_down"):
		lateralAccel += -transform.basis.y * (lateralUpwardThrust)
	if Input.is_action_pressed("craft_lateral_forward"):
		lateralAccel += -transform.basis.x * (lateralThrust)
	if Input.is_action_pressed("craft_lateral_backward"):
		lateralAccel += transform.basis.x * (lateralThrust)
	if Input.is_action_pressed("craft_lateral_left"):
		lateralAccel += transform.basis.z * (lateralThrust)
	if Input.is_action_pressed("craft_lateral_right"):
		lateralAccel += -transform.basis.z * (lateralThrust)
	if Input.is_action_pressed("craft_lateral_cancel"):
		lateralAccel += -linear_velocity * (lateralThrust)
	
	var angularAccel = Vector3.ZERO
	
	if Input.is_action_pressed("craft_angular_roll_cw"):
		angularAccel += -transform.basis.y * (angularThrust)
	if Input.is_action_pressed("craft_angular_roll_ccw"):
		angularAccel += transform.basis.y * (angularThrust)
	if Input.is_action_pressed("craft_angular_forward"):
		angularAccel += transform.basis.z * (angularThrust)
	if Input.is_action_pressed("craft_angular_backward"):
		angularAccel += -transform.basis.z * (angularThrust)
	if Input.is_action_pressed("craft_angular_left"):
		angularAccel += transform.basis.x * (angularThrust)
	if Input.is_action_pressed("craft_angular_right"):
		angularAccel += -transform.basis.x * (angularThrust)
	if Input.is_action_pressed("craft_angular_cancel"):
		angularAccel += -angular_velocity * (angularThrust)
	
	# if the user is applying angular thrust, we need to interrupt the alignment
	if angularAccel != Vector3.ZERO:
		alignTarget = "none"
		alignTargetChanged.emit(alignTarget)
	
	var alignVector = Vector3.ZERO
	if alignTarget == "prograde":
		alignVector = linear_velocity.normalized()
	elif alignTarget == "retrograde":
		alignVector = -linear_velocity.normalized()
	elif alignTarget == "radial_in":
		alignVector = -position.normalized()
	elif alignTarget == "radial_out":
		alignVector = position.normalized()
	elif alignTarget == "normal":
		alignVector = transform.basis.y.normalized()
	elif alignTarget == "antinormal":
		alignVector = -transform.basis.y.normalized()
	elif alignTarget == "stabilize":
		angularAccel = -angular_velocity.normalized() * angularThrust
		if angularAccel.length() < stopping_velocity:
			alignTarget = "none"
			angularAccel = Vector3.ZERO
			alignTargetChanged.emit(alignTarget)

	const Kp = 0.8
	const Ki = 0.5
	const Kd = 0.5
	const deadzone_deg = 0.1

	if alignVector != Vector3.ZERO:
		var target = alignVector.normalized()
		var current = transform.basis.y.normalized()

		var cos_angle = current.dot(target)
		var angle = acos(clamp(cos_angle, -1.0, 1.0))
		if angle < deg_to_rad(deadzone_deg):
			integral = Vector3.ZERO
			prev_error = Vector3.ZERO
		else:
			var error = current.cross(target)
			error = error * (1.0 + angle / deg_to_rad(deadzone_deg))

			var velocity_damping = -Kd * angular_velocity

			integral += error * delta

			var P = Kp * error
			var I = Ki * integral
			var accel = P + I + velocity_damping
			
			if angle < deg_to_rad(stopping_angle):
				angular_velocity = Vector3.ZERO
				alignTarget = "none"
				alignTargetChanged.emit(alignTarget)

			angularAccel = accel.limit_length(angularThrust)
	else:
		integral = Vector3.ZERO
		prev_error = Vector3.ZERO

	var consumption = fuelConsumption * (lateralAccel.length() + angularAccel.length()) * delta
	if(fuel - consumption < 0):
		var amt = fuel / consumption
		lateralAccel *= amt
		angularAccel *= amt
		fuel = 0
	else:
		fuel -= consumption
	
	fuelUpdate.emit(fuel, fuel / fuelConsumption)
	
	self.apply_force(mass * lateralAccel)
	self.apply_torque(mass * angularAccel)
	
	if popUpTime > 0:
		popUpTime -= delta
		$"../SamplePopup".visible = true
	else:
		$"../SamplePopup".visible = false
	
	prev_velocity = linear_velocity


func setAlignTarget(new_val: String) -> void:
	if new_val == "stabilize":
		alignTargetStabilize = transform.basis.y.normalized()
		alignTarget = "stabilize"
	elif alignTarget == new_val:
		alignTarget = "none"
	else:
		alignTarget = new_val
		alignTargetChanged.emit(alignTarget)

var popUpTime = 0.0

func _on_sample_button_pressed() -> void:
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		global_position,                    # from
		global_position + Vector3.DOWN * 2,  # to (10 units down)
		collision_mask,                     # collision mask (optional)
		[self]                             # array of objects to exclude
	)
	var result = space_state.intersect_ray(query)
	
	if result and (linear_velocity + angular_velocity).length() < 0.05: 
		popUpTime = 5
