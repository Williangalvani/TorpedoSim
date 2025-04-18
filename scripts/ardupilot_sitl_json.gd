extends Node

class_name ArdupilotSitlJson

# Vehicle Node. Must implement actuate_servos(values: float[])
@export var target_vehicle: RigidBody3D
# Port to listen for JSON data, Ardupilot's default is 9002
@export var JSON_PORT: int = 9002
# Pause the simulator while waiting for ardupilot data, effectively a lock-step system
@export var wait_SITL = false
# Connection type (0 = UDP, 1 = WebSocket)
@export_enum("UDP", "WebSocket") var connection_type: int = 0

@onready var start_time: int
@onready var _initial_position: Vector3

signal status_updated
signal sitl_packet_rate_updated
signal servos_updated

# WebSocket mode variables
var socket := WebSocketPeer.new()
var last_connection_attempt: int = 0
const RECONNECT_DELAY_MS = 2000  # Wait 2 seconds between connection attempts

# UDP mode variables
var interface = PacketPeerUDP.new()  # UDP socket for fdm in (server)
var peer = null

# Common variables
var calculated_acceleration: Vector3
var phys_time: float = 0
var last_velocity: Vector3
var last_servo_timestamp: int = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	start_time = Time.get_ticks_msec()
	last_velocity = Vector3.ZERO
	_initial_position = target_vehicle.get_global_transform().origin
	set_physics_process(true)
	
	if connection_type == 0:  # UDP mode
		connect_udp()
	else:  # WebSocket mode
		connect_websocket()

func connect_udp() -> void:
	if interface.bind(JSON_PORT) != OK:
		print("Failed to connect UDP on port ", JSON_PORT)
		status_updated.emit("Failed to connect UDP")
	else:
		print("UDP bound to port ", JSON_PORT)
		status_updated.emit("UDP listening on port " + str(JSON_PORT))

func connect_websocket() -> void:
	var websocket_url = "ws://192.168.15.8:9002"
	if OS.has_feature('web'):
		websocket_url = JavaScriptBridge.eval('window.location.origin.replace("http","ws")') + "/ws_sitl/"	
	print("Connecting to ArduPilot WebSocket server at ", websocket_url)
	var result = socket.connect_to_url(websocket_url, TLSOptions.client_unsafe())
	if result != OK:
		print("Failed to connect to ArduPilot server at ", websocket_url)
		print(result)
		status_updated.emit("Failed to connect to ArduPilot")
	else:
		print("WebSocket connection successful")
	last_connection_attempt = Time.get_ticks_msec()

func read_udp_servos() -> void:
	if not peer and interface.get_packet_port() > 0:
		interface.set_dest_address("127.0.0.1", interface.get_packet_port())
		peer = true

	if not interface.get_available_packet_count():
		if (Time.get_ticks_msec() - last_servo_timestamp) > 1000:
			status_updated.emit("Not connected to ArduPilot")
		if wait_SITL:
			interface.wait()
		else:
			return
	
	handle_servos(interface.get_packet())

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
		servos.append(value - 0.5)
	target_vehicle.actuate_servos(servos)
	servos_updated.emit(servos_as_string)
	var packet_frequency = 1000.0 / (Time.get_ticks_msec() - last_servo_timestamp + 1)  # +1 to avoid division by zero
	last_servo_timestamp = Time.get_ticks_msec()
	sitl_packet_rate_updated.emit(packet_frequency)
	status_updated.emit("Connected to ArduPilot")

func send_fdm() -> void:
	if connection_type == 0:  # UDP mode
		send_fdm_udp()
	else:  # WebSocket mode
		send_fdm_websocket()

func send_fdm_udp() -> void:
	if not peer:
		return
		
	var buffer = StreamPeerBuffer.new()
	var json_data = prepare_fdm_data()
	var json_string = "\n" + JSON.stringify(json_data) + "\n"
	buffer.put_utf8_string(json_string)
	interface.put_packet(buffer.data_array)

func send_fdm_websocket() -> void:
	if socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		status_updated.emit("Not connected to ArduPilot")
		return
		
	var json_data = prepare_fdm_data()
	var json_string = "\n" + JSON.stringify(json_data) + "\n"
	socket.send_text(json_string)

func prepare_fdm_data() -> Dictionary:
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
	
	return JSON_fmt

func _process(delta: float) -> void:
	if connection_type == 0:  # UDP mode
		read_udp_servos()
	else:  # WebSocket mode
		process_websocket()
		
func process_websocket() -> void:
	socket.poll()
	
	var state = socket.get_ready_state()
	match state:
		WebSocketPeer.STATE_OPEN:
			while socket.get_available_packet_count():
				handle_servos(socket.get_packet())
		WebSocketPeer.STATE_CLOSED, WebSocketPeer.STATE_CLOSING:
			status_updated.emit("Disconnected from ArduPilot")
			# Try to reconnect after delay
			if Time.get_ticks_msec() - last_connection_attempt >= RECONNECT_DELAY_MS:
				connect_websocket()
		WebSocketPeer.STATE_CONNECTING:
			status_updated.emit("Connecting to ArduPilot...")

func _physics_process(delta: float) -> void:
	phys_time = phys_time + delta
	calculated_acceleration = (target_vehicle.linear_velocity - last_velocity) / delta
	calculated_acceleration.y += 10
	last_velocity = target_vehicle.linear_velocity
	send_fdm()

func _exit_tree() -> void:
	if connection_type == 0:  # UDP mode
		interface.close()
	else:  # WebSocket mode
		socket.close()
