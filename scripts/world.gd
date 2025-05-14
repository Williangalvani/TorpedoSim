extends Node3D

@export var is_server: bool

signal player_connected(peer_id, player_info)
signal player_disconnected(peer_id)
signal server_disconnected

const PORT = 7000
const ALTERNATIVE_PORTS = [7001, 7002, 7003, 8000]  # Alternative ports to try if main port fails
const DEFAULT_SERVER_IP = "127.0.0.1" # IPv4 localhost
const MAX_CONNECTIONS = 20
const USE_WSS = false # Keep this false to disable TLS/SSL
const NUM_VEHICLES = 4  # Number of vehicles to pre-spawn

# This is the local player info. This should be modified locally
# before the connection is made. It will be passed to every other peer.
var player_data = {"name": "Name"}

var player_scene = preload("res://vehicles/bluerov2/BlueROV2.tscn")

func pprint(string: String):
	var id = multiplayer.get_unique_id()
	print("%s: %s" % [id, string])

func _ready():
	# Connect signals for both server and client
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connected_fail)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	print(Globals.player_info)
	is_server = OS.has_feature("dedicated_server")
	if is_server:
		Globals.is_server = true
		_setup_server()
	else:
		_setup_client()

#
# SERVER-SPECIFIC CODE
#

func _setup_server():
	print("setting up server")
	$serverCamera.make_current()
	$HUD/HBoxContainer/servosPanel.visible = false
	_create_initial_vehicles()
	create_game()

func _create_initial_vehicles():
	# Create NUM_VEHICLES vehicles and position them in a grid
	for i in range(NUM_VEHICLES):
		var new_vehicle = player_scene.instantiate()
		new_vehicle.set_json_port(9002 + i)
		var vehicle_number = i + 1
		new_vehicle.name = "vehicle_%d" % vehicle_number
		new_vehicle.set_name_label("Rov %d" % vehicle_number)
		
		# Position vehicles in a 2x2 grid, spaced 5 units apart
		var row = i / 2
		var col = i % 2
		new_vehicle.position = Vector3(col * 0.6, 0, row * 0.6)
		
		$players.add_child(new_vehicle, true)
		pprint("Created vehicle %d at position %s" % [i, new_vehicle.position])

func create_game():
	var peer = WebSocketMultiplayerPeer.new()
	var used_port = PORT
	
	# Explicitly pass null as the TLS options to ensure TLS is disabled
	var error = peer.create_server(PORT, "127.0.0.1", null)
	if error != OK:
		print("Failed to create server on port %d: Error %d" % [PORT, error])
		print("ERROR: Could not create WebSocket server on port. Last error: ", error)
		if error == ERR_UNAVAILABLE:
			print("The server port may already be in use. Try closing other applications or restarting your device.")
		return error
	
	print("WebSocket server created successfully on port: ", used_port)
	multiplayer.multiplayer_peer = peer

# Server handling of new player connections
func _server_handle_player_connected(id):
	_register_player.rpc_id(id)


# Server handling of player disconnections
func _server_handle_player_disconnected(id):
	player_disconnected.emit(id)
	pprint("Server: player %s disconnected, vehicle returned to pool" % id)

#
# CLIENT-SPECIFIC CODE
#

func _setup_client():
	print(OS.get_cmdline_args())
	var args = OS.get_cmdline_args()
	for arg in args:
		if arg.find("player=") != -1:
			player_data.name = arg.split("=")[1]
			player_data.vehicle_name = "vehicle_" + arg.split("=")[1]
			break
	join_game()

func join_game(address = ""):
	pprint("Client: joining game")
	if address.is_empty():
		if OS.has_feature('web'):
			address = JavaScriptBridge.eval('window.location.origin.replace("http","ws")') + "/bluesim_ws/"	
		else:
			address = "ws://" + DEFAULT_SERVER_IP + ":" + str(PORT)
	
	var peer = WebSocketMultiplayerPeer.new()
	var error = peer.create_client(address, TLSOptions.client_unsafe())

	if error:
		print("Error joining: ", error)
		return error
		
	multiplayer.multiplayer_peer = peer

# Client function to find and setup player vehicle and camera
func _setup_client_vehicle():
	# Get our vehicle using the name assigned by the server
	if OS.has_feature("web"):
		#get vehicle number from url query params
		var url = JavaScriptBridge.eval('window.location.href')
		var vehicle_number = url.split("?")[1].split("=")[1]
		player_data.vehicle_name = "vehicle_" + vehicle_number
		print("attaching to vehicle", vehicle_number)
		
	var my_bluerov = $players.find_child(player_data.vehicle_name, true, false)
	print("my_bluerov ", my_bluerov)
	
	if my_bluerov:
		%PlayerPhantomCamera3D.follow_target = my_bluerov
		# Find and activate camera
		var camera = _find_camera_in_node(my_bluerov)
		if camera:
			camera.make_current()
		else:
			pprint("Warning: No camera found in vehicle %s" % player_data.vehicle_name)
	else:
		pprint("Error: Could not find assigned vehicle %s" % player_data.vehicle_name)

# Helper function to recursively find a camera in a node's children
func _find_camera_in_node(node):
	# Check if this node is a camera
	if node is Camera3D:
		return node
	
	# Recursively check all children
	for child in node.get_children():
		var found_camera = _find_camera_in_node(child)
		if found_camera:
			return found_camera
	
	# No camera found
	return null

# Client handling of successful connection
func _client_handle_connected():
	var peer_id = multiplayer.get_unique_id()
	player_connected.emit(peer_id, player_data)
	pprint("Client: connected with ID %s" % peer_id)
	
	# Wait a moment for player creation then setup vehicle
	get_tree().create_timer(1.0).timeout.connect(_setup_client_vehicle)

# Client handling of connection failure
func _client_handle_connection_failed():
	multiplayer.multiplayer_peer = null
	pprint("Client: connection failed")

# Client handling of server disconnection
func _client_handle_server_disconnected():
	multiplayer.multiplayer_peer = null
	server_disconnected.emit()
	pprint("Client: server disconnected")

#
# SHARED CODE (but with role-specific implementations)
#

# Common handler for peer connections that delegates to role-specific functions
func _on_player_connected(id):
	if is_server:
		_server_handle_player_connected(id)

# Common handler for peer disconnections that delegates to role-specific functions
func _on_player_disconnected(id):
	if is_server:
		_server_handle_player_disconnected(id)
	else:
		player_disconnected.emit(id)
		pprint("Client: player %s disconnected" % id)

# Common handler for successful connection that delegates to role-specific functions
func _on_connected_ok():
	if !is_server:
		_client_handle_connected()

# Common handler for connection failure that delegates to role-specific functions
func _on_connected_fail():
	if !is_server:
		_client_handle_connection_failed()

# Common handler for server disconnection that delegates to role-specific functions
func _on_server_disconnected():
	if !is_server:
		_client_handle_server_disconnected()

func remove_multiplayer_peer():
	multiplayer.multiplayer_peer = null

# RPC functions
@rpc("any_peer", "reliable")
func _register_player():
	# Setup vehicle and camera immediately after registration
	if !is_server:
		_setup_client_vehicle()
