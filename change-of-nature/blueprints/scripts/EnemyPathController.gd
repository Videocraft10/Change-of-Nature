extends Node3D
class_name EnemyPathController

@export var move_speed: float = 2.0
@export var rotation_speed: float = 5.0
@export var transition_duration: float = 1.0

var current_path: Path3D = null
var current_path_follow: PathFollow3D = null
var is_transitioning: bool = false
var transition_tween: Tween

# Enemy detection
@export var detection_range: float = 10.0
@export var chase_speed: float = 4.0
var player_node: Node3D = null
var is_chasing: bool = false

func _ready():
	# Find the player node
	player_node = get_tree().get_first_node_in_group("player")
	
	# Connect to level script door opening signal
	connect_to_level_script()
	
	# Find initial path in current room
	find_and_setup_path()

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
	if is_transitioning:
		return
		
	# Check for player detection
	check_player_detection()
	
	if is_chasing and player_node:
		chase_player(delta)
	elif current_path_follow:
		follow_current_path(delta)

func find_and_setup_path():
	# Find Path3D in current room
	var room_node = find_current_room()
	if room_node:
		var path = room_node.get_node_or_null("EnemyPath")
		if path and path is Path3D:
			setup_path(path)

func find_current_room() -> Node3D:
	# Find which room this enemy is currently in
	var rooms = get_tree().get_nodes_in_group("rooms")
	for room in rooms:
		if room.global_position.distance_to(global_position) < 20.0:  # Adjust threshold
			return room
	return null

func setup_path(new_path: Path3D):
	if current_path == new_path:
		return
		
	var old_position = global_position
	current_path = new_path
	
	# Create or reuse PathFollow3D
	if current_path_follow:
		current_path_follow.queue_free()
	
	current_path_follow = PathFollow3D.new()
	current_path.add_child(current_path_follow)
	
	# Find closest point on new path
	var closest_offset = find_closest_offset_on_path(old_position)
	current_path_follow.progress = closest_offset
	
	# Smooth transition to new path
	transition_to_path_position(old_position)

func find_closest_offset_on_path(world_pos: Vector3) -> float:
	if not current_path or not current_path.curve:
		return 0.0
		
	var curve = current_path.curve
	var closest_offset = 0.0
	var min_distance = INF
	
	# Sample points along the curve to find closest
	for i in range(100):
		var offset = (i / 99.0) * curve.get_baked_length()
		var curve_point = current_path.to_global(curve.sample_baked(offset))
		var distance = world_pos.distance_to(curve_point)
		
		if distance < min_distance:
			min_distance = distance
			closest_offset = offset
	
	return closest_offset

func transition_to_path_position(start_pos: Vector3):
	if not current_path_follow:
		return
		
	is_transitioning = true
	var target_pos = current_path_follow.global_position
	
	# Create smooth transition
	if transition_tween:
		transition_tween.kill()
	
	transition_tween = create_tween()
	transition_tween.tween_method(
		func(pos): global_position = pos,
		start_pos,
		target_pos,
		transition_duration
	)
	
	await transition_tween.finished
	is_transitioning = false

func follow_current_path(delta):
	if not current_path_follow:
		return
		
	# Move along the path
	current_path_follow.progress += move_speed * delta
	
	# Update enemy position and rotation
	global_position = current_path_follow.global_position
	
	# Look forward along the path
	if current_path_follow.progress < current_path.curve.get_baked_length() - 0.1:
		var look_ahead_pos = current_path.curve.sample_baked(current_path_follow.progress + 1.0)
		var world_look_pos = current_path.to_global(look_ahead_pos)
		look_at_smooth(world_look_pos, delta)
	
	# Check if we need to switch to a new room's path
	if current_path_follow.progress_ratio >= 0.9:  # Near end of path
		check_for_room_transition()

func check_for_room_transition():
	var new_room = find_current_room()
	if new_room:
		var new_path = new_room.get_node_or_null("EnemyPath")
		if new_path and new_path != current_path:
			setup_path(new_path)

func look_at_smooth(target_pos: Vector3, delta):
	var direction = (target_pos - global_position).normalized()
	if direction.length() > 0.1:
		var target_transform = transform.looking_at(global_position + direction, Vector3.UP)
		transform = transform.interpolate_with(target_transform, rotation_speed * delta)

# Player detection and chasing
func check_player_detection():
	if not player_node:
		return
		
	var distance_to_player = global_position.distance_to(player_node.global_position)
	
	if distance_to_player <= detection_range and not is_chasing:
		start_chase()
	elif distance_to_player > detection_range * 1.5 and is_chasing:  # Hysteresis
		stop_chase()

func start_chase():
	is_chasing = true
	print("Enemy started chasing player!")

func stop_chase():
	is_chasing = false
	find_and_setup_path()  # Return to path following
	print("Enemy stopped chasing, returning to patrol")

func chase_player(delta):
	if not player_node:
		return
		
	var direction = (player_node.global_position - global_position).normalized()
	global_position += direction * chase_speed * delta
	look_at_smooth(player_node.global_position, delta)