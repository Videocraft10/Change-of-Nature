extends Node3D

@export var room_scenes: Array[PackedScene]

var RoomGenerated = false

# Called when the node enters the scene tree for the first time.
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
		RoomGenerated = true
		
		# 1. Pick a random scene from the array.
		var random_room_scene = room_scenes.pick_random()
		
		# 2. Create an instance of the chosen room.
		var room_instance = random_room_scene.instantiate()
		
		# 3. Add the new room to the scene tree.
		# We add it to the parent of the door so it doesn't move with the door.
		get_parent().add_child(room_instance)

		# 4. Find a connection point in the room
		var connection_point = null
		var connection_points = []
		
		# Get all nodes in the room with the group "connection_points"
		for node in room_instance.get_children():
			if node.is_in_group("connection_points"):
				connection_points.append(node)
		
		# Check if we found any connection points
		if connection_points.size() > 0:
			# Select the first connection point (or you could pick randomly)
			connection_point = connection_points[0]
			print("Found connection point in room:", connection_point.name)
			
			# 5. Align the room so the connection point matches our door position
			# Calculate the position offset
			var door_global_transform = $DoorConnectionPoint.global_transform
			room_instance.global_transform = room_instance.global_transform.translated(
				door_global_transform.origin - connection_point.global_transform.origin
			)
		else:
			print("No connection points found in the room!")
			# Fall back to the previous behavior
			room_instance.global_transform = $DoorConnectionPoint.global_transform
	
	elif body.is_in_group("player") and RoomGenerated:
		print("Room already Generated")
	pass # Replace with function body.
