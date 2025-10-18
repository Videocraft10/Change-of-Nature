extends Node3D

var music_player: AudioStreamPlayer = null
var song_cred_control: Control = null

@export_category("Gen Settings")
@export var TurnRoomWeight = 0
@export var FinalRoomWeight = 0
@export var ForceNextRoom: String

@export_category("Monster Settings")
@export var TestBaddieWeight = 0

# Enemy spawn configuration with weighted chances
# Each entry has a scene path and a weight (percentage)
# Weights should add up to 100 for clarity, but will be normalized automatically
# can_in_front: if true, this enemy can spawn in pre-generated rooms (coming from front)
@export var enemy_spawn_list: Array[Dictionary] = [
	{
		"scene_path": "res://blueprints/scenes/test_angler.tscn",
		"weight": 75,
		"can_in_front": true
	},
	# Example for additional enemy types:
	# {
	# 	"scene_path": "res://blueprints/scenes/other_enemy.tscn",
	# 	"weight": 25,
	# 	"can_in_front": false
	# }
]

# Next Room Vars
var NextRoomTurn = false
var NextRoomFinal = false
var NextRoomIsForced = false

#Turn Checks (so rooms dont clip)
var LastTurnL = false
var LastTurnR = false

# Room Weights
var CurrentTurnRoomWeight: int = 0
var CurrentFinalRoomWeight: int = 0

# Monster Weights
var SpawnMonster = false
var CurrentMonsterWeight: int = 0
var spawn_fail_multiplier: int = 1  # Doubles each time spawn fails
var max_monster_weight: int = 100  # Maximum weight needed to spawn, decreases with each spawn

# Front-spawn tracking for next enemy
var next_enemy_is_front_spawn: bool = false  # Whether the NEXT enemy will spawn from front
var front_spawn_weight: int = 0  # Weight that builds up for front-spawn eligibility
var front_spawn_queued: bool = false  # Set to true when front-spawn is ready and waiting
var should_pre_generate_room: bool = false  # Set to true when next door should pre-generate

# Door Numbering
var current_door_number = 0

# Music control
var first_door_opened = false
var first_angler_spawned = false

# Signal for when enemy spawns - lights can connect to this
signal enemy_spawned

func _ready() -> void:
	# Wait for the scene to be fully loaded, then increment door number
	# This ensures the first preplaced door gets 00, and generated doors start at 01
	await get_tree().process_frame
	current_door_number += 1
	print("World loaded, door number incremented to: ", current_door_number)

func get_music_player() -> AudioStreamPlayer:
	if music_player == null:
		if has_node("Active Casualties - Viromalous"):
			music_player = get_node("Active Casualties - Viromalous") as AudioStreamPlayer
		else:
			print("Warning: 'Intro' node not found")
	return music_player

func get_song_cred_control() -> Control:
	"""Safely get the song credit control node"""
	if song_cred_control == null:
		if has_node("CanvasLayer/SongCredControl"):
			song_cred_control = get_node("CanvasLayer/SongCredControl") as Control
		else:
			print("Warning: 'CanvasLayer/SongCredControl' node not found")
	return song_cred_control

func get_current_door_number() -> String:
	# Format as two-digit string (01, 02, 03, etc.)
	return "%02d" % current_door_number

