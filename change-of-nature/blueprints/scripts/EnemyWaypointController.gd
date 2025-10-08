extends Node3D
class_name EnemyWaypointController

@export var move_speed: float = 2.0
@export var rotation_speed: float = 5.0
@export var waypoint_reach_distance: float = 1.0

# Detection system
@export var detection_range: float = 10.0
@export var chase_speed: float = 4.0
@export var line_of_sight_check: bool = true

var current_waypoints: Array[Vector3] = []
var current_waypoint_index: int = 0
var player_node: Node3D = null
var is_chasing: bool = false

# State management
enum AIState { PATROLLING, CHASING, SEARCHING, RETURNING }
var current_state: AIState = AIState.PATROLLING
var last_known_player_position: Vector3
var search_timer: float = 0.0
var search_duration: float = 5.0

func _ready():
	player_node = get_tree().get_first_node_in_group("player")
	
	# Connect to level script door opening signal
	connect_to_level_script()
	
	generate_room_waypoints()

func connect_to_level_script():
	# Find BP_LevelScript in the scene
	var level_script = find_level_script()
	if level_script:
		# We'll check for spawning when doors are opened
		print("Enemy connected to level script")

func find_level_script() -> Node:
	# Look for BP_LevelScript in the scene tree
	var current_scene = get_tree().current_scene
	return find_node_with_script(current_scene, "BP_LevelScript.gd")

func find_node_with_script(node: Node, script_name: String) -> Node:
	if node.get_script() != null:
		var script_path = node.get_script().get_path()
		if script_path.ends_with(script_name):
			return node
	
	for child in node.get_children():
		var result = find_node_with_script(child, script_name)
		if result:
			return result
	
	return null

# Static function to handle enemy spawning
static func try_spawn_enemy() -> Node3D:
	var level_script = _find_level_script_static()
	if not level_script:
		return null
	
	# Check if enemy weight is over 100
	if level_script.CurrentMonsterWeight >= 100:
		# 50% chance to spawn
		if randf() < 0.5:
			print("Spawning enemy! Monster weight was: ", level_script.CurrentMonsterWeight)
			
			# Reset the weight
			level_script.CurrentMonsterWeight = 0
			
			# Load and spawn enemy at world origin
			var enemy_scene = preload("res://blueprints/scenes/test_angler.tscn")  # Adjust path
			var enemy_instance = enemy_scene.instantiate()
			enemy_instance.global_position = Vector3.ZERO
			
			# Add to current scene
			var current_scene = Engine.get_main_loop().current_scene
			current_scene.add_child(enemy_instance)
			
			print("Enemy spawned at world origin")
			return enemy_instance
		else:
			# Reset weight even if not spawning (failed chance)
			level_script.CurrentMonsterWeight = 0
			print("Enemy spawn chance failed, weight reset")
	
	return null

static func _find_level_script_static() -> Node:
	var current_scene = Engine.get_main_loop().current_scene
	return _find_node_with_script_static(current_scene, "BP_LevelScript.gd")

static func _find_node_with_script_static(node: Node, script_name: String) -> Node:
	if node.get_script() != null:
		var script_path = node.get_script().get_path()
		if script_path.ends_with(script_name):
			return node
	
	for child in node.get_children():
		var result = _find_node_with_script_static(child, script_name)
		if result:
			return result
	
	return null

func _process(delta):
	match current_state:
		AIState.PATROLLING:
			patrol_waypoints(delta)
			check_player_detection()
		AIState.CHASING:
			chase_player(delta)
			check_player_lost()
		AIState.SEARCHING:
			search_for_player(delta)
		AIState.RETURNING:
			return_to_patrol(delta)

func generate_room_waypoints():
	"""Generate waypoints for the current room"""
	var current_room = find_current_room()
	if not current_room:
		return
		
	current_waypoints.clear()
	
	# Method 1: Use predefined waypoint nodes
	var waypoint_nodes = []
	find_waypoint_nodes(current_room, waypoint_nodes)
	
	if waypoint_nodes.size() > 0:
		for waypoint in waypoint_nodes:
			current_waypoints.append(waypoint.global_position)
	else:
		# Method 2: Generate waypoints automatically
		generate_automatic_waypoints(current_room)
	
	current_waypoint_index = 0
	print("Generated ", current_waypoints.size(), " waypoints for room")

func find_waypoint_nodes(node: Node, waypoints: Array):
	"""Recursively find all waypoint nodes"""
	if node.is_in_group("enemy_waypoints"):
		waypoints.append(node)
	
	for child in node.get_children():
		find_waypoint_nodes(child, waypoints)

func generate_automatic_waypoints(room: Node3D):
	"""Automatically generate waypoints based on room layout"""
	var room_bounds = get_room_bounds(room)
	var room_center = room_bounds.get_center()
	var room_size = room_bounds.size
	
	# Create a grid of waypoints
	var waypoint_spacing = 5.0
	var x_count = max(2, int(room_size.x / waypoint_spacing))
	var z_count = max(2, int(room_size.z / waypoint_spacing))
	
	for x in range(x_count):
		for z in range(z_count):
			var waypoint_pos = Vector3(
				room_bounds.position.x + (x + 0.5) * (room_size.x / x_count),
				room_center.y,
				room_bounds.position.z + (z + 0.5) * (room_size.z / z_count)
			)
			
			# Check if waypoint is valid (not in walls, etc.)
			if is_waypoint_valid(waypoint_pos):
				current_waypoints.append(waypoint_pos)

