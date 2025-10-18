extends Node3D
class_name TestAnglerEnemyWaypointController

@export var move_speed: float = 2.0
@export var rotation_speed: float = 5.0
@export var waypoint_reach_distance: float = 1.0
@export var speed_per_waypoint: float = 0.1  # Speed increase per waypoint (10% by default)
@export var final_speed: float = 50.0  # Speed to use when more than 50 waypoints

var sorted_waypoints: Array[Vector3] = []
var current_waypoint_index: int = 0
var has_finished_waypoints: bool = false
var extra_movement_timer: float = 0.0
var extra_movement_duration: float = 5.0
var movement_direction: Vector3
var base_move_speed: float = 2.0  # Store original move speed
var is_speed_boosted: bool = false  # Track if currently boosted
var is_front_spawn: bool = false  # Track if this is a front-spawn enemy
var is_moving_to_last_waypoint: bool = false  # Track if moving to starting position
var move_backwards: bool = false  # Track if moving backwards through waypoints

func _ready():
	# Always spawn at world origin
	global_position = Vector3.ZERO
	print("Test angler spawned at world origin.")
	
	# Find and sort all waypoints in the scene
	find_and_sort_waypoints_from_position(global_position)
	
	# Scale speed based on total waypoints
	update_speed_based_on_waypoints()

func set_spawn_at_last_waypoint():
	"""Configure this enemy to spawn from the front (last waypoint, moving backwards)"""
	print("Configuring enemy for FRONT-SPAWN mode")
	is_front_spawn = true
	is_moving_to_last_waypoint = true
	move_backwards = true
	
	# Disable kill and trauma zones during initial movement to last waypoint
	disable_danger_zones()
	
	# Set waypoint index to last waypoint
	if not sorted_waypoints.is_empty():
		current_waypoint_index = sorted_waypoints.size() - 1
		print("Starting at last waypoint (", current_waypoint_index, ") for front-spawn")

func disable_danger_zones():
	"""Disable kill area and trauma zones"""
	if has_node("kill_area"):
		$kill_area.monitoring = false
		$kill_area.monitorable = false
		print("Disabled kill area")
	
	if has_node("trauma_causer"):
		$trauma_causer.set_process(false)
		print("Disabled trauma causer")

func enable_danger_zones():
	"""Re-enable kill area and trauma zones"""
	if has_node("kill_area"):
		$kill_area.monitoring = true
		$kill_area.monitorable = true
		print("Enabled kill area")
	
	if has_node("trauma_causer"):
		$trauma_causer.set_process(true)
		print("Enabled trauma causer")

func _process(delta):
	# Trauma causer functionality from test_angler.gd - only if player is not in freefly
	if has_node("trauma_causer"):
		var player = get_tree().get_first_node_in_group("player")
		var player_freeflying = player and "freeflying" in player and player.freeflying
		
		# Only cause trauma if player is not in freefly mode
		if not player_freeflying:
			$trauma_causer.cause_trauma()
			$trauma_causer.trauma_reduction_rate()
		else:
			# Still call trauma reduction to allow trauma to decrease while in freefly
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
			# Update speed based on new waypoint count
			update_speed_based_on_waypoints()

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

func update_speed_based_on_waypoints():
	"""Update movement speed based on current number of waypoints"""
	if sorted_waypoints.size() > 0:
		var total_waypoints = sorted_waypoints.size()
		
		# If more than 50 waypoints, use final_speed and skip scaling
		if total_waypoints > 50:
			move_speed = final_speed
			base_move_speed = final_speed
			print("Total waypoints: ", total_waypoints, " (>50) - Using final speed: ", move_speed)
		else:
			# Normal scaling for 50 or fewer waypoints
			var base_speed = 2.0
			var speed_multiplier = 1.0 + (total_waypoints - 1) * speed_per_waypoint
			move_speed = base_speed * speed_multiplier
			base_move_speed = move_speed  # Store the base speed for this waypoint count
			print("Total waypoints: ", total_waypoints, " - Adjusted speed: ", move_speed, " (multiplier: ", speed_multiplier, ", per waypoint: ", speed_per_waypoint, ")")
	else:
		move_speed = 2.0
		base_move_speed = 2.0
		print("No waypoints found, using base speed.")



