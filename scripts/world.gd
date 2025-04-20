extends Node3D

@export var is_server: bool

signal player_connected(peer_id, player_info)
signal player_disconnected(peer_id)
signal server_disconnected

const PORT = 7000
const DEFAULT_SERVER_IP = "127.0.0.1" # IPv4 localhost
const MAX_CONNECTIONS = 20

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
	print("joining")
	if address.is_empty():
		address = DEFAULT_SERVER_IP
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, PORT)
	if error:
		print("error joining")
		return error
	multiplayer.multiplayer_peer = peer
	var id = str(multiplayer.get_unique_id())
	await get_tree().create_timer(2.0).timeout 
	
	# Loop through children to find the one matching our ID
	var my_bluerov = null
	for child in $players.get_children():
		if child.name == id:
			my_bluerov = child
			break
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
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, MAX_CONNECTIONS)
	if error:
		return error
	multiplayer.multiplayer_peer = peer

	players[1] = player_info
	player_connected.emit(1, player_info)


func remove_multiplayer_peer():
	multiplayer.multiplayer_peer = null
	players.clear()


# When the server decides to start the game from a UI scene,
# do Lobby.load_game.rpc(filepath)
@rpc("call_local", "reliable")
func load_game(game_scene_path):
	get_tree().change_scene_to_file(game_scene_path)


# Every peer will call this when they have loaded the game scene.
@rpc("any_peer", "call_local", "reliable")
func player_loaded():
	if multiplayer.is_server():
		players_loaded += 1
		if players_loaded == players.size():
			$/root/Game.start_game()
			players_loaded = 0


# When a peer connects, send them my player info.
# This allows transfer of all desired data for each player, not only the unique ID.
func _on_player_connected(id):
	_register_player.rpc_id(id, player_info)
	var new_player = player_scene.instantiate()
	new_player.name = str(id)
	$players.add_child(new_player, true)
	new_player.set_id(id)
	print("player %s connected" % id)


@rpc("any_peer", "reliable")
func _register_player(new_player_info):
	var new_player_id = multiplayer.get_remote_sender_id()
	players[new_player_id] = new_player_info
	player_connected.emit(new_player_id, new_player_info)


func _on_player_disconnected(id):
	players.erase(id)
	player_disconnected.emit(id)


func _on_connected_ok():
	var peer_id = multiplayer.get_unique_id()
	players[peer_id] = player_info
	player_connected.emit(peer_id, player_info)


func _on_connected_fail():
	multiplayer.multiplayer_peer = null


func _on_server_disconnected():
	multiplayer.multiplayer_peer = null
	players.clear()
	server_disconnected.emit()
