extends Node3D

signal door_opened(door_node: Node3D, room_instance: Node3D)

@export var room_files: Array[PackedScene]
@export var room_scene_paths: Array[String] = []  # Use paths instead for self-reference
@export var TurnRoomL: Array[String] = []  # Path to left turn rooms
@export var TurnRoomR: Array[String] = []  # Path to right turn rooms
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
		var level_script = find_level_script()
		
		# Check if we should generate a turn room
		if level_script and level_script.NextRoomTurn:
			print("NextRoomTurn is true, checking turn room logic...")
			
			var selected_turn_room = ""
			
			# Check LastTurnL and LastTurnR states
			if not level_script.LastTurnL and not level_script.LastTurnR:
				# Both false, pick randomly
				if randi() % 2 == 0 and not TurnRoomL.is_empty():
					selected_turn_room = TurnRoomL.pick_random()
					level_script.LastTurnL = true
					print("Selected left turn room, set LastTurnL to true")
				elif not TurnRoomR.is_empty():
					selected_turn_room = TurnRoomR.pick_random()
					level_script.LastTurnR = true
					print("Selected right turn room, set LastTurnR to true")
			elif level_script.LastTurnL and not level_script.LastTurnR:
				# Left is true, choose right
				if not TurnRoomR.is_empty():
					selected_turn_room = TurnRoomR.pick_random()
					level_script.LastTurnR = true
					print("LastTurnL was true, selected right turn room, set LastTurnR to true")
			elif not level_script.LastTurnL and level_script.LastTurnR:
				# Right is true, choose left
				if not TurnRoomL.is_empty():
					selected_turn_room = TurnRoomL.pick_random()
					level_script.LastTurnL = true
					print("LastTurnR was true, selected left turn room, set LastTurnL to true")
			elif level_script.LastTurnL and level_script.LastTurnR:
				# Both true, reset both to false and pick randomly
				level_script.LastTurnL = false
				level_script.LastTurnR = false
				print("Both LastTurnL and LastTurnR were true, reset both to false")
				if randi() % 2 == 0 and not TurnRoomL.is_empty():
					selected_turn_room = TurnRoomL.pick_random()
					level_script.LastTurnL = true
					print("Selected left turn room, set LastTurnL to true")
				elif not TurnRoomR.is_empty():
					selected_turn_room = TurnRoomR.pick_random()
					level_script.LastTurnR = true
					print("Selected right turn room, set LastTurnR to true")
			
			# Load the selected turn room
			if not selected_turn_room.is_empty():
				var scene_resource = load(selected_turn_room) as PackedScene
				if scene_resource:
					room_instance = scene_resource.instantiate()
					print("Loaded turn room:", selected_turn_room)
					# Reset turn room weight back to 0 after loading a turn room
					level_script.TurnRoomWeight = 0
					print("Reset TurnRoomWeight to 0 after generating turn room")
				else:
					print("Failed to load turn room from path:", selected_turn_room)
					return
			else:
				print("No valid turn room paths configured!")
				return
		else:
			# Regular room generation logic
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
		
		# Check if room pre-generation is needed for front-spawn enemy
		if level_script and level_script.should_pre_generate_room:
			print("Front-spawn enemy ready! Pre-generating next room...")
			level_script.should_pre_generate_room = false  # Reset the flag
			
			# Build available scenes list (same as above selection logic)
			var next_available_scenes = []
			for scene in room_files:
				if scene != null:
					next_available_scenes.append(scene)
			for path in room_scene_paths:
				if not path.is_empty():
					var scene_resource = load(path) as PackedScene
					if scene_resource:
						next_available_scenes.append(scene_resource)
			
			if not next_available_scenes.is_empty():
				var next_scene = next_available_scenes.pick_random()
				var next_room_instance = next_scene.instantiate()
				# Add to same parent so it's part of the level
				target_parent.add_child(next_room_instance)
				
				# Find ALL connection points in the generated room (recursively search all descendants)
				var all_connection_points = []
				var nodes_to_check = [room_instance]
				while nodes_to_check.size() > 0:
					var node = nodes_to_check.pop_front()
					if node.is_in_group("connection_points"):
						all_connection_points.append(node)
					for child in node.get_children():
						nodes_to_check.append(child)
				
				print("Found ", all_connection_points.size(), " total connection points in generated room")
				
				# Find a connection point that is NOT the one we already used for entry
				var src_conn = null
				for conn in all_connection_points:
					if conn != connection_point:
						src_conn = conn
						print("Selected unused connection point: ", conn.name)
						break
				
				if src_conn != null:
					# Find a connection point on the next room to align to (search recursively)
					var next_conn = null
					var next_nodes_to_check = [next_room_instance]
					while next_nodes_to_check.size() > 0:
						var node = next_nodes_to_check.pop_front()
						if node.is_in_group("connection_points"):
							next_conn = node
							break
						for child in node.get_children():
							next_nodes_to_check.append(child)
					
					if next_conn != null:
						# Align next room so its connection matches the source connection
						# First translate to match positions
						var position_offset = src_conn.global_transform.origin - next_conn.global_transform.origin
						next_room_instance.global_transform = next_room_instance.global_transform.translated(position_offset)
						
						# Then rotate to match orientations
						var door_euler_2 = src_conn.global_transform.basis.get_euler()
						var conn_euler_2 = next_conn.global_transform.basis.get_euler()
						var rotation_diff_2 = door_euler_2 - conn_euler_2
						next_room_instance.rotate_object_local(Vector3(1, 0, 0), rotation_diff_2.x)
						next_room_instance.rotate_object_local(Vector3(0, 1, 0), rotation_diff_2.y)
						next_room_instance.rotate_object_local(Vector3(0, 0, 1), rotation_diff_2.z)
						print("Pre-generated next room for front-spawn enemy, attached to: ", src_conn.name, " at position: ", src_conn.global_transform.origin)
						
						# Now trigger the front-spawn enemy
						print("Room pre-generated, now spawning front-spawn enemy...")
						level_script.spawn_front_enemy()
					else:
						print("Pre-generated next room but it has no connection points")
				else:
					print("No unused connection point found in generated room (only has entry point)")
			else:
				print("No available room scenes to pre-generate next room")
		
		# Emit the signal after room generation is complete
		door_opened.emit(self, room_instance)
	
	elif body.is_in_group("player") and RoomGenerated:
		print("Room already Generated")