func _on_dr_testing_gen_door_door_opened(door_node: Node3D, room_instance: Node3D) -> void: 
	# Play music on first door opening
	if not first_door_opened:
		first_door_opened = true
		var player = get_music_player()
		if player:
			player.play()
			print("Intro music started playing")
		
		# Start song credit fade sequence
		fade_song_credits()
	
	# Increment door number first so the newly generated room gets the next number
	current_door_number += 1
	print("Door number incremented to: ", current_door_number)
	
	## Check Gen Settings
	if ForceNextRoom:
		NextRoomIsForced = true
	else:
		NextRoomIsForced = false
	
	if TurnRoomWeight >= 100:
		NextRoomTurn = true
	else:
		NextRoomTurn = false
		
	if FinalRoomWeight >= 100:
		NextRoomFinal = true
	else:
		NextRoomFinal = false

	if CurrentMonsterWeight >= max_monster_weight:
		SpawnMonster = true
	else:
		SpawnMonster = false

	# Add random weights when door is opened
	var final_room_increase = randi_range(1, 4)
	var turn_room_increase = randi_range(1, 20)
	var base_monster_increase = randi_range(1, 20)
	var current_monster_increase = base_monster_increase * spawn_fail_multiplier
	var front_spawn_increase = randi_range(5, 15)  # Weight increase for front-spawn
	
	CurrentMonsterWeight += current_monster_increase
	FinalRoomWeight += final_room_increase
	TurnRoomWeight += turn_room_increase
	front_spawn_weight += front_spawn_increase
	
	print("Increased FinalRoomWeight by ", final_room_increase, " (now: ", FinalRoomWeight, ")")
	print("Increased TurnRoomWeight by ", turn_room_increase, " (now: ", TurnRoomWeight, ")")
	print("Increased CurrentMonsterWeight by ", current_monster_increase, " (base: ", base_monster_increase, " x", spawn_fail_multiplier, ") (now: ", CurrentMonsterWeight, ")")
	print("Increased front_spawn_weight by ", front_spawn_increase, " (now: ", front_spawn_weight, ")")
	
	# Check if front-spawn weight has reached threshold AND next enemy is flagged for front-spawn
	if front_spawn_weight >= 100 and next_enemy_is_front_spawn and not front_spawn_queued:
		front_spawn_queued = true
		should_pre_generate_room = true
		print("Front-spawn READY - when monster weight hits 100, next door will pre-generate room!")
	elif front_spawn_weight >= 100 and next_enemy_is_front_spawn:
		print("Front-spawn already queued, waiting for monster spawn...")
	elif next_enemy_is_front_spawn:
		print("Next enemy flagged for front-spawn, waiting for front_spawn_weight to reach 100 (", front_spawn_weight, "/100)")

	# Try to spawn enemy after door is opened
	try_spawn_enemy_after_door()

	# Handle forced room logic - you can modify the door's ForceNextRoom here if needed
	# For example: door_node.ForceNextRoom = "res://some/special/room.tscn"
	
	print("Door opened: ", door_node.name, " - Room generated: ", room_instance.name)

func try_spawn_enemy_after_door():
	# Check if enemy weight is over max threshold
	if CurrentMonsterWeight >= max_monster_weight:
		# If front-spawn is queued, trigger room pre-generation BEFORE spawning
		if front_spawn_queued:
			print("Monster weight reached 100 with front-spawn queued! Triggering room pre-generation...")
			should_pre_generate_room = true
			# Note: The actual spawn will happen after the next door opens and room is pre-generated
			return  # Don't spawn yet, wait for room to be pre-generated

		# 50% chance to spawn
		if randf() < 0.5:
			# Reduce max weight for future spawns
			var weight_reduction = randi_range(0, 10)
			max_monster_weight -= weight_reduction
			# Ensure it doesn't go below a minimum threshold
			max_monster_weight = max(max_monster_weight, 20)
			
			print("Spawning enemy! Monster weight was: ", CurrentMonsterWeight, " / ", max_monster_weight + weight_reduction)
			print("Max monster weight reduced by ", weight_reduction, " (now: ", max_monster_weight, ")")
			
			# Reset the weight and multiplier on successful spawn
			CurrentMonsterWeight = 0
			SpawnMonster = false
			spawn_fail_multiplier = 1  # Reset multiplier on success
			
			# Check if front-spawn is queued for THIS spawn
			var spawn_from_front = front_spawn_queued
			
			# Select enemy based on weighted probabilities (filter for front-spawn if needed)
			var enemy_scene_path = select_random_enemy_scene(spawn_from_front)
			if ResourceLoader.exists(enemy_scene_path):
				var enemy_scene = load(enemy_scene_path)
				var enemy_instance = enemy_scene.instantiate()
				
				# Add to current scene FIRST
				get_tree().current_scene.add_child(enemy_instance)
				
				# THEN set position after it's in the tree
				enemy_instance.global_position = Vector3.ZERO
				
				# If spawning from front, configure enemy to start at last waypoint
				if spawn_from_front:
					if enemy_instance.has_method("set_spawn_at_last_waypoint"):
						enemy_instance.set_spawn_at_last_waypoint()
						print("Enemy configured to spawn from FRONT (last waypoint, moving backwards)")
					else:
						print("Warning: Enemy doesn't support front spawning, spawning normally")
					
					# Reset front-spawn flags after using them
					front_spawn_queued = false
					front_spawn_weight = 0
					next_enemy_is_front_spawn = false
					print("Front-spawn used, flags reset")
				
				# Emit signal to make all lights flicker
				enemy_spawned.emit()
				
				# Fade out music on first angler spawn
				if not first_angler_spawned:
					first_angler_spawned = true
					fade_out_music()
				
				print("Enemy spawned - multiplier reset to 1")
				
				# After spawning, decide if NEXT enemy will be front-spawn (100% chance DEBUG - revert to 0.1 later)
				if not next_enemy_is_front_spawn:  # Only roll if not already set
					if randf() < 1.0:
						next_enemy_is_front_spawn = true
						print("NEXT enemy will be a front-spawn (100% chance triggered)!")
					else:
						next_enemy_is_front_spawn = false
						print("Next enemy will be a normal back-spawn")
			else:
				print("Enemy scene not found at: ", enemy_scene_path)
		else:
			# Failed spawn - double the multiplier for next time
			spawn_fail_multiplier *= 2
			CurrentMonsterWeight = 0
			SpawnMonster = false
			print("Enemy spawn chance failed (50%), weight reset, multiplier increased to x", spawn_fail_multiplier)

