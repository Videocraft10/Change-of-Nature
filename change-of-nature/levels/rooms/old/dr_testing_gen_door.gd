extends Node3D

signal door_opened(door_node: Node3D, room_instance: Node3D)

@export var room_files: Array[PackedScene]
@export var room_scene_paths: Array[String] = []  # Use paths instead for self-reference
@export var FinalRoom: String

var allow_self_reference: bool = false
var current_scene_path: String = ""  # Set this to the current scene's path



var RoomGenerated = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Auto-detect current scene path if not set
	if current_scene_path.is_empty() and allow_self_reference:
		# Try to find the scene file path of THIS specific room/node
		# Look for the scene file that contains this node, not the main scene
		var node = self
		while node != null:
			if node.scene_file_path != "":
				current_scene_path = node.scene_file_path
				print("Auto-detected room scene path:", current_scene_path)
				break
			node = node.get_parent()
		
		# If we still don't have a path, this might be the root scene
		if current_scene_path.is_empty():
			print("Warning: Could not auto-detect room scene path. Please set current_scene_path manually.")
			print("Example: 'res://levels/rooms/dr_test_basic_room.tscn'")
	
	# Auto-connect to BP_LevelScript if it exists
	var level_script = find_level_script()
	if level_script and level_script.has_method("_on_dr_testing_gen_door_door_opened"):
		if not door_opened.is_connected(level_script._on_dr_testing_gen_door_door_opened):
			door_opened.connect(level_script._on_dr_testing_gen_door_door_opened)
			print("Auto-connected door signal to level script: ", name)
		else:
			print("Door signal already connected: ", name)
	else:
		print("Warning: Could not find BP_LevelScript or connection method for door: ", name)

func find_level_script() -> Node:
	# Look for BP_LevelScript in the scene tree
	var current_scene = get_tree().current_scene
	
	# First, try to find a node with BP_LevelScript script
	var nodes_to_check = [current_scene]
	
	while nodes_to_check.size() > 0:
		var node = nodes_to_check.pop_front()
		
		# Check if this node has the BP_LevelScript
		if node.get_script() != null:
			var script_path = node.get_script().get_path()
			if script_path.ends_with("BP_LevelScript.gd"):
				return node
		
		# Add children to check
		for child in node.get_children():
			nodes_to_check.append(child)
	
	return null


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_bp_small_door_body_entered(body: Node3D) -> void:
	# Check if the body is the player and if a room hasn't been generated yet.
	if body.is_in_group("player") and not RoomGenerated:
		print("Generating Room at door's location.")
		
		var room_instance: Node3D
		
		# Method 1: Use scene paths to avoid circular reference
		if allow_self_reference and not current_scene_path.is_empty():
			print("Loading self-referencing room from path:", current_scene_path)
			var scene_resource = load(current_scene_path) as PackedScene
			if scene_resource:
				room_instance = scene_resource.instantiate()
			else:
				print("Failed to load scene from path:", current_scene_path)
				return
		else:
			# Method 2: Use traditional PackedScene array
			# Combine both arrays for selection
			var available_scenes = []
			
			# Add PackedScenes
			for scene in room_files:
				if scene != null:
					available_scenes.append(scene)
			
			# Add scenes from paths
			for path in room_scene_paths:
				if not path.is_empty():
					var scene_resource = load(path) as PackedScene
					if scene_resource:
						available_scenes.append(scene_resource)
			
			if available_scenes.is_empty():
				print("No room scenes available!")
				return
			
			# Pick a random scene
			var random_scene = available_scenes.pick_random()
			room_instance = random_scene.instantiate()
		
		# 3. Add the new room to the scene tree.
		# We add it to the parent of the door so it doesn't move with the door.
		# For nested rooms, consider adding to the root level to avoid transform issues
		var target_parent = get_parent()
		# Optional: Add to scene root instead for cleaner hierarchy
		# target_parent = get_tree().current_scene
		target_parent.add_child(room_instance)

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
			var conn_point_euler = connection_point.global_transform.basis.get_euler()
			var x_rot = conn_point_euler.x
			var y_rot = conn_point_euler.y
			var z_rot = conn_point_euler.z
			print("Connection point rotation (x, y, z):", x_rot, y_rot, z_rot)
			# Calculate the difference in rotation between the connection point and the door
			var door_euler = $DoorConnectionPoint.global_transform.basis.get_euler()
			var conn_euler = connection_point.global_transform.basis.get_euler()
			var rotation_diff = door_euler - conn_euler
			print("Rotation difference (x, y, z):", rotation_diff)
			# Apply the rotation difference to the room so the connection point aligns with the door
			room_instance.rotate_object_local(Vector3(1, 0, 0), rotation_diff.x)
			room_instance.rotate_object_local(Vector3(0, 1, 0), rotation_diff.y)
			room_instance.rotate_object_local(Vector3(0, 0, 1), rotation_diff.z)
			RoomGenerated = true

		else:
			print("No connection points found in the room!")
			# Fall back to the previous behavior
			room_instance.global_transform = $DoorConnectionPoint.global_transform
			RoomGenerated = true
		
		# Emit the signal after room generation is complete
		door_opened.emit(self, room_instance)
	
	elif body.is_in_group("player") and RoomGenerated:
		print("Room already Generated")
