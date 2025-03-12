extends Node

class_name ArdupilotSitlJson

# Vehicle Node. Must implement actuate_servos(values: float[])
@export var target_vehicle: RigidBody3D
# Port to listen for JSON data, Ardupilot's default is 9002
@export var JSON_PORT: int = 9002
# Pause the simulator while waiting for ardupilot data, effectively a lock-step system
@export var wait_SITL = false

@onready var start_time: int
@onready var _initial_position: Vector3
var socket := WebSocketPeer.new()
var calculated_acceleration: Vector3
var phys_time: float = 0
var last_velocity: Vector3
var last_servo_timestamp: int = 0
var last_connection_attempt: int = 0
const RECONNECT_DELAY_MS = 2000  # Wait 1 second between connection attempts

# Called when the node enters the scene tree for the first time.
func _ready():
	# Get the `window` object, where globally defined functions are.
	var window = JavaScriptBridge.get_interface("window")
	start_time = Time.get_ticks_msec()
	last_velocity = Vector3.ZERO
	_initial_position = target_vehicle.get_global_transform().origin
	set_physics_process(true)
	connect_to_server()

func connect_to_server() -> void:
	var websocket_url = "ws://192.168.15.8:9002"
	if OS.has_feature('web'):
		print("browser detected")
		websocket_url = JavaScriptBridge.eval('window.location.origin.replace("http","ws")') + "/ws_sitl/"
	print("Connecting to ArduPilot WebSocket server at ", websocket_url)
	var result =  socket.connect_to_url(websocket_url, TLSOptions.client_unsafe())
	if result != OK:
		print("Failed to connect to ArduPilot server at ", websocket_url)
		print(result)
		$"../HUD/status".text = "Failed to connect to ArduPilot"
	else:
		print("connection successful")
	last_connection_attempt = Time.get_ticks_msec()

func handle_servos(data: PackedByteArray) -> void:
	var buffer = StreamPeerBuffer.new()
	buffer.data_array = data
	
	var magic = buffer.get_u16()
	if magic != 18458:
		print("Invalid magic number: ", magic)
		return
		
	buffer.seek(2)
	var _framerate = buffer.get_u16()
	buffer.seek(4)
	var _framecount = buffer.get_u16()

	var servos: Array[float] = []
	var servos_as_string = 'Servo data from autopilot:\n'
	for i in range(0, 15):
		buffer.seek(8 + i * 2)
		var value = (float(buffer.get_u16()) - 1000.0) / 1000
		servos_as_string += "%d: %f\n" % [i, value]
		servos.append(value -0.5)
	target_vehicle.actuate_servos(servos)
	$"../HUD/VBoxContainer2/Servos".text = servos_as_string
	last_servo_timestamp = Time.get_ticks_msec()
	$"../HUD/HBoxContainer/statuspanel/status".text = "Connected to ArduPilot"

func send_fdm() -> void:
	if socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		$"../HUD/HBoxContainer/statuspanel/status".text = "Not connected to ArduPilot"
		return
		
	var buffer = StreamPeerBuffer.new()
	buffer.put_double((Time.get_ticks_msec() - start_time) / 1000.0)

	var _basis = target_vehicle.transform.basis

	var toNED = Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
	var toFRD = Basis(Vector3(0, -1, 0), Vector3(0, 0, -1), Vector3(1, 0, 0))
	
	var _angular_velocity = toFRD * (target_vehicle.angular_velocity * _basis)
	var gyro = [_angular_velocity.x, _angular_velocity.y, _angular_velocity.z]

	var _acceleration = toFRD * (calculated_acceleration * _basis)
	var accel = [_acceleration.x, _acceleration.y, _acceleration.z]

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
	socket.send_text(JSON_string)

func _process(_delta: float) -> void:
	socket.poll()
	
	var state = socket.get_ready_state()
	match state:
		WebSocketPeer.STATE_OPEN:
			while socket.get_available_packet_count():
				handle_servos(socket.get_packet())
		WebSocketPeer.STATE_CLOSED, WebSocketPeer.STATE_CLOSING:
			$"../HUD/HBoxContainer/statuspanel/status".text = "Disconnected from ArduPilot"
			# Try to reconnect after delay
			if Time.get_ticks_msec() - last_connection_attempt >= RECONNECT_DELAY_MS:
				connect_to_server()
		WebSocketPeer.STATE_CONNECTING:
			$"../HUD/HBoxContainer/statuspanel/status".text = "Connecting to ArduPilot..."

func _physics_process(delta: float) -> void:
	phys_time = phys_time + delta
	calculated_acceleration = (target_vehicle.linear_velocity - last_velocity) / delta
	calculated_acceleration.y += 10
	last_velocity = target_vehicle.linear_velocity
	send_fdm()

func _exit_tree() -> void:
	socket.close()