func spawn_front_enemy():
	"""Spawn a front-spawn enemy at the last waypoint"""
	print("Spawning front-spawn enemy...")
	
	# Reduce max weight for future spawns
	var weight_reduction = randi_range(0, 10)
	max_monster_weight -= weight_reduction
	max_monster_weight = max(max_monster_weight, 20)
	
	# Reset weights
	CurrentMonsterWeight = 0
	SpawnMonster = false
	spawn_fail_multiplier = 1
	
	# Select enemy from front-capable enemies only
	var enemy_scene_path = select_random_enemy_scene(true)
	if ResourceLoader.exists(enemy_scene_path):
		var enemy_scene = load(enemy_scene_path)
		var enemy_instance = enemy_scene.instantiate()
		
		# Add to current scene
		get_tree().current_scene.add_child(enemy_instance)
		
		# Set position at world origin first
		enemy_instance.global_position = Vector3.ZERO
		
		# Configure enemy to spawn at last waypoint and move backwards
		if enemy_instance.has_method("set_spawn_at_last_waypoint"):
			enemy_instance.set_spawn_at_last_waypoint()
			print("Enemy configured to spawn from FRONT (will teleport to last waypoint, move backwards)")
		else:
			print("Warning: Enemy doesn't support front spawning")
		
		# Reset front-spawn flags
		front_spawn_queued = false
		front_spawn_weight = 0
		next_enemy_is_front_spawn = false
		print("Front-spawn complete, flags reset")
		
		# Emit signal to make all lights flicker
		enemy_spawned.emit()
		
		# Fade out music on first angler spawn
		if not first_angler_spawned:
			first_angler_spawned = true
			fade_out_music()
		
		print("Front-spawn enemy spawned - multiplier reset to 1")
		
		# After spawning, decide if NEXT enemy will be front-spawn (100% chance DEBUG - revert to 0.1 later)
		if randf() < 1.0:
			next_enemy_is_front_spawn = true
			print("NEXT enemy will be a front-spawn (100% chance triggered)!")
		else:
			next_enemy_is_front_spawn = false
			print("Next enemy will be a normal back-spawn")
	else:
		print("Front-spawn enemy scene not found at: ", enemy_scene_path)

func fade_out_music():
	if music_player:
		var tween = create_tween()
		tween.tween_property(music_player, "volume_db", -80, 2.0)
		print("Fading out music over 2 seconds")

