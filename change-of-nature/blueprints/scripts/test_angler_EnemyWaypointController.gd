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
	# Start at world origin
	global_position = Vector3.ZERO
	print("Test angler spawned at world origin")
	
	# Find and sort all waypoints in the scene
	find_and_sort_waypoints()

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
	"""Find all nodes with 'enemy_waypoints' group and sort by distance from world origin"""
	var waypoint_nodes = get_tree().get_nodes_in_group("enemy_waypoints")
	
	if waypoint_nodes.is_empty():
		print("No enemy waypoints found in scene tree")
		# Create fallback waypoints if none found
		create_fallback_waypoints()
		return
	
	print("Found ", waypoint_nodes.size(), " waypoint nodes")
	
	# Create array of waypoint data with positions and distances
	var waypoint_data = []
	for node in waypoint_nodes:
		if node is Node3D:
			var distance = Vector3.ZERO.distance_to(node.global_position)
			waypoint_data.append({
				"position": node.global_position,
				"distance": distance,
				"node": node
			})
	
	# Sort by distance (closest to furthest from world origin)
	waypoint_data.sort_custom(func(a, b): return a.distance < b.distance)
	
	# Extract sorted positions
	sorted_waypoints.clear()
	for data in waypoint_data:
		sorted_waypoints.append(data.position)
		print("Waypoint: ", data.node.name, " at ", data.position, " (distance: ", data.distance, ")")
	
	current_waypoint_index = 0
	print("Sorted ", sorted_waypoints.size(), " waypoints by distance from origin")

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
	
