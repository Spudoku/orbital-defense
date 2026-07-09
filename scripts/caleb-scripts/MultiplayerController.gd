extends Control

#region export
@export var gameScene: PackedScene

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

@export var Address = "127.0.0.1" # local server (?)
@export var port = 8910 # TODO: check port?

const MAX_PLAYERS = 2

var peer

enum LobbyState {
	IDLE,
	HOSTING,
	JOINING
}

var state = LobbyState.IDLE

func _ready():
	cancelButton.disabled = true
	startGameButton.disabled = true
	hostButton.disabled = false
	joinButton.disabled = false
	state = LobbyState.IDLE

	# server connectivity
	multiplayer.peer_connected.connect(player_connected)
	multiplayer.peer_disconnected.connect(player_disconnected)
	multiplayer.connected_to_server.connect(connected_to_server)
	multiplayer.connection_failed.connect(connection_failed)
	
	if "--server" in OS.get_cmdline_args():
		hostGame()
	pass


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
	startGameButton.disabled = true

	#TODO: connect to server
	peer = ENetMultiplayerPeer.new()
	peer.create_client(Address, port)
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.set_multiplayer_peer(peer)
	print("Joining server...")
	#TODO: send player data to server (username, id) and notify host of new player joining
	# in NotificationLabel, 

	
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
	if state != LobbyState.HOSTING:
		print("You must be hosting to start the game!")
		label.text = "You must be hosting to start the game!"
		return
	
	if usernameText.text == "":
		print("Please enter a username!")
		label.text = "Please enter a username!"
		return

	label.text = ""

	hostButton.disabled = true
	joinButton.disabled = true
	# start the game!
	startGame.rpc()
	pass # Replace with function body.


#region backend

func hostGame():
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, MAX_PLAYERS)
	

	if error != OK:
		print("Cannot host!", error)
		return
	
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)

	multiplayer.set_multiplayer_peer(peer)
	print("Waiting for players!")

	
	pass

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
		print("Disconnecting all peers...")
		for peer_id in multiplayer_peer.get_peers():
			multiplayer_peer.disconnect_peer(peer_id)
			print("Disconnected peer ", peer_id)

		multiplayer_peer.close()

		multiplayer.multiplayer_peer = null

		print("Server closed.")
	else:
		print("No multiplayer peer to close.")


#endregion
