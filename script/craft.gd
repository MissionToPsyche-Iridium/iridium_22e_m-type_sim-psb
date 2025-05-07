extends RigidBody3D

@export var lateralThrust: float = 2
@export var lateralUpwardThrust: float = 3
@export var angularThrust: float = 20
@export var gravity: float = 0.06

@export_range(0.0, 100.0) var fuel = 100.0
@export var fuelConsumption: float = 0.1 # fuel:dv ratio

@export var stopping_angle: float = 0.5  # Degrees threshold
@export var stopping_velocity: float = 0.1  # Angular velocity threshold

@export var do_silly_explosion: bool = true

var crash_acceleration: float = 10
var has_exploded: bool = false  # Add this flag to prevent multiple explosions

signal fuelUpdate(fuel: float, dv: float)
signal alignTargetChanged(new_val: String)
signal crash()
var alignTarget: String = "none"
var alignTargetStabilize: Vector3 = Vector3.ZERO

var integral: Vector3 = Vector3.ZERO
var prev_error: Vector3 = Vector3.ZERO

var prev_velocity: Vector3 = Vector3.ZERO
@export var lock_controls: bool = false

func _ready() -> void:
	fuelConsumption = 0.05 * (Globals.difficulty+1)
	crash_acceleration = 10 + 2*(2 - Globals.difficulty)

var explosion_time = 0.0
var explosion_frames = 0

var animation_duration = 9.0
@export var animation_time = 0.0
@export var animation_direction = 0
var animation_on_finish: Callable
var animation_on_fail: Callable

@onready var navball = $"../Camera3D/Navball"
@onready var navball_prograde = $"../Camera3D/Navball/Prograde"
# @onready var navball_radial_in = $"../Camera3D/Navball/RadialIn"
# @onready var navball_normal = $"../Camera3D/Navball/Normal"

@onready var RCSForward: Array[GPUParticles3D] = [$"RCS/Back/Top/Back", $"RCS/Back/Bottom/Back"]
@onready var RCSBackward: Array[GPUParticles3D] = [$"RCS/Front/Top/Back", $"RCS/Front/Bottom/Back"]
@onready var RCSLeft: Array[GPUParticles3D] = [$"RCS/Back/Top/Right", $"RCS/Back/Bottom/Right", $"RCS/Front/Top/Left", $"RCS/Front/Bottom/Left"]
@onready var RCSRight: Array[GPUParticles3D] = [$"RCS/Back/Top/Left", $"RCS/Back/Bottom/Left", $"RCS/Front/Top/Right", $"RCS/Front/Bottom/Right"]
@onready var RCSUp: Array[GPUParticles3D] = [$"RCS/Back/Bottom/Down", $"RCS/Front/Bottom/Down"]
@onready var RCSDown: Array[GPUParticles3D] = [$"RCS/Back/Top/Up", $"RCS/Front/Top/Up"]

@onready var RCSRollRight: Array[GPUParticles3D] = [$"RCS/Back/Top/Right", $"RCS/Front/Top/Right", $"RCS/Back/Bottom/Left", $"RCS/Front/Bottom/Left"]
@onready var RCSRollLeft: Array[GPUParticles3D] = [$"RCS/Back/Top/Left", $"RCS/Front/Top/Left", $"RCS/Back/Bottom/Right", $"RCS/Front/Bottom/Right"]
@onready var RCSYawRight: Array[GPUParticles3D] = [$"RCS/Back/Top/Right", $"RCS/Back/Bottom/Right", $"RCS/Front/Top/Right", $"RCS/Front/Bottom/Right"]
@onready var RCSYawLeft: Array[GPUParticles3D] = [$"RCS/Back/Top/Left", $"RCS/Back/Bottom/Left", $"RCS/Front/Top/Left", $"RCS/Front/Bottom/Left"]
@onready var RCSPitchDown: Array[GPUParticles3D] = [$"RCS/Back/Top/Up", $"RCS/Front/Bottom/Down"]
@onready var RCSPitchUp: Array[GPUParticles3D] = [$"RCS/Back/Bottom/Down", $"RCS/Front/Top/Up"]