func get_room_bounds(room: Node3D) -> AABB:
	"""Get the bounding box of a room"""
	var bounds = AABB()
	var first = true
	
	# Find all MeshInstance3D nodes to calculate bounds
	var mesh_instances = []
	find_mesh_instances(room, mesh_instances)
	
	for mesh_instance in mesh_instances:
		var mesh_bounds = mesh_instance.get_aabb()
		mesh_bounds = mesh_instance.transform * mesh_bounds
		
		if first:
			bounds = mesh_bounds
			first = false
		else:
			bounds = bounds.merge(mesh_bounds)
	
	return bounds

func find_mesh_instances(node: Node, instances: Array):
	if node is MeshInstance3D:
		instances.append(node)
	
	for child in node.get_children():
		find_mesh_instances(child, instances)

func is_waypoint_valid(pos: Vector3) -> bool:
	"""Check if a waypoint position is valid (no obstacles)"""
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		pos + Vector3.UP * 2.0,
		pos - Vector3.UP * 0.5
	)
	
	var result = space_state.intersect_ray(query)
	return result.is_empty() == false  # Should hit floor

func find_current_room() -> Node3D:
	"""Find which room the enemy is currently in"""
	var rooms = get_tree().get_nodes_in_group("rooms")
	for room in rooms:
		var distance = room.global_position.distance_to(global_position)
		if distance < 25.0:  # Adjust based on room size
			return room
	return null

func patrol_waypoints(delta):
	if current_waypoints.is_empty():
		generate_room_waypoints()
		return
	
	var target_waypoint = current_waypoints[current_waypoint_index]
	move_towards_position(target_waypoint, move_speed, delta)
	
	# Check if reached waypoint
	if global_position.distance_to(target_waypoint) < waypoint_reach_distance:
		current_waypoint_index = (current_waypoint_index + 1) % current_waypoints.size()
		
		# Check if we moved to a new room
		check_room_transition()

func check_room_transition():
	"""Check if enemy moved to a new room and update waypoints"""
	var new_room = find_current_room()
	if new_room:
		# Simple check: if far from current waypoints, regenerate
		var avg_waypoint_dist = 0.0
		for waypoint in current_waypoints:
			avg_waypoint_dist += global_position.distance_to(waypoint)
		avg_waypoint_dist /= current_waypoints.size()
		
		if avg_waypoint_dist > 15.0:  # Threshold for new room
			generate_room_waypoints()

func move_towards_position(target_pos: Vector3, speed: float, delta):
	var direction = (target_pos - global_position).normalized()
	global_position += direction * speed * delta
	
	# Smooth rotation
	if direction.length() > 0.1:
		var target_transform = transform.looking_at(global_position + direction, Vector3.UP)
		transform = transform.interpolate_with(target_transform, rotation_speed * delta)

# Player detection and chasing
func check_player_detection():
	if not player_node:
		return
		
	var distance_to_player = global_position.distance_to(player_node.global_position)
	
	if distance_to_player <= detection_range:
		if line_of_sight_check:
			if has_line_of_sight_to_player():
				start_chase()
		else:
			start_chase()

func has_line_of_sight_to_player() -> bool:
	if not player_node:
		return false
		
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 1.5,
		player_node.global_position + Vector3.UP * 1.0
	)
	
	# Exclude the enemy and player from raycast
	# query.exclude = []  # Add RIDs to exclude if needed
	
	var result = space_state.intersect_ray(query)
	return result.is_empty()  # No obstacles = clear line of sight

func start_chase():
	current_state = AIState.CHASING
	last_known_player_position = player_node.global_position
	print("Enemy started chasing!")

func chase_player(delta):
	if not player_node:
		current_state = AIState.SEARCHING
		return
	
	# Update last known position if we can see the player
	if has_line_of_sight_to_player():
		last_known_player_position = player_node.global_position
	
	move_towards_position(last_known_player_position, chase_speed, delta)

func check_player_lost():
	if not player_node:
		current_state = AIState.SEARCHING
		return
		
	var distance_to_player = global_position.distance_to(player_node.global_position)
	
	if distance_to_player > detection_range * 1.5:  # Hysteresis
		if not has_line_of_sight_to_player():
			current_state = AIState.SEARCHING
			search_timer = 0.0

func search_for_player(delta):
	search_timer += delta
	
	# Search around last known position
	move_towards_position(last_known_player_position, move_speed * 0.7, delta)
	
	# Check if we found the player again
	if player_node and global_position.distance_to(player_node.global_position) <= detection_range:
		if has_line_of_sight_to_player():
			start_chase()
			return
	
	# Give up searching after duration
	if search_timer >= search_duration:
		current_state = AIState.RETURNING

func return_to_patrol(delta):
	# Find nearest waypoint and return to patrol
	if current_waypoints.is_empty():
		generate_room_waypoints()
		current_state = AIState.PATROLLING
		return
	
	# Find closest waypoint
	var closest_waypoint_index = 0
	var closest_distance = INF
	
	for i in range(current_waypoints.size()):
		var distance = global_position.distance_to(current_waypoints[i])
		if distance < closest_distance:
			closest_distance = distance
			closest_waypoint_index = i
	
	current_waypoint_index = closest_waypoint_index
	move_towards_position(current_waypoints[current_waypoint_index], move_speed, delta)
	
	# Return to patrol when close enough
	if global_position.distance_to(current_waypoints[current_waypoint_index]) < waypoint_reach_distance:
		current_state = AIState.PATROLLING
		print("Enemy returned to patrol")
