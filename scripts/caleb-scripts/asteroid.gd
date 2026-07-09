extends RigidBody2D

const SPEED = 50.0
const LIFETIME = 5.0


var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var torque: float
func _ready():
	# delete the bullet after LIFETIME seconds
	await get_tree().create_timer(LIFETIME).timeout

	print("Deleted bullet ", name)
	queue_free()

	torque = randf_range(-10, 10)
	pass

func _physics_process(_delta: float) -> void:
	add_constant_torque(torque)

	var forward_direction = Vector2.UP.rotated(rotation)
	add_constant_central_force(forward_direction * SPEED)

# func _physics_process(delta: float) -> void:
# 	# ONLY the server processes the movement physics
# 	if multiplayer.is_server():
# 		var dir = Vector2(1, 0).rotated(rotation)
# 		velocity = SPEED * dir
		
# 		if not is_on_floor():
# 			velocity.y += gravity * delta

# 		move_and_slide()

# 		for i in range(get_slide_collision_count()):
# 			var collision = get_slide_collision(i)
# 			if collision:
# 				var collider = collision.get_collider()
# 				if collider and collider.is_in_group("Players"):
# 					print("Bullet ", name, " hit player ", collider.name)
# 				queue_free()
# 	else:
# 		pass