func adjustRCSAnimation(lateralAccel: Vector3, angularAccel: Vector3) -> void:
	lateralAccel = transform.basis.inverse() * lateralAccel
	var forward = max(0, lateralAccel.z) / lateralThrust
	var backward = max(0, -lateralAccel.z) / lateralThrust
	var left = max(0, lateralAccel.x) / lateralThrust
	var right = max(0, -lateralAccel.x) / lateralThrust
	var up = max(0, lateralAccel.y) / lateralUpwardThrust
	var down = max(0, -lateralAccel.y) / lateralUpwardThrust
	
	for i in range(RCSForward.size()):
		RCSForward[i].amount_ratio = forward
	for i in range(RCSBackward.size()):
		RCSBackward[i].amount_ratio = backward
	for i in range(RCSLeft.size()):
		RCSLeft[i].amount_ratio = left
	for i in range(RCSRight.size()):
		RCSRight[i].amount_ratio = right
	for i in range(RCSUp.size()):
		RCSUp[i].amount_ratio = up
	for i in range(RCSDown.size()):
		RCSDown[i].amount_ratio = down
	
	angularAccel = transform.basis.inverse() * angularAccel
	var pitchUp = max(0, angularAccel.x) / angularThrust
	var pitchDown = max(0, -angularAccel.x) / angularThrust
	var yawLeft = max(0, angularAccel.y) / angularThrust
	var yawRight = max(0, -angularAccel.y) / angularThrust
	var rollLeft = max(0, angularAccel.z) / angularThrust
	var rollRight = max(0, -angularAccel.z) / angularThrust

	for i in range(RCSRollLeft.size()):
		RCSRollLeft[i].amount_ratio += rollLeft
	for i in range(RCSRollRight.size()):
		RCSRollRight[i].amount_ratio += rollRight
	for i in range(RCSYawLeft.size()):
		RCSYawLeft[i].amount_ratio += yawLeft
	for i in range(RCSYawRight.size()):
		RCSYawRight[i].amount_ratio += yawRight
	for i in range(RCSPitchUp.size()):
		RCSPitchUp[i].amount_ratio += pitchUp
	for i in range(RCSPitchDown.size()):
		RCSPitchDown[i].amount_ratio += pitchDown


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
		
	navball.basis = transform.basis

	if linear_velocity.length() > 0.01:
		var global_vel_dir = linear_velocity.normalized()
		var craft_local_vel_dir = transform.basis.inverse() * global_vel_dir
		
		navball_prograde.basis = Basis.looking_at(craft_local_vel_dir)
		navball_prograde.visible = true
	else:
		navball_prograde.visible = false
	
	if (linear_velocity - prev_velocity).length() > crash_acceleration:
		lock_controls = true
		$"../FailDialog".visible = true
		
		if do_silly_explosion and not has_exploded:
			has_exploded = true
			$explosion.visible = true
			$model.visible = false
			create_explosion_parts()
		
		crash.emit()
	
	if lock_controls:
		navball.get_parent_node_3d().visible = false
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
	
	# Determine target alignment vector based on current mode
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
		# Normal is perpendicular to velocity and position vectors
		if linear_velocity.length() > 0.01:
			alignVector = linear_velocity.cross(position).normalized()
		else:
			alignTarget = "none"
			alignTargetChanged.emit(alignTarget)
	elif alignTarget == "antinormal":
		# Antinormal is opposite of normal
		if linear_velocity.length() > 0.01:
			alignVector = -linear_velocity.cross(position).normalized()
		else:
			alignTarget = "none"
			alignTargetChanged.emit(alignTarget)
	elif alignTarget == "stabilize":
		# Just dampen rotation without changing orientation
		angularAccel = -angular_velocity * angularThrust
		if angular_velocity.length() < stopping_velocity:
			angular_velocity = Vector3.ZERO
			alignTarget = "none"
			alignTargetChanged.emit(alignTarget)

	# PID controller constants
	const Kp = 2.0  # Proportional gain
	const Kd = 1.0  # Derivative gain
	const MAX_ANGLE_ERROR = PI  # Maximum angle for proportional scaling

	# If we have a valid alignment target
	if alignVector != Vector3.ZERO and alignTarget != "stabilize":
		# Calculate desired direction and current direction
		var target_dir = alignVector.normalized()
		var current_dir = transform.basis.y.normalized()
		
		# Calculate the rotation axis and angle to align current with target
		var cross_product = current_dir.cross(target_dir)
		var dot_product = current_dir.dot(target_dir)
		
		# Clamp dot product to valid range (-1 to 1)
		dot_product = clamp(dot_product, -1.0, 1.0)
		
		# Angle between the vectors
		var angle = acos(dot_product)
		
		# If angle is small enough, we're aligned
		if angle < deg_to_rad(stopping_angle):
			angular_velocity = Vector3.ZERO
			alignTarget = "none"
			alignTargetChanged.emit(alignTarget)
		else:
			# Calculate rotation axis (normalized cross product)
			var rotation_axis = Vector3.ZERO
			if cross_product.length_squared() > 0.000001:
				rotation_axis = cross_product.normalized()
			
			# If we have a valid rotation axis
			if rotation_axis != Vector3.ZERO:
				# Calculate proportional term - scales with angle
				var p_term = rotation_axis * angle
				
				# Calculate derivative term - dampen angular velocity
				var d_term = -angular_velocity
				
				# Combine terms with weights
				angularAccel = (Kp * p_term + Kd * d_term) * angularThrust
				
				# Limit the maximum torque
				if angularAccel.length() > angularThrust:
					angularAccel = angularAccel.normalized() * angularThrust

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

	self.adjustRCSAnimation(lateralAccel, angularAccel)
	
	prev_velocity = linear_velocity

	updateAnimation(delta)

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

