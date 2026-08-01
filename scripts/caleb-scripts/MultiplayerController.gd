extends Control
class_name MultiplayerController
enum TestingType {
	Railway = 0,
	Local = 1
}

#region export

@export var testingType: TestingType = TestingType.Railway
@export var gameScene: PackedScene


# Inside MultiplayerController.gd
# RAILWAY TESTING VALUES
@export var Address = "orbital-defense-production.up.railway.app" # Put your Railway domain here!
@export var port = 443 # Standard secure web proxy port used by Railway


#endregion

#region onReady
@onready var menuCanvas = $MenuCanvas
@onready var creditsCanvas = $CreditsCanvas
@onready var label = $MenuCanvas/Label

@onready var hostButton = $MenuCanvas/HostButton
@onready var joinButton = $MenuCanvas/JoinButton
@onready var cancelButton = $MenuCanvas/CancelButton
@onready var startGameButton = $MenuCanvas/StartGameButton

@onready var roomCodeText = $MenuCanvas/RoomCode
@onready var usernameText = $MenuCanvas/Username

@onready var notificationLabel = $MenuCanvas/NotificationLabel
#endregion

# Idle: neither joining nor hosting
# idle can go to join or to host via respective buttons
# 
# hosting: from idle using host button. can go back to idle by pressing cancel
# 
# joining: from idle using join button. can go back to idle by pressing cancel
#


const MAX_PLAYERS = 2
const MENU_DESIGN_SIZE = Vector2(1920.0, 1080.0)

var peer

enum LobbyState {
	IDLE,
	HOSTING,
	JOINING
}

var state = LobbyState.IDLE

func _ready():
	if not resized.is_connected(_fit_menu_to_window):
		resized.connect(_fit_menu_to_window)
	_fit_menu_to_window()
	call_deferred("_fit_menu_to_window")
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


func _fit_menu_to_window() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return

	var menu_scale = max(
		size.x / MENU_DESIGN_SIZE.x,
		size.y / MENU_DESIGN_SIZE.y
	)
	menuCanvas.scale = Vector2.ONE * menu_scale
	menuCanvas.position = (size - MENU_DESIGN_SIZE * menu_scale) * 0.5
	creditsCanvas.scale = Vector2.ONE * menu_scale
	creditsCanvas.position = (size - MENU_DESIGN_SIZE * menu_scale) * 0.5

func init_menu():
	menuCanvas.visible = true
	creditsCanvas.visible = false
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


func _on_credits_button_pressed() -> void:
	menuCanvas.visible = false
	creditsCanvas.visible = true


func _on_credits_back_button_pressed() -> void:
	creditsCanvas.visible = false
	menuCanvas.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if creditsCanvas.visible and event.is_action_pressed("ui_cancel"):
		_on_credits_back_button_pressed()
		get_viewport().set_input_as_handled()


func _on_cancel_button_button_down() -> void:
	label.text = ""
	state = LobbyState.IDLE
	cancelButton.disabled = true
	startGameButton.disabled = true
	hostButton.disabled = false
	joinButton.disabled = false


	close_server()

	pass # Replace with function body.


func _on_join_button_button_down() -> void:
	# TODO: check if server is "busy" or full
	if usernameText.text == "":
		print("Please enter a username!")
		label.text = "Please enter a username!"
		return

	hostButton.disabled = true
	joinButton.disabled = true
	

	cancelButton.disabled = false
	state = LobbyState.JOINING
	startGameButton.disabled = false

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

	# TODO: create server
	hostGame()
	SendPlayerData(usernameText.text, multiplayer.get_unique_id())

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
		GameManager.game_in_progress = true
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
	# check if game is in progress
	if multiplayer.is_server():
		var sender_id = multiplayer.get_unique_id()
		if sender_id == 0:
			sender_id = id

		if GameManager.game_in_progress:
			print("Game already in progress. Rejecting new player: ", playerName)
			reject_connection.rpc_id(id, "Game already in progress. Please try again later.")
			get_tree().create_timer(0.2).timeout.connect(func():
				if multiplayer.get_peers().has(sender_id):
					multiplayer.disconnect_peer(sender_id)
			)
			return

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
	GameManager.player_ids.erase(id)
	print("Player disconnected: %d" % id)

	#TODO: restart server game state if all players disconnected
	pass

func connected_to_server():
	# note: since this passes 1, does that mean its server authority?
	SendPlayerData.rpc_id(1, usernameText.text, multiplayer.get_unique_id())

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

@rpc("any_peer", "call_remote", "reliable")
func reject_connection(reason: String) -> void:
	print("Connection rejected by server: %s" % reason)
	label.text = "Connection rejected by server: %s" % reason

	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	init_menu()
#endregion
