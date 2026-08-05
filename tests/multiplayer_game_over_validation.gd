extends SceneTree

const GAMEPLAY_SCENE_PATH = "res://scenes/keyboard_tracing_prototype.tscn"
const TEST_PORT = 18910
const CONNECTION_TIMEOUT_SECONDS = 5.0
const CLEANUP_TIMEOUT_SECONDS = 5.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if "--server" in arguments:
		await _run_server()
	elif "--client" in arguments:
		await _run_client()
	else:
		push_error("Pass --server or --client to the multiplayer game-over validation.")
		quit(1)


func _run_server() -> void:
	var peer := ENetMultiplayerPeer.new()
	var create_error: int = peer.create_server(TEST_PORT, 1)
	if create_error != OK:
		push_error("Could not create validation server: %s" % error_string(create_error))
		quit(1)
		return

	root.multiplayer.multiplayer_peer = peer
	if not await _wait_for_remote_peer():
		push_error("Validation client did not connect to the server.")
		quit(1)
		return

	# Give the client time to create /root/Level before spawning replicated children.
	await create_timer(0.5).timeout
	var gameplay: Node = load(GAMEPLAY_SCENE_PATH).instantiate()
	root.add_child(gameplay)
	await create_timer(0.75).timeout

	gameplay.check_game_over()
	if not await _wait_for_level_cleanup():
		push_error("Server Level survived the multiplayer game-over transition.")
		quit(1)
		return

	print("Multiplayer game-over server validation passed.")
	quit(0)


func _run_client() -> void:
	var peer := ENetMultiplayerPeer.new()
	var create_error: int = peer.create_client("127.0.0.1", TEST_PORT)
	if create_error != OK:
		push_error("Could not create validation client: %s" % error_string(create_error))
		quit(1)
		return

	root.multiplayer.multiplayer_peer = peer
	if not await _wait_for_connection(peer):
		push_error("Validation client could not connect to the server.")
		quit(1)
		return

	var gameplay: Node = load(GAMEPLAY_SCENE_PATH).instantiate()
	root.add_child(gameplay)

	if not await _wait_for_level_cleanup():
		push_error("Client Level survived the multiplayer game-over transition.")
		quit(1)
		return

	print("Multiplayer game-over client validation passed.")
	quit(0)


func _wait_for_remote_peer() -> bool:
	var timeout_at: int = Time.get_ticks_msec() + int(CONNECTION_TIMEOUT_SECONDS * 1000.0)
	while Time.get_ticks_msec() < timeout_at:
		if not root.multiplayer.get_peers().is_empty():
			return true
		await create_timer(0.05).timeout
	return false


func _wait_for_connection(peer: ENetMultiplayerPeer) -> bool:
	var timeout_at: int = Time.get_ticks_msec() + int(CONNECTION_TIMEOUT_SECONDS * 1000.0)
	while Time.get_ticks_msec() < timeout_at:
		if peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			return true
		if peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
			return false
		await create_timer(0.05).timeout
	return false


func _wait_for_level_cleanup() -> bool:
	var timeout_at: int = Time.get_ticks_msec() + int(CLEANUP_TIMEOUT_SECONDS * 1000.0)
	while Time.get_ticks_msec() < timeout_at:
		if root.get_node_or_null("Level") == null:
			return true
		await create_timer(0.05).timeout
	return false
