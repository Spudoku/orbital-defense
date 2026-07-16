extends Node

var Players = {}
var player_ids = []
var _active_laser_peers: Dictionary = {}

var player1: int # this player controls horizontal movement
var player2: int # this player controls vertical movement


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
	Players.clear()
	player_ids.clear()
