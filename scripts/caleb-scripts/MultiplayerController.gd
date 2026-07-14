extends Control
class_name MultiplayerController
enum TestingType {
	Railway = 0,
	Local = 1
}

#region export

@export var testingType: TestingType
@export var gameScene: PackedScene


# Inside MultiplayerController.gd
# RAILWAY TESTING VALUES
@export var Address = "orbital-defense-production.up.railway.app" # Put your Railway domain here!
@export var port = 443 # Standard secure web proxy port used by Railway

# @export var Address = "orbital-defense-production.up.railway.app" # Put your Railway domain here!
# @export var port = 443 # Standard secure web proxy port used by Railway

# LOCAL TESTING ONLY
# @export var Address = "127.0.0.1" # local server (?)
# @export var port = 8910 # TODO: check port?
#endregion

#region onReady
@onready var label = $Label

@onready var hostButton = $HostButton
@onready var joinButton = $JoinButton
@onready var cancelButton = $CancelButton
@onready var startGameButton = $StartGameButton

@onready var roomCodeText = $RoomCode
@onready var usernameText = $Username

@onready var notificationLabel = $NotificationLabel
#endregion

# Idle: neither joining nor hosting
# idle can go to join or to host via respective buttons
# 
# hosting: from idle using host button. can go back to idle by pressing cancel
# 
# joining: from idle using join button. can go back to idle by pressing cancel
#


const MAX_PLAYERS = 2

var peer

enum LobbyState {
	IDLE,
	HOSTING,
	JOINING
}

var state = LobbyState.IDLE

func _ready():
	init_menu()
	match testingType:
		TestingType.Railway:
			Address = "orbital-defense-production.up.railway.app"
			port = 443
		TestingType.Local:
			Address = "127.0.0.1"
			port = 8910
	
	if "--server" in OS.get_cmdline_args():
		hostGame()
	pass

func init_menu():
	cancelButton.disabled = true
	startGameButton.disabled = true
	hostButton.disabled = false
	joinButton.disabled = false
	state = LobbyState.IDLE

	# server connectivity
	if not multiplayer.peer_connected.is_connected(player_connected):
		multiplayer.peer_connected.connect(player_connected)
	if not multiplayer.peer_disconnected.is_connected(player_disconnected):
		multiplayer.peer_disconnected.connect(player_disconnected)
	if not multiplayer.connected_to_server.is_connected(connected_to_server):
		multiplayer.connected_to_server.connect(connected_to_server)
	if not multiplayer.connection_failed.is_connected(connection_failed):
		multiplayer.connection_failed.connect(connection_failed)

	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)


func _on_cancel_button_button_down() -> void:
	label.text = ""
	state = LobbyState.IDLE
	cancelButton.disabled = true
	startGameButton.disabled = true
	hostButton.disabled = false
	joinButton.disabled = false

	# TODO: destroy peer and/or disconnect from server
	# if peer:
	# 	peer = null

	close_server()

	pass # Replace with function body.


func _on_join_button_button_down() -> void:
	if usernameText.text == "":
		print("Please enter a username!")
		label.text = "Please enter a username!"
		return
	# check room code text
	# if roomCodeText.text == "":
	# 	print("Please enter a room code!")
	# 	label.text = "Please enter a room code!"
	# 	return
	# TODO: check if room code is valid
	hostButton.disabled = true
	joinButton.disabled = true
	

	cancelButton.disabled = false
	state = LobbyState.JOINING
	startGameButton.disabled = false

	#TODO: connect to server


	# code by Gemini:

	match testingType:
		TestingType.Railway:
			var connection_url = "wss://" + Address + ":" + str(port)
			peer = WebSocketMultiplayerPeer.new()
			print("Connecting to cloud server: ", connection_url)
		
			# Call create_client with the WebSocket URL string
			var error = peer.create_client(connection_url)
			if error != OK:
				print("Cannot connect to WebSocket server!", error)
				return

		TestingType.Local:
			peer = ENetMultiplayerPeer.new()
			
			
			var error = peer.create_client(Address, port)
			if error != OK:
				print("Cannot connect to server!", error)
				return
			peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	
	# var connection_url = Address
	

	multiplayer.set_multiplayer_peer(peer)
	print("Joining server...")
	pass # Replace with function body.