func move_through_waypoints(delta):
	if sorted_waypoints.is_empty():
		print("No waypoints available, despawning")
		queue_free()
		return
	
	# Calculate remaining waypoints
	var remaining_waypoints = sorted_waypoints.size() - current_waypoint_index
	var total_waypoints = sorted_waypoints.size()
	var target_waypoint = sorted_waypoints[current_waypoint_index]
	
	# Teleport mode: Jump to waypoints until 20 remain (works for ALL waypoint counts)
	if remaining_waypoints > 20:
		# Teleport mode: instantly jump to waypoints
		if not is_speed_boosted:
			print("Teleport mode activated! Total waypoints: ", total_waypoints, ", Remaining: ", remaining_waypoints)
			is_speed_boosted = true
		
		# Directly teleport to the waypoint instead of moving
		global_position = target_waypoint
		
		# Instantly mark as reached and move to next/previous waypoint
		print("Teleported to waypoint ", current_waypoint_index + 1, " of ", sorted_waypoints.size())
		
		# Handle front-spawn: if we've reached last waypoint during initial positioning
		if is_front_spawn and is_moving_to_last_waypoint:
			print("FRONT-SPAWN (Teleport): Reached last waypoint! Enabling danger zones and moving backwards")
			enable_danger_zones()
			is_moving_to_last_waypoint = false
		
		# Move to next/previous waypoint based on direction
		if move_backwards:
			current_waypoint_index -= 1
			# Check if we've reached the first waypoint (moving backwards)
			if current_waypoint_index < 0:
				print("Front-spawn enemy reached beginning (waypoint 0)")
				has_finished_waypoints = true
				if sorted_waypoints.size() >= 2:
					var first_waypoint = sorted_waypoints[0]
					var second_waypoint = sorted_waypoints[1]
					movement_direction = (first_waypoint - second_waypoint).normalized()
				else:
					movement_direction = -Vector3.FORWARD
		else:
			current_waypoint_index += 1
			# Check if we've reached the last waypoint (moving forwards)
			if current_waypoint_index >= sorted_waypoints.size():
				check_for_new_waypoints()
				
				if current_waypoint_index >= sorted_waypoints.size():
					has_finished_waypoints = true
					if sorted_waypoints.size() >= 2:
						var last_waypoint = sorted_waypoints[sorted_waypoints.size() - 1]
						var second_last_waypoint = sorted_waypoints[sorted_waypoints.size() - 2]
						movement_direction = (last_waypoint - second_last_waypoint).normalized()
					else:
						movement_direction = Vector3.FORWARD
					print("Test angler finished all waypoints, moving straight for 5 seconds")
		return  # Skip normal movement this frame
	
	# Normal movement mode (20 or fewer waypoints remaining)
	if is_speed_boosted:
		print("Teleport mode deactivated. Remaining waypoints: ", remaining_waypoints)
		is_speed_boosted = false
	
	# Speed ramping: Only apply if total waypoints <= 50
	if total_waypoints <= 50:
		move_speed = base_move_speed  # Use calculated speed based on total waypoints
	else:
		move_speed = final_speed  # Use final_speed for >50 waypoints
	
	# Use normal movement for non-teleport mode
	move_towards_position(target_waypoint, move_speed, delta)
	
	# Check if reached waypoint
	if global_position.distance_to(target_waypoint) < waypoint_reach_distance:
		print("Reached waypoint ", current_waypoint_index + 1, " of ", sorted_waypoints.size())
		
		# Handle front-spawn: if we've reached last waypoint during initial positioning
		if is_front_spawn and is_moving_to_last_waypoint:
			print("FRONT-SPAWN: Reached last waypoint! Enabling danger zones and moving backwards")
			enable_danger_zones()
			is_moving_to_last_waypoint = false
			# Already set to move backwards, continue from current position
		
		# Move to next/previous waypoint based on direction
		if move_backwards:
			current_waypoint_index -= 1
			# Check if we've reached the first waypoint (moving backwards)
			if current_waypoint_index < 0:
				print("Front-spawn enemy reached beginning (waypoint 0)")
				has_finished_waypoints = true
				# Set movement direction for straight movement
				if sorted_waypoints.size() >= 2:
					var first_waypoint = sorted_waypoints[0]
					var second_waypoint = sorted_waypoints[1]
					movement_direction = (first_waypoint - second_waypoint).normalized()
				else:
					movement_direction = -Vector3.FORWARD
		else:
			current_waypoint_index += 1
			# Check if we've reached the last waypoint (moving forwards)
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


func _on_kill_area_area_entered(_area: Area3D) -> void:
	#print("Kill area triggered by: ", area.name, " from parent: ", area.get_parent().name)
	pass
	
func _on_kill_area_body_entered(body: Node3D) -> void: # For Player detection
	#print("Kill area triggered by body: ", body.name)
	
	# Check if the body is the player
	if body.is_in_group("player"):
		# Check if player is in locker, safe area, or freefly mode
		var is_in_locker = "in_locker" in body and body.in_locker
		var is_safe = "safe" in body and body.safe
		var is_freeflying = "freeflying" in body and body.freeflying
		
		# Only execute death logic if player is NOT safe, NOT in locker, and NOT freeflying
		if not is_safe and not is_in_locker and not is_freeflying:
			print("dead")
			get_tree().change_scene_to_file("res://temp/lv_dead_title.tscn")
		else:
			if is_freeflying:
				print("Player is in freefly mode - protected from angler")
			elif is_in_locker:
				print("Player is in locker - protected from angler")
			elif is_safe:
				print("Player is in safe area - no damage taken")
			else:
				print("Player is protected - no damage taken")
