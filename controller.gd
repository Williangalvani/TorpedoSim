extends RigidBody3D

@onready var _player_pcam: PhantomCamera3D

@export var mouse_sensitivity: float = 0.05

@export var min_pitch: float = -89.9
@export var max_pitch: float = 50

@export var min_yaw: float = 0
@export var max_yaw: float = 360

@export var THRUSTER_FORCE: float = 20
var current_thrust: float = 0

@export var upright_force: float = 1

@onready var thrusteranimation: AnimationPlayer
@onready var bubbles: GPUParticles3D

func _ready() -> void:
	thrusteranimation = $bodymesh/AnimationPlayer
	_player_pcam = %PlayerPhantomCamera3D
	bubbles = $bubble_generator
	if _player_pcam.get_follow_mode() == _player_pcam.FollowMode.THIRD_PERSON:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	#thrusteranimation = $fishy.AnimationPlayer

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	if event.is_action_pressed("ui_accept"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	if _player_pcam.get_follow_mode() == _player_pcam.FollowMode.THIRD_PERSON:
		_set_pcam_rotation(_player_pcam, event)

	if event.is_action_pressed("thrust_up"):
		bubbles.amount_ratio = 1.0
		bubbles.process_material.direction = Vector3(0,0,-1)
		current_thrust = THRUSTER_FORCE
		thrusteranimation.play("spinprops", -1, 2)
	elif event.is_action_pressed("thrust_down"):
		current_thrust = -THRUSTER_FORCE
		bubbles.amount_ratio = 1.0
		bubbles.process_material.direction = Vector3(0,0,1)
		thrusteranimation.play("spinprops", -1, -2)
	elif event.is_action_released("thrust_up") or event.is_action_released("thrust_down"):
		current_thrust = 0
		bubbles.amount_ratio = 0.0
		thrusteranimation.stop()


func _process_logic() -> void:
	pass

func turn_to_camera_direction() -> void:
	# Get desired forward direction from camera
	var camera_forward = -_player_pcam.global_transform.basis.z.normalized()
	
	# Calculate rotation between current forward and desired forward
	var current_forward = global_transform.basis.z.normalized()
	var rotation_axis = current_forward.cross(camera_forward).normalized()
	
	# Only rotate if we have a valid axis
	if rotation_axis.is_normalized():
		# Calculate angle between vectors (in radians)
		var angle = acos(current_forward.dot(camera_forward))
		
		# Apply torque proportional to angle and mass
		var torque_strength = angle * mass * 5.0  # Adjust multiplier as needed
		apply_torque(rotation_axis * torque_strength)
		
		# Add angular damping to prevent overshooting
		angular_velocity *= 0.95  # Adjust damping factor as needed

func is_in_water() -> bool:
	return self.global_position.y < 0

func apply_buoyancy() -> void:
	if self.is_in_water():
		var buoyancy_force = Vector3.UP * 9.81 * self.mass * 0.8
		self.apply_central_force(buoyancy_force)

func apply_thrust() -> void:
	if self.is_in_water():
		var thrust_force = self.global_transform.basis.z * current_thrust
		self.apply_central_force(thrust_force)

func apply_keep_upright() -> void:
	# Get current up direction and desired up (world up)
	var current_up = global_transform.basis.y
	var desired_up = Vector3.UP
	
	# Calculate rotation needed to align current up with desired up
	var rotation_axis = current_up.cross(desired_up).normalized()
	
	if rotation_axis.is_normalized():
		# Apply corrective torque
		var angle = acos(current_up.dot(desired_up))
		var torque_strength = angle * mass * upright_force
		apply_torque(rotation_axis * torque_strength)
		
		# Add angular damping
		angular_velocity *= 0.98

func _physics_process(_delta: float) -> void:
	self.apply_buoyancy()
	self.turn_to_camera_direction()
	self.apply_thrust()
	self.apply_keep_upright()

func _set_pcam_rotation(pcam: PhantomCamera3D, event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var pcam_rotation_degrees: Vector3

		# Assigns the current 3D rotation of the SpringArm3D node - so it starts off where it is in the editor
		pcam_rotation_degrees = pcam.get_third_person_rotation_degrees()

		# Change the X rotation
		pcam_rotation_degrees.x -= event.relative.y * mouse_sensitivity

		# Clamp the rotation in the X axis so it go over or under the target
		pcam_rotation_degrees.x = clampf(pcam_rotation_degrees.x, min_pitch, max_pitch)

		# Change the Y rotation value
		pcam_rotation_degrees.y -= event.relative.x * mouse_sensitivity

		# Sets the rotation to fully loop around its target, but witout going below or exceeding 0 and 360 degrees respectively
		pcam_rotation_degrees.y = wrapf(pcam_rotation_degrees.y, min_yaw, max_yaw)

		# Change the SpringArm3D node's rotation and rotate around its target
		pcam.set_third_person_rotation_degrees(pcam_rotation_degrees)
