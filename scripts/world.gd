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

# This will contain player info for every player,
# with the keys being each player's unique IDs.
var players = {}

# This is the local player info. This should be modified locally
# before the connection is made. It will be passed to every other peer.
var player_data = {"name": "Name"}

var players_loaded = 0
var available_vehicles = []  # List to track available vehicles

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
		new_vehicle.name = "vehicle_%d" % i
		
		# Position vehicles in a 2x2 grid, spaced 5 units apart
		var row = i / 2
		var col = i % 2
		new_vehicle.position = Vector3(col * 5.0, 0, row * 5.0)
		
		$players.add_child(new_vehicle, true)
		available_vehicles.append(new_vehicle)
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
	if available_vehicles.size() == 0:
		pprint("No vehicles available for player %s" % id)
		return
		
	var vehicle = available_vehicles.pop_front()
	var new_player_info = {
		"name": str(id),
		"peerid": id,
		"simple_id": players.size(),
		"vehicle_name": vehicle.name
	}
	players[id] = new_player_info
	
	# Register the new player on their client
	_register_player.rpc_id(id, new_player_info)
	
	# Rename the vehicle to match the player ID and set authority
	vehicle.name = str(id)
	vehicle.player_info = new_player_info

	pprint("Server: player %s connected and assigned to vehicle %s" % [id, vehicle.name])
	pprint(str(players))

# Server handling of player disconnections
func _server_handle_player_disconnected(id):
	if players.has(id):
		var player_data = players[id]
		var vehicle_name = player_data.get("vehicle_name")
		
		# Find the vehicle and make it available again
		for child in $players.get_children():
			if child.name == str(id):
				child.name = vehicle_name
				available_vehicles.append(child)
				break
	
	players.erase(id)
	player_disconnected.emit(id)
	pprint("Server: player %s disconnected, vehicle returned to pool" % id)

#
# CLIENT-SPECIFIC CODE
#

func _setup_client():
	join_game()

func join_game(address = ""):
	pprint("Client: joining game")
	if address.is_empty():
		if OS.has_feature('web'):
			address = JavaScriptBridge.eval('window.location.origin.replace("http","ws")') + "/bluesim_ws/"	
		else:
			address = "ws://" + DEFAULT_SERVER_IP + ":" + str(PORT)
	
	var peer = WebSocketMultiplayerPeer.new()
	var error = peer.create_client(address)

	if error:
		print("Error joining: ", error)
		return error
		
	multiplayer.multiplayer_peer = peer

# Client function to find and setup player vehicle and camera
func _setup_client_vehicle():
	var id = str(multiplayer.get_unique_id())
	
	# Loop through children to find the one matching our ID
	var my_bluerov = null
	for child in $players.get_children():
		if child.name == id:
			my_bluerov = child
			break
	
	if my_bluerov:
		%PlayerPhantomCamera3D.follow_target = my_bluerov
		
		# Find and activate camera
		var camera = _find_camera_in_node(my_bluerov)
		if camera:
			camera.make_current()

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
	players[peer_id] = player_data
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
	players.clear()
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
		players.erase(id)
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
	players.clear()

# RPC functions
@rpc("any_peer", "reliable")
func _register_player(new_player_info):
	var new_player_id = multiplayer.get_remote_sender_id()
	players[new_player_id] = new_player_info
	player_data = new_player_info
	player_connected.emit(new_player_id, new_player_info)
	Globals.player_info = new_player_info
	pprint("Client: player %s registered" % new_player_info)