# Function to handle creating explosion parts
func create_explosion_parts() -> void:
	# Get the parent node that contains the craft
	var parent_node = get_parent()
	
	# Create exploding parts from the model's children
	var part_count = 0  # Limit number of parts for safety
	for child in $model.get_children():
		# Safety limit to prevent too many parts
		if part_count > 20:
			break
			
		# Skip non-visible or non-geometry nodes
		if not (child is MeshInstance3D or child is Node3D) or not child.visible:
			continue
		
		part_count += 1
		
		# Create a new RigidBody3D for this part
		var part_body = RigidBody3D.new()
		
		# Add to the parent node (same level as the craft)
		parent_node.add_child(part_body)
		
		# Set the position to match the child's global position by applying transforms
		# First get the child's position relative to model
		var child_transform = $model.transform * child.transform
		
		# Set the part_body's transform based on craft's transform
		part_body.transform = transform * child_transform
		
		# Make a copy of the child node
		var part = child.duplicate()
		part.visible = true
		# part.scale *= 0.25
		part.position = Vector3.ZERO
		
		# Add the part as a child of the RigidBody with identity transform
		# We need to reset the transform since we already positioned the RigidBody correctly
		# part.transform = Transform3D.IDENTITY
		part_body.add_child(part)
		
		part_body.linear_velocity = linear_velocity
		
		# Set collision properties
		var collision = CollisionShape3D.new()
		
		# Use box shape with appropriate size based on the part's scale
		var shape = SphereShape3D.new()
		
		shape.radius = 0.05
		collision.shape = shape
		part_body.add_child(collision)
		
		# Set mass to be relatively light
		part_body.mass = 10
		
		if part_count == 1:
			$"../Camera3D".target_node = part_body

func startAnimation(on_finish: Callable, on_fail: Callable) -> void:
	animation_direction = 1
	animation_time = 0
	animation_duration = 10
	animation_on_finish = on_finish
	animation_on_fail = on_fail
	
func updateAnimation(delta: float) -> void:
	if animation_time >= animation_duration:
		animation_direction = -1
		animation_on_finish.call()
	elif animation_time < 0:
		animation_direction = 0
		animation_time = 0
	
	if animation_direction > 0 and linear_velocity.length() > 0.15:
		animation_on_fail.call()
		animation_direction = -10
	
	var drill_angle = -(3.14/2.0) * (1 - min(1, animation_time / 3.0))
	if animation_time > 3.0:
		var extension_time = animation_time - 3.0
		var drill_extension = 0.85 * (1 - min(1, extension_time / 6.0))
		$"model/Drill/Drill Bit".position.y = drill_extension
		$"model/Drill/Drill Bit".rotation.y += 100 * delta
	
	$"model/Drill".rotation.x = drill_angle
	
	animation_time += animation_direction * delta
	
	
