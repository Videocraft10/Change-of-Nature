extends Node3D
class_name TestAnglerEnemyWaypointController

@export var move_speed: float = 2.0
@export var rotation_speed: float = 5.0
@export var waypoint_reach_distance: float = 1.0

var sorted_waypoints: Array[Vector3] = []
var current_waypoint_index: int = 0
var has_finished_waypoints: bool = false
var extra_movement_timer: float = 0.0
var extra_movement_duration: float = 5.0
var movement_direction: Vector3

func _ready():
	# Find spawn position 15 rooms behind the player
	var spawn_position = find_spawn_position_behind_player()
	global_position = spawn_position
	print("Test angler spawned at: ", spawn_position)
	
	# Adjust speed based on number of generated rooms
	adjust_speed_based_on_rooms()
	
	# Find and sort all waypoints in the scene
	find_and_sort_waypoints_from_position(spawn_position)

func _process(delta):
	# Trauma causer functionality from test_angler.gd
	if has_node("trauma_causer"):
		$trauma_causer.cause_trauma()
		$trauma_causer.trauma_reduction_rate()
	
	if has_finished_waypoints:
		# Move straight for 5 seconds then despawn
		move_straight_and_despawn(delta)
	else:
		# Move through waypoints
		move_through_waypoints(delta)

func find_and_sort_waypoints():
	"""Legacy function - redirects to position-based waypoint finding"""
	find_and_sort_waypoints_from_position(global_position)



func check_for_new_waypoints():
	"""Check for newly generated waypoints and add them to the path"""
	var current_waypoint_nodes = get_tree().get_nodes_in_group("enemy_waypoints")
	var current_waypoint_count = current_waypoint_nodes.size()
	var existing_waypoint_count = sorted_waypoints.size()
	
	# If we have more waypoints in the scene than in our path, add the new ones
	if current_waypoint_count > existing_waypoint_count:
		print("Found ", current_waypoint_count - existing_waypoint_count, " new waypoints! Updating path...")
		
		# Get positions of waypoints we already have
		var existing_positions = []
		for pos in sorted_waypoints:
			existing_positions.append(pos)
		
		# Find new waypoints that aren't in our existing path
		var new_waypoints = []
		for node in current_waypoint_nodes:
			if node is Node3D:
				var found_existing = false
				for existing_pos in existing_positions:
					if existing_pos.distance_to(node.global_position) < 0.1:  # Close enough to be the same waypoint
						found_existing = true
						break
				
				if not found_existing:
					new_waypoints.append({
						"position": node.global_position,
						"node": node
					})
		
		# Add new waypoints using nearest neighbor from current position
		if not new_waypoints.is_empty():
			add_new_waypoints_to_path(new_waypoints)
			# Update speed based on new room count
			adjust_speed_based_on_rooms()

func add_new_waypoints_to_path(new_waypoints: Array):
	"""Add new waypoints to the existing path using nearest neighbor"""
	var current_position = global_position
	var remaining_new_waypoints = new_waypoints.duplicate()
	
	# Add new waypoints by finding nearest unvisited ones
	while not remaining_new_waypoints.is_empty():
		var closest_index = 0
		var closest_distance = INF
		
		# Find closest new waypoint to current position
		for i in range(remaining_new_waypoints.size()):
			var distance = current_position.distance_to(remaining_new_waypoints[i].position)
			if distance < closest_distance:
				closest_distance = distance
				closest_index = i
		
		# Add closest waypoint to path
		var next_waypoint = remaining_new_waypoints[closest_index]
		sorted_waypoints.append(next_waypoint.position)
		current_position = next_waypoint.position
		remaining_new_waypoints.remove_at(closest_index)
		print("Added new waypoint: ", next_waypoint.node.name, " at ", next_waypoint.position)

func create_fallback_waypoints():
	"""Create basic waypoints if no enemy_waypoints group nodes found"""
	sorted_waypoints = [
		Vector3(0, 0, 5),
		Vector3(5, 0, 5),
		Vector3(5, 0, 10),
		Vector3(0, 0, 10),
		Vector3(-5, 0, 10),
		Vector3(-5, 0, 15) 
	]
	print("Created fallback waypoints")

