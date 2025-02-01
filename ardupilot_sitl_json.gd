extends Node

class_name ArdupilotSitlJson

@export var target_vehicle: VehicleBody3D
@onready var wait_SITL = false
@onready var start_time
@onready var _initial_position

var interface = PacketPeerUDP.new()  # UDP socket for fdm in (server)
var calculated_acceleration
var phys_time = 0
var last_velocity
var peer = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	start_time = Time.get_ticks_msec()
	last_velocity = Vector3(0,0,0)
	_initial_position = target_vehicle.get_global_transform().origin
	set_physics_process(true)
	connect_fmd_in()

func connect_fmd_in():
	if interface.bind(9002) != OK:
		print("Failed to connect fdm_in")

func read_servos():
	if not peer:
		interface.set_dest_address("127.0.0.1", interface.get_packet_port())

	if not interface.get_available_packet_count():
		if wait_SITL:
			interface.wait()
		else:
			return

	var buffer = StreamPeerBuffer.new()
	buffer.data_array = interface.get_packet()

	var magic = buffer.get_u16()
	buffer.seek(2)
	var _framerate = buffer.get_u16()
	#print(_framerate)
	buffer.seek(4)
	var _framecount = buffer.get_u16()

	if magic != 18458:
		return
		
	var servos: Array[float] = []
	var servos_as_string = ''
	for i in range(0, 15):
		buffer.seek(8 + i * 2)
		var value = (float(buffer.get_u16()) - 1000.0) / 1000
		servos_as_string += "%d: %f\n" % [i, value]
		servos.append(value -0.5)
	target_vehicle.actuate_servos(servos)
	$"../HUD/VBoxContainer2/Servos".text = servos_as_string


func send_fdm():
	var buffer = StreamPeerBuffer.new()

	buffer.put_double((Time.get_ticks_msec() - start_time) / 1000.0)

	var _basis = target_vehicle.transform.basis

# These are the same but mean different things, let's keep both for now
	var toNED = Basis(Vector3(-1, 0, 0), Vector3(0, 0, -1), Vector3(1, 0, 0))

	toNED = Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))

	var toFRD = Basis(Vector3(0, -1, 0), Vector3(0, 0, -1), Vector3(1, 0, 0))

	var _angular_velocity = toFRD * (target_vehicle.angular_velocity * _basis)
	var gyro = [_angular_velocity.x, _angular_velocity.y, _angular_velocity.z]

	var _acceleration = toFRD * (calculated_acceleration * _basis)

	var accel = [_acceleration.x, _acceleration.y, _acceleration.z]

	# var orientation = toFRD.xform(Vector3(-rotation.x, - rotation.y, -rotation.z))
	var quaternon = Basis(-_basis.z, _basis.x, _basis.y).rotated(Vector3(1, 0, 0), PI).rotated(Vector3(1, 0, 0), PI / 2).get_rotation_quaternion()

	var euler = quaternon.get_euler()
	euler = [euler.y, euler.x, euler.z]

	var _velocity = toNED * target_vehicle.linear_velocity
	var velo = [_velocity.x, _velocity.y, _velocity.z]

	var _position = toNED * target_vehicle.transform.origin
	var pos = [_position.x, _position.y, _position.z]

	var IMU_fmt = {"gyro": gyro, "accel_body": accel}
	var JSON_fmt = {
		"timestamp": phys_time,
		"imu": IMU_fmt,
		"position": pos,
		"quaternion": [quaternon.w, quaternon.x, quaternon.y, quaternon.z],
		"velocity": velo
	}
	var JSON_string = "\n" + JSON.stringify(JSON_fmt) + "\n"
	buffer.put_utf8_string(JSON_string)
	interface.put_packet(buffer.data_array)


func _process(delta):
	phys_time = phys_time + 1.0 / 60 # Globals.physics_rate
	calculated_acceleration = (target_vehicle.linear_velocity - last_velocity) / delta
	calculated_acceleration.y += 10
	last_velocity = target_vehicle.linear_velocity
	read_servos()
	send_fdm()
