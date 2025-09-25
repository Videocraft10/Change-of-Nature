extends Node3D

@export var room_scenes: Array[PackedScene]

var RoomGenerated = false

func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_bp_small_door_body_entered(body: Node3D) -> void:
	# Check if the body is the player and if a room hasn't been generated yet.
	if body.is_in_group("player") and not RoomGenerated:
		# Ensure the room_scenes array is not empty.
		if room_scenes.is_empty():
			print("No room scenes assigned to the door!")
			return

		print("Generating Room at door's location.")
		
		# 1. Pick a random scene from the array.
		var random_room_scene = room_scenes.pick_random()
		
		# 2. Create an instance of the chosen room.
		var room_instance = random_room_scene.instantiate()
		
		# 3. Add the new room to the scene tree.
		# We add it to the parent of the door so it doesn't move with the door.
		get_parent().add_child(room_instance)

		# 4. Since the room's root node is the connection point, 
		# we just need to match it with the door's connection point
		var door_transform = $DoorConnectionPoint.global_transform
		
		# 5. Set the room's global position and rotation to match the door connection point, but do not scale
		var new_basis = door_transform.basis.orthonormalized() # Remove any scaling from the basis
		room_instance.global_transform = Transform3D(new_basis, door_transform.origin)

		# Optional: Apply 180-degree rotation if the rooms need to face each other
		# Uncomment if needed:
		# room_instance.rotate_y(PI)

		# Get the filename from the resource path (without extension)
		var room_name = random_room_scene.resource_path.get_file().get_basename()
		print("Room '" + room_name + "' Generated.")
		