func find_spawn_position_behind_player() -> Vector3:
	"""Find a spawn position approximately 15 rooms behind the player's current room"""
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		print("No player found, spawning at world origin")
		return Vector3.ZERO
	
	var player_position = player.global_position
	print("Player found at: ", player_position)
	
	# Get all room nodes
	var rooms = get_tree().get_nodes_in_group("rooms")
	if rooms.is_empty():
		print("No rooms found, spawning at world origin")
		return Vector3.ZERO
	
	# Find the room closest to the player (current room)
	var closest_room = null
	var closest_distance = INF
	for room in rooms:
		if room is Node3D:
			var distance = player_position.distance_to(room.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_room = room
	
	if not closest_room:
		print("No valid rooms found, spawning at world origin")
		return Vector3.ZERO
	
	print("Player's current room: ", closest_room.name, " at ", closest_room.global_position)
	
	# Sort rooms by distance from current room
	var sorted_rooms = []
	for room in rooms:
		if room is Node3D and room != closest_room:
			var distance = closest_room.global_position.distance_to(room.global_position)
			sorted_rooms.append({
				"room": room,
				"distance": distance
			})
	
	# Sort by distance (closest to furthest from player's room)
	sorted_rooms.sort_custom(func(a, b): return a.distance < b.distance)
	
	# Try to find a room 15 positions back, or use the furthest room available
	var target_room_index = min(14, sorted_rooms.size() - 1)  # 15 rooms back (0-indexed)
	
	if target_room_index >= 0 and target_room_index < sorted_rooms.size():
		var spawn_room = sorted_rooms[target_room_index].room
		print("Spawning in room: ", spawn_room.name, " (", target_room_index + 1, " rooms behind player)")
		return spawn_room.global_position
	else:
		print("Not enough rooms found, spawning at furthest available room or origin")
		if sorted_rooms.size() > 0:
			return sorted_rooms[-1].room.global_position
		return Vector3.ZERO

func find_and_sort_waypoints_from_position(start_position: Vector3):
	"""Find all nodes with 'enemy_waypoints' group and create path from given position"""
	var waypoint_nodes = get_tree().get_nodes_in_group("enemy_waypoints")
	
	if waypoint_nodes.is_empty():
		print("No enemy waypoints found in scene tree")
		# Create fallback waypoints if none found
		create_fallback_waypoints()
		return
	
	print("Found ", waypoint_nodes.size(), " waypoint nodes")
	
	# Store all waypoints with their data
	var all_waypoints = []
	for node in waypoint_nodes:
		if node is Node3D:
			all_waypoints.append({
				"position": node.global_position,
				"node": node
			})
	
	# Build path using nearest neighbor algorithm starting from spawn position
	sorted_waypoints.clear()
	build_nearest_neighbor_path_from_position(all_waypoints, start_position)
	
	current_waypoint_index = 0
	print("Built path with ", sorted_waypoints.size(), " waypoints from spawn position")

func build_nearest_neighbor_path_from_position(all_waypoints: Array, start_pos: Vector3):
	"""Build waypoint path using nearest neighbor algorithm starting from given position"""
	if all_waypoints.is_empty():
		return
	
	var remaining_waypoints = all_waypoints.duplicate()
	var current_position = start_pos
	
	# Build path by always choosing the nearest unvisited waypoint
	while not remaining_waypoints.is_empty():
		var closest_index = 0
		var closest_distance = INF
		
		# Find closest remaining waypoint to current position
		for i in range(remaining_waypoints.size()):
			var distance = current_position.distance_to(remaining_waypoints[i].position)
			if distance < closest_distance:
				closest_distance = distance
				closest_index = i
		
		# Add closest waypoint to path and remove from remaining
		var next_waypoint = remaining_waypoints[closest_index]
		sorted_waypoints.append(next_waypoint.position)
		current_position = next_waypoint.position
		remaining_waypoints.remove_at(closest_index)
		print("Next waypoint: ", next_waypoint.node.name, " at ", next_waypoint.position, " (distance: ", closest_distance, ")")

func adjust_speed_based_on_rooms():
	"""Adjust movement speed based on the number of rooms currently in the scene"""
	# Count rooms in the scene (assuming they're in a 'rooms' group or have 'room' in their name)
	var room_count = 0
	
	# Method 1: Try to find rooms by group
	var rooms_by_group = get_tree().get_nodes_in_group("rooms")
	if not rooms_by_group.is_empty():
		room_count = rooms_by_group.size()
	else:
		# Method 2: Count nodes with "room" in their name as fallback
		var current_scene = get_tree().current_scene
		room_count = count_room_nodes(current_scene)
	
	# Calculate speed multiplier (starts at base speed, increases by 0.5 per room)
	var base_speed = 2.0  # Original move_speed
	var speed_multiplier = 1.0 + (room_count - 1) * 0.5  # Each additional room adds 50% speed
	move_speed = base_speed * speed_multiplier
	
	print("Found ", room_count, " rooms. Adjusted speed to: ", move_speed, " (multiplier: ", speed_multiplier, ")")

func count_room_nodes(node: Node) -> int:
	# Recursively count nodes that appear to be rooms
	var count = 0
	
	# Check if this node looks like a room (has "room" in name or is tagged as room)
	if "room" in node.name.to_lower() or "dr_" in node.name.to_lower():
		count += 1
	
	# Recursively check children
	for child in node.get_children():
		count += count_room_nodes(child)
	
	return count

func move_through_waypoints(delta):
	if sorted_waypoints.is_empty():
		print("No waypoints available, despawning")
		queue_free()
		return
	
	var target_waypoint = sorted_waypoints[current_waypoint_index]
	move_towards_position(target_waypoint, move_speed, delta)
	
	# Check if reached waypoint
	if global_position.distance_to(target_waypoint) < waypoint_reach_distance:
		print("Reached waypoint ", current_waypoint_index + 1, " of ", sorted_waypoints.size())
		current_waypoint_index += 1
		
		# Check if we've reached the last waypoint
		if current_waypoint_index >= sorted_waypoints.size():
			# Check for new waypoints before finishing
			check_for_new_waypoints()
			
			# If still no more waypoints after checking, then finish
			if current_waypoint_index >= sorted_waypoints.size():
				has_finished_waypoints = true
				# Set movement direction for straight movement
				if sorted_waypoints.size() >= 2:
					var last_waypoint = sorted_waypoints[sorted_waypoints.size() - 1]
					var second_last_waypoint = sorted_waypoints[sorted_waypoints.size() - 2]
					movement_direction = (last_waypoint - second_last_waypoint).normalized()
				else:
					movement_direction = Vector3.FORWARD  # Default direction
				print("Test angler finished all waypoints, moving straight for 5 seconds")

func move_straight_and_despawn(delta):
	# Move straight in the last direction
	global_position += movement_direction * move_speed * delta
	
	# Rotate to face movement direction
	if movement_direction.length() > 0.1:
		var target_transform = transform.looking_at(global_position + movement_direction, Vector3.UP)
		transform = transform.interpolate_with(target_transform, rotation_speed * delta)
	
	# Increment timer
	extra_movement_timer += delta
	
	# Despawn after 5 seconds
	if extra_movement_timer >= extra_movement_duration:
		print("Test angler despawning after 5 seconds of straight movement")
		queue_free()

func move_towards_position(target_pos: Vector3, speed: float, delta):
	var direction = (target_pos - global_position).normalized()
	global_position += direction * speed * delta
	
	# Smooth rotation
	if direction.length() > 0.1:
		var target_transform = transform.looking_at(global_position + direction, Vector3.UP)
		transform = transform.interpolate_with(target_transform, rotation_speed * delta)


func _on_kill_area_area_entered(area: Area3D) -> void:
	print("Kill area triggered by: ", area.name, " from parent: ", area.get_parent().name)
	
	# Check if the area belongs to player or if the parent is the player
	var target_node = area.get_parent()
	if area.is_in_group("player") or (target_node and target_node.is_in_group("player")):
		print("Player detected! (Teleporting disabled for now)")
		# Teleporting temporarily disabled
		#if target_node:
			#target_node.global_position = Vector3.ZERO
			# Reset player velocity if it's a CharacterBody3D
			#if target_node is CharacterBody3D:
				#target_node.velocity = Vector3.ZERO
	
