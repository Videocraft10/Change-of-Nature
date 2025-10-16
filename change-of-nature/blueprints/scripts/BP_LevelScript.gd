extends Node3D

var music_player: AudioStreamPlayer = null
var song_cred_control: Control = null

@export_category("Gen Settings")
@export var TurnRoomWeight = 0
@export var FinalRoomWeight = 0
@export var ForceNextRoom: String

@export_category("Monster Settings")
@export var TestBaddieWeight = 0

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
	
	CurrentMonsterWeight += current_monster_increase
	FinalRoomWeight += final_room_increase
	TurnRoomWeight += turn_room_increase
	print("Increased FinalRoomWeight by ", final_room_increase, " (now: ", FinalRoomWeight, ")")
	print("Increased TurnRoomWeight by ", turn_room_increase, " (now: ", TurnRoomWeight, ")")
	print("Increased CurrentMonsterWeight by ", current_monster_increase, " (base: ", base_monster_increase, " x", spawn_fail_multiplier, ") (now: ", CurrentMonsterWeight, ")")

	# Try to spawn enemy after door is opened
	try_spawn_enemy_after_door()

	# Handle forced room logic - you can modify the door's ForceNextRoom here if needed
	# For example: door_node.ForceNextRoom = "res://some/special/room.tscn"
	
	print("Door opened: ", door_node.name, " - Room generated: ", room_instance.name)

func try_spawn_enemy_after_door():
	# Check if enemy weight is over max threshold
	if CurrentMonsterWeight >= max_monster_weight:
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
			
			# Try to load enemy scene - adjust path as needed
			var enemy_scene_path = "res://blueprints/scenes/test_angler.tscn"
			if ResourceLoader.exists(enemy_scene_path):
				var enemy_scene = load(enemy_scene_path)
				var enemy_instance = enemy_scene.instantiate()
				
				# Add to current scene FIRST
				get_tree().current_scene.add_child(enemy_instance)
				
				# THEN set position after it's in the tree
				enemy_instance.global_position = Vector3.ZERO
				
				# Emit signal to make all lights flicker
				enemy_spawned.emit()
				
				# Fade out music on first angler spawn
				if not first_angler_spawned:
					first_angler_spawned = true
					fade_out_music()
				
				print("Enemy spawned at world origin - multiplier reset to 1")
			else:
				print("Enemy scene not found at: ", enemy_scene_path)
		else:
			# Failed spawn - double the multiplier for next time
			spawn_fail_multiplier *= 2
			CurrentMonsterWeight = 0
			SpawnMonster = false
			print("Enemy spawn chance failed (50%), weight reset, multiplier increased to x", spawn_fail_multiplier)

func fade_out_music():
	# Fade out the music over 4 seconds and then stop it
	var player = get_music_player()
	if not player:
		print("No music player found")
		return
	
	print("Fading out music")
	var initial_volume = player.volume_db
	var tween = create_tween()

	# Fade from current volume to -80 dB (essentially silent) over 10 seconds
	tween.tween_property(player, "volume_db", -80.0, 10.0)
	await tween.finished
	
	# Stop the music and restore volume for potential future use
	player.stop()
	player.volume_db = initial_volume
	print("Music stopped after fade out")

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