func select_random_enemy_scene(filter_front_spawn: bool = false) -> String:
	"""Select a random enemy scene path based on weighted probabilities
	
	Args:
		filter_front_spawn: If true, only select enemies with can_in_front = true
	"""
	# Filter the enemy list if needed
	var available_enemies = []
	if filter_front_spawn:
		for enemy_entry in enemy_spawn_list:
			if enemy_entry.has("can_in_front") and enemy_entry["can_in_front"]:
				available_enemies.append(enemy_entry)
		
		if available_enemies.is_empty():
			print("Warning: No enemies with can_in_front=true, falling back to all enemies")
			available_enemies = enemy_spawn_list
	else:
		available_enemies = enemy_spawn_list
	
	if available_enemies.is_empty():
		print("Warning: enemy_spawn_list is empty, returning default test_angler")
		return "res://blueprints/scenes/test_angler.tscn"
	
	# Calculate total weight
	var total_weight = 0
	for enemy_entry in available_enemies:
		if enemy_entry.has("weight"):
			total_weight += enemy_entry["weight"]
	
	if total_weight <= 0:
		print("Warning: total weight is 0, using first enemy in list")
		return available_enemies[0]["scene_path"]
	
	# Pick a random value between 0 and total_weight
	var random_value = randf() * total_weight
	
	# Find which enemy this value corresponds to
	var cumulative_weight = 0
	for enemy_entry in available_enemies:
		if enemy_entry.has("weight") and enemy_entry.has("scene_path"):
			cumulative_weight += enemy_entry["weight"]
			if random_value <= cumulative_weight:
				var front_spawn_str = " (front-spawn)" if filter_front_spawn else ""
				print("Selected enemy", front_spawn_str, ": ", enemy_entry["scene_path"], " (weight: ", enemy_entry["weight"], "/", total_weight, ")")
				return enemy_entry["scene_path"]
	
	# Fallback to first enemy
	print("Warning: failed to select enemy, using first in list")
	return available_enemies[0]["scene_path"]

func fade_song_credits():
	"""Fade in song credits, stay for 5 seconds, fade out, then delete CanvasLayer"""
	var cred_control = get_song_cred_control()
	if not cred_control:
		print("No song credit control found")
		return
	
	# Make visible and set alpha to 0 for fade in
	cred_control.visible = true
	cred_control.modulate.a = 0.0
	
	print("Fading in song credits over 2 seconds...")
	# Fade in over 2 seconds
	var tween = create_tween()
	tween.tween_property(cred_control, "modulate:a", 1.0, 2.0)
	await tween.finished
	
	print("Song credits visible, waiting 5 seconds...")
	# Stay visible for 5 seconds
	await get_tree().create_timer(5.0).timeout
	
	print("Fading out song credits over 2 seconds...")
	# Fade out over 2 seconds
	tween = create_tween()
	tween.tween_property(cred_control, "modulate:a", 0.0, 2.0)
	await tween.finished
	
	# Delete the CanvasLayer
	if has_node("CanvasLayer"):
		var canvas_layer = get_node("CanvasLayer")
		canvas_layer.queue_free()
		print("CanvasLayer deleted after song credits fade out")

var FogDelay = false

func _on_fog_off_collider_area_entered(_area: Area3D) -> void:
	if _area.is_in_group("player"):
		if FogDelay:
			pass
		else:
			$WorldEnvironment.environment.fog_enabled = !$WorldEnvironment.environment.fog_enabled
			$DirectionalLight3D.visible = !$DirectionalLight3D.visible
			FogDelay = true
			print("Fog Toggled")


func _on_fog_on_collider_area_entered(_area: Area3D) -> void:
	if _area.is_in_group("player"):
		if not FogDelay:
			pass
		else:
			$WorldEnvironment.environment.fog_enabled = !$WorldEnvironment.environment.fog_enabled
			$DirectionalLight3D.visible = !$DirectionalLight3D.visible
			FogDelay = false
			print("Fog Toggled")
