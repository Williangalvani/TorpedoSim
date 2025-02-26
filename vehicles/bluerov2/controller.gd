extends RigidBody3D

# BlueROV2 Controller
# This file should contain all BLUEROV2-specific logic.
# That includes processing the servo outputs into thrusters, applying custom physics,
# and handling peripherals, such as the camera lights, and gripper

@export var THRUSTER_FORCE = 2

# last servo values received from the server
var servos = []

func _ready():
  # initialize servos to neutral
	for i in range(8):
		servos.append(0.5)

func add_force_local(force: Vector3, pos: Vector3):
	var pos_local = self.transform.basis * pos
	var force_local = self.transform.basis * force
	self.apply_force(force_local, pos_local)

func is_in_water() -> bool:
	return self.global_position.y < 0

func apply_buoyancy() -> void:
	if self.is_in_water():
		var buoyancy_force = Vector3.UP * 9.81 * (self.mass *1.01)
		self.apply_force(buoyancy_force, self.transform.basis * $buoyancy.position)

func actuate_servos(values: Array[float]):
  # update the last servo values received from the server
  # called when we get a new servo message from the server
	servos = values

func set_thrusters():
  # apply the last servo values received from the server to the thrusters
  # called on every physics update
	for i in range(8):
		actuate_servo(i, servos[i])

func actuate_servo(id, percentage):
  # translantes the percentage into a force, and applies it to the thruster
  # called on every physics update
	if percentage == 0:
		return

	var force = percentage * -THRUSTER_FORCE
	match id:
		0:
			self.add_force_local($t1.transform.basis*Vector3(0,0,force), $t1.position)
		1:
			self.add_force_local($t2.transform.basis*Vector3(0,0,force), $t2.position)
		2:
			self.add_force_local($t3.transform.basis*Vector3(0,0,force), $t3.position)
		3:
			self.add_force_local($t4.transform.basis*Vector3(0,0,force), $t4.position)
		4:
			self.add_force_local($t5.transform.basis*Vector3(0,0,force), $t5.position)
		5:
			self.add_force_local($t6.transform.basis*Vector3(0,0,force), $t6.position)
		6:
			self.add_force_local($t7.transform.basis*Vector3(0,0,force), $t7.position)
		7:
			self.add_force_local($t8.transform.basis*Vector3(0,0,force), $t8.position)
		8:
			$Camera.rotation_degrees.x = -45 + 90 * percentage
		#9:
			#percentage -= 0.1
			#$light1.light_energy = percentage * 5
			#$light2.light_energy = percentage * 5
			#$light3.light_energy = percentage * 5
			#$light4.light_energy = percentage * 5
			#$scatterlight.light_energy = percentage * 2.5
			#if percentage < 0.01 and light_glows[0].get_parent() != null:
				#for light in light_glows:
					#self.remove_child(light)
			#elif percentage > 0.01 and light_glows[0].get_parent() == null:
				#for light in light_glows:
					#self.add_child(light)
#
		#10:
			#if percentage < 0.4:
				#ljoint.set_param(6, 1)
				#rjoint.set_param(6, -1)
			#elif percentage > 0.6:
				#ljoint.set_param(6, -1)
				#rjoint.set_param(6, 1)
			#else:
				#ljoint.set_param(6, 0)
				#rjoint.set_param(6, 0)


func _unhandled_input(event):
  # handle keyboard input for debugging
	var thrust = 30
	if event is InputEventKey:
		# There are for debugging:
		# Some forces:
		if event.pressed and event.keycode == KEY_X:
			self.apply_central_force(Vector3(30, 0, 0))
		if event.pressed and event.keycode == KEY_Y:
			self.apply_central_force(Vector3(0, 30, 0))
		if event.pressed and event.keycode == KEY_Z:
			self.apply_central_force(Vector3(0, 0, 30))
		# Reset position
		if event.pressed and event.keycode == KEY_R:
			self.set_position(Vector3(0, 0, 0))
		# Some torques
		if event.pressed and event.keycode == KEY_Q:
			self.apply_torque(self.transform.basis * Vector3(0, 10, 0))
		if event.pressed and event.keycode == KEY_E:
			self.apply_torque(self.transform.basis * Vector3(0, -10, 0))
		# Some hard-coded positions (used to check accelerometer)
		if event.pressed and event.keycode == KEY_W:
			self.apply_central_force(transform.basis * Vector3(0, 0, thrust))
		if event.pressed and event.keycode == KEY_S:
			self.apply_central_force(transform.basis * Vector3(0, 0, -thrust))
		if event.pressed and event.keycode == KEY_A:
			self.apply_central_force(transform.basis * Vector3(thrust, 0, 0))
		if event.pressed and event.keycode == KEY_D:
			self.apply_central_force(transform.basis * Vector3(-thrust, 0, 0))
		if event.pressed and event.keycode == KEY_SPACE:
			self.apply_central_force(Vector3(0, thrust, 00))
		if event.pressed and event.keycode == KEY_C:
			self.apply_central_force(Vector3(0, -thrust, 0))
	

func _physics_process(_delta: float) -> void:
	self.set_thrusters()
	self.apply_buoyancy()