func _on_host_button_button_down() -> void:
	if usernameText.text == "":
		print("Please enter a username!")
		label.text = "Please enter a username!"
		return

	label.text = ""
	cancelButton.disabled = false
	state = LobbyState.HOSTING
	startGameButton.disabled = false

	hostButton.disabled = true
	joinButton.disabled = true

	SendPlayerData(usernameText.text, multiplayer.get_unique_id())
	# TODO: create server
	hostGame()

	pass # Replace with function body.


func _on_start_game_button_button_down() -> void:
	# if state != LobbyState.HOSTING:
	# 	print("You must be hosting to start the game!")
	# 	label.text = "You must be hosting to start the game!"
	# 	return
	if usernameText.text == "":
		print("Please enter a username!")
		label.text = "Please enter a username!"
		return

	label.text = ""

	hostButton.disabled = true
	joinButton.disabled = true
	# start the game!
	request_server_to_start.rpc_id(1)
	pass # Replace with function body.


#region backend

func hostGame():
	# hopefully Railway can provide the right environment variable
	if OS.has_environment("PORT"):
		port = OS.get_environment("PORT").to_int()

	match testingType:
		TestingType.Railway:
			peer = WebSocketMultiplayerPeer.new()
			var error = peer.create_server(port, "*")
			if error != OK:
				print("Cannot host WebSocket server!", error)
				return
		TestingType.Local:
			peer = ENetMultiplayerPeer.new()
			var error = peer.create_server(port, MAX_PLAYERS)
			if error != OK:
				print("Cannot host!", error)
				return
			# Safely isolate ENet packet tracking properties exclusively to Local builds
			peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	
	
	# peer.get_host().compress(ENetConnection.COMPRESS_FASTLZ)
	if testingType == TestingType.Local:
		peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	
	multiplayer.set_multiplayer_peer(peer)
	print("Waiting for players!")

	
	pass

# This runs ONLY on the server because clients called it via rpc_id(1)
@rpc("any_peer", "call_local", "reliable")
func request_server_to_start():
	if multiplayer.is_server():
		print("Server received start request. Broadcasting to all clients...")
		# The server calls .rpc(), which successfully broadcasts to ALL clients
		startGame.rpc()

@rpc("any_peer", "call_local")
func startGame():
	if gameScene:
		var scene = gameScene.instantiate()
		
		get_tree().root.add_child(scene)

		self.process_mode = Node.PROCESS_MODE_DISABLED
		self.visible = false
		# the scenes '_ready' will handle spawning players and game logic

	pass


@rpc("any_peer")
func SendPlayerData(playerName, id):
	if !GameManager.Players.has(id):
		GameManager.Players[id] = {
			"name": playerName,
			"id": id
		}
		GameManager.player_ids.push_front(id)
	print("Player ", playerName, " has joined the game!")
	# server
	if multiplayer.is_server():
		for i in GameManager.Players:
			SendPlayerData.rpc(GameManager.Players[i].name, i)
	pass


func player_connected(id):
	print("Player connected ", id)
	notificationLabel.text = "Player connected: " + str(id)
	pass

func player_disconnected(id):
	GameManager.Players.erase(id)
	var players = get_tree().get_nodes_in_group("Players")
	for i in players:
		if i.name == str(id):
			i.queue_free()
	pass

func connected_to_server():
	# note: since this passes 1, does that mean its server authority?
	SendPlayerData.rpc_id(1, $Username.text, multiplayer.get_unique_id())

	# TODO: validate roomcode.text
	# print("Connected to server with room code", roomCodeText.text)
	# label.text = "Connected to server with room code " + roomCodeText.text
	pass

func connection_failed():
	print("Connection failed!")
	label.text = "Connection failed! Please try again..."
	pass

# NOTE: this code generated with AI
func close_server():
	print("Closing server...")
	var multiplayer_peer = multiplayer.get_multiplayer_peer()

	if multiplayer_peer and not (multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
		print("Server closed.")

		print("Server closed.")
	else:
		print("No multiplayer peer to close.")


# reset menu when disconnected by server
func _on_server_disconnected() -> void:
	print("Server disconnected.")

	var level = get_tree().root.get_node_or_null("Level")
	if level:
		level.set_process(false)
		level.set_physics_process(false)
		level.queue_free()
	
	GameManager.clear_game_state()

	self.visible = true
	self.process_mode = Node.PROCESS_MODE_INHERIT
	init_menu()


#endregion
