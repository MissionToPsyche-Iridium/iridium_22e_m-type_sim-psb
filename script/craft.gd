extends RigidBody3D

@export var lateralThrust: float = 2
@export var lateralUpwardThrust: float = 3
@export var angularThrust: float = 20
@export var gravity: float = 0.06

@export_range(0.0, 100.0) var fuel = 100.0
@export var fuelConsumption: float = 0.1 # fuel:dv ratio

@export var stopping_angle: float = 5  # Degrees threshold
@export var stopping_velocity: float = 0.1  # Angular velocity threshold

@export var do_silly_explosion: bool = true

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
	fuelConsumption = 0.05 * (Globals.difficulty+1)
	crash_acceleration = 10 + 2*(2 - Globals.difficulty)

var explosion_time = 0.0
var explosion_frames = 0

@onready var navball = $"../Camera3D/Navball"
@onready var navball_prograde = $"../Camera3D/Navball/Prograde"
# @onready var navball_retrograde = $"../Camera3D/Navball/Retrograde"
# @onready var navball_radial_in = $"../Camera3D/Navball/RadialIn"
# @onready var navball_radial_out = $"../Camera3D/Navball/RadialOut"
# @onready var navball_normal = $"../Camera3D/Navball/Normal"
# @onready var navball_antinormal = $"../Camera3D/Navball/Antinormal"


func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	
	if lock_controls and explosion_frames < 16 and do_silly_explosion:
		explosion_time += delta
		if explosion_time >= (1.0/15.0):
			$explosion.frame = (8 + explosion_frames) % 16
			explosion_frames += 1
			explosion_time = 0
	
	if explosion_frames >= 16:
		$explosion.visible = false
	
	self.apply_force(-self.position.normalized() * 0.06)
	
	# Create a proper reference frame for the navball
	# Origin is at planet center, Y is "up" (radial out from craft's position)
	var up_direction = position.normalized()
	# Choose any perpendicular vector for forward reference (north)
	var forward_ref = Vector3.FORWARD
	if abs(up_direction.dot(forward_ref)) > 0.9:
		forward_ref = Vector3.RIGHT  # Use alternate reference if too close to up
	var right_direction = up_direction.cross(forward_ref).normalized()
	var forward_direction = right_direction.cross(up_direction).normalized()
	
	# Create reference frame basis
	var reference_basis = Basis(right_direction, up_direction, forward_direction)
	
	# Set navball to show craft orientation relative to this reference frame
	navball.basis = reference_basis.inverse() * global_transform.basis
	
	# Update navball prograde marker
	if linear_velocity.length() > 0.01:
		# Convert velocity to reference frame coordinates
		var velocity_in_reference = reference_basis.inverse() * linear_velocity.normalized()
		# Set prograde marker rotation to point in velocity direction
		navball_prograde.basis = Basis.looking_at(velocity_in_reference, Vector3.UP)
		navball_prograde.visible = true
	else:
		navball_prograde.visible = false
	
	if (linear_velocity - prev_velocity).length() > crash_acceleration:
		lock_controls = true
		$"../FailDialog".visible = true
		if do_silly_explosion:
			$explosion.visible = true
		$model.visible = false
		crash.emit()
	
	if lock_controls:
		return

	var lateralAccel = Vector3.ZERO
	
	if Input.is_action_pressed("craft_lateral_up"):
		lateralAccel += transform.basis.y * (lateralUpwardThrust)
	if Input.is_action_pressed("craft_lateral_down"):
		lateralAccel += -transform.basis.y * (lateralUpwardThrust)
	if Input.is_action_pressed("craft_lateral_forward"):
		lateralAccel += transform.basis.z * (lateralThrust)
	if Input.is_action_pressed("craft_lateral_backward"):
		lateralAccel += -transform.basis.z * (lateralThrust)
	if Input.is_action_pressed("craft_lateral_left"):
		lateralAccel += transform.basis.x * (lateralThrust)
	if Input.is_action_pressed("craft_lateral_right"):
		lateralAccel += -transform.basis.x * (lateralThrust)
	if Input.is_action_pressed("craft_lateral_cancel"):
		lateralAccel += -linear_velocity * (lateralThrust)
	
	var angularAccel = Vector3.ZERO
	
	if Input.is_action_pressed("craft_angular_roll_cw"):
		angularAccel += -transform.basis.y * (angularThrust)
	if Input.is_action_pressed("craft_angular_roll_ccw"):
		angularAccel += transform.basis.y * (angularThrust)
	if Input.is_action_pressed("craft_angular_forward"):
		angularAccel += transform.basis.x * (angularThrust)
	if Input.is_action_pressed("craft_angular_backward"):
		angularAccel += -transform.basis.x * (angularThrust)
	if Input.is_action_pressed("craft_angular_left"):
		angularAccel += -transform.basis.z * (angularThrust)
	if Input.is_action_pressed("craft_angular_right"):
		angularAccel += transform.basis.z * (angularThrust)
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

	var consumption = fuelConsumption * (lateralAccel.length() + angularAccel.length()*0.2) * delta
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
