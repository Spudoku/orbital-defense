extends Node

signal master_volume_changed(volume_percent: float)

var Players = {}
var player_ids = []
var _active_laser_peers: Dictionary = {}

var master_volume_percent: float = 100.0

var player1: int # this player controls horizontal movement
var player2: int # this player controls vertical movement

var game_in_progress: bool = false


func _ready() -> void:
	var master_bus_index: int = AudioServer.get_bus_index("Master")
	if master_bus_index < 0:
		return

	if AudioServer.is_bus_mute(master_bus_index):
		master_volume_percent = 0.0
	else:
		master_volume_percent = db_to_linear(
			AudioServer.get_bus_volume_db(master_bus_index)
		) * 100.0


func set_master_volume(volume_percent: float) -> void:
	master_volume_percent = clampf(volume_percent, 0.0, 100.0)
	var master_bus_index: int = AudioServer.get_bus_index("Master")
	if master_bus_index >= 0:
		var linear_volume: float = master_volume_percent / 100.0
		AudioServer.set_bus_mute(master_bus_index, is_zero_approx(linear_volume))
		if linear_volume > 0.0:
			AudioServer.set_bus_volume_db(master_bus_index, linear_to_db(linear_volume))

	master_volume_changed.emit(master_volume_percent)

@rpc("any_peer", "call_local", "reliable")
func sync_controls(p1: int, p2: int) -> void:
	player1 = p1
	player2 = p2
	var level = get_tree().root.get_node_or_null("Level")
	if level:
		level.updated_roles = false

@rpc("any_peer", "call_local", "reliable")
func clear_game_state() -> void:
	player1 = -1
	player2 = -1
	game_in_progress = false
	Players.clear()
	player_ids.clear()
	_active_laser_peers.clear()
