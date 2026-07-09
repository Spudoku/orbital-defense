extends Node2D

@export var AsteroidScene: PackedScene

@export var spawn_noise: AudioStream

@onready var audio_player = $AudioStreamPlayer2D
@onready var clientLabel = $ClientLabel

func _ready():
	if multiplayer.is_server():
		clientLabel.text = "I am the host/server"
	else:
		$Timer.stop()
		print("I'm not the server, stopped timer")
		clientLabel.text = "I am a client. My id is: " + str(multiplayer.get_unique_id())
	# else:
	# 	$Timer.start()
	# 	print("I'm the server, started timer")
	# 	spawn_asteroid()


# TODO: make this serverside
@rpc("any_peer", "call_local")
func spawn_asteroid():
	if AsteroidScene and multiplayer.is_server():
		var asteroid = AsteroidScene.instantiate()
		var random_x = randf_range(0, get_viewport().size.x)
		var random_y = randf_range(0, get_viewport().size.y)
		asteroid.global_position = Vector2(random_x, random_y)
		asteroid.rotation = randf_range(0, 2 * PI)
		var id = ResourceUID.create_id()
		asteroid.name = "Asteroid_" + str(id) # don't forget to use unique names!
		# asteroid.set_id(id)

		add_child(asteroid)

		# reset noise and play it
		audio_player.stop()
		audio_player.stream = spawn_noise
		audio_player.play()
		
		remove_after_delay(asteroid, 5) # Remove the asteroid after 2-6 seconds

func remove_after_delay(node: Node, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if is_instance_valid(node):
		node.queue_free()


func _on_timer_timeout() -> void:
	spawn_asteroid()
	pass # Replace with function body.
