extends Node

var Players = {}
var player_ids = []

var player1: int # this player controls horizontal movement
var player2: int # this player controls vertical movement


@rpc("any_peer", "call_local", "reliable")
func sync_controls(p1: int, p2: int) -> void:
	player1 = p1
	player2 = p2