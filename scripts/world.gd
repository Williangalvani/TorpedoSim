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

# This will contain player info for every player,
# with the keys being each player's unique IDs.
var players = {}

# This is the local player info. This should be modified locally
# before the connection is made. It will be passed to every other peer.
# For example, the value of "name" can be set to something the player
# entered in a UI scene.
var player_info = {"name": "Name"}

var players_loaded = 0

var player_scene = preload("res://vehicles/bluerov2/BlueROV2.tscn")

func pprint(string: String):
	var id = multiplayer.get_unique_id()
	print("%s: %s" % [id, string])

func _ready():
	if is_server:
		$serverCamera.make_current()
		$HUD/HBoxContainer/servosPanel.visible = false

		multiplayer.peer_connected.connect(_on_player_connected)
		multiplayer.peer_disconnected.connect(_on_player_disconnected)
		multiplayer.connected_to_server.connect(_on_connected_ok)
		multiplayer.connection_failed.connect(_on_connected_fail)
		multiplayer.server_disconnected.connect(_on_server_disconnected)
		create_game()
	else:
		join_game()

func join_game(address = ""):
	self.pprint("joining")
	if address.is_empty():
		address = DEFAULT_SERVER_IP
	
	var peer = WebSocketMultiplayerPeer.new()
	# Always use ws:// protocol (not wss://) to ensure TLS is disabled
	var url = "ws://%s:%s" % [address, PORT]
	pprint("Connecting to: %s" % url)
	
	var error = peer.create_client(url)
	if error:
		print("error joining: ", error)
		return error
	multiplayer.multiplayer_peer = peer

	await get_tree().create_timer(1.0).timeout 
	var id = str(multiplayer.get_unique_id())
	# Loop through children to find the one matching our ID
	var my_bluerov = null
	for child in $players.get_children():
		if child.name == id:
			my_bluerov = child
			break
	#print($players.get_children())
	%PlayerPhantomCamera3D.follow_target = my_bluerov
	
	# If we found our vehicle, look for a camera in its children and make it active
	if my_bluerov:
		# Find the first camera in the children
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

func create_game():
	var peer = WebSocketMultiplayerPeer.new()
	var ports_to_try = [PORT] + ALTERNATIVE_PORTS
	var success = false
	var last_error = 0
	var used_port = PORT
	
	# Try each port until one works
	for port in ports_to_try:
		# Explicitly pass null as the TLS options to ensure TLS is disabled
		var error = peer.create_server(port, "127.0.0.1", null)
		if error == OK:
			success = true
			used_port = port
			break
		else:
			last_error = error
			print("Failed to create server on port %d: Error %d" % [port, error])
	
	if not success:
		print("ERROR: Could not create WebSocket server on any port. Last error: ", last_error)
		if last_error == ERR_UNAVAILABLE:
			print("The server port may already be in use. Try closing other applications or restarting your device.")
		return last_error
	
	print("WebSocket server created successfully on port: ", used_port)
	multiplayer.multiplayer_peer = peer

func remove_multiplayer_peer():
	multiplayer.multiplayer_peer = null
	players.clear()

# When a peer connects, send them my player info.
# This allows transfer of all desired data for each player, not only the unique ID.
func _on_player_connected(id):
	player_info["peerid"] = multiplayer.get_unique_id()
	player_info["simple_id"] = players.size()
	players[id] = player_info
	_register_player.rpc_id(id, player_info)
	var new_player = player_scene.instantiate()
	new_player.name = str(id)
	$players.add_child(new_player, true)
	new_player.set_id(id)
	pprint("player %s connected" % id)

# this runs on clients
@rpc("any_peer", "reliable")
func _register_player(new_player_info):
	var new_player_id = multiplayer.get_remote_sender_id()
	players[new_player_id] = new_player_info
	player_connected.emit(new_player_id, new_player_info)
	pprint("player %s registered" % new_player_info)

func _on_player_disconnected(id):
	players.erase(id)
	player_disconnected.emit(id)
	pprint("player %s disconnected" % id)
	for child in $players.get_children():
		if child.name == str(id):
			child.queue_free()
			break

func _on_connected_ok():
	var peer_id = multiplayer.get_unique_id()
	players[peer_id] = player_info
	player_connected.emit(peer_id, player_info)
	pprint("player %s connected" % peer_id)

func _on_connected_fail():
	multiplayer.multiplayer_peer = null
	pprint("connection failed")

func _on_server_disconnected():
	multiplayer.multiplayer_peer = null
	players.clear()
	server_disconnected.emit()
	pprint("server disconnected")
