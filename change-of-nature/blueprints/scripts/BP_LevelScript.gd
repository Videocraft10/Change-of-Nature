extends Node3D

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
var CurrentTurnRoomWeight = 0
var CurrentFinalRoomWeight = 0

# Monster Weights
var SpawnMonster = false
var CurrentMonsterWeight = 0
var spawn_fail_multiplier = 1  # Doubles each time spawn fails

# Door Numbering
var current_door_number = 0

# Signal for when enemy spawns - lights can connect to this
signal enemy_spawned

func _ready() -> void:
	# Wait for the scene to be fully loaded, then increment door number
	# This ensures the first preplaced door gets 00, and generated doors start at 01
	await get_tree().process_frame
	current_door_number += 1
	print("World loaded, door number incremented to: ", current_door_number)

func get_current_door_number() -> String:
	# Format as two-digit string (01, 02, 03, etc.)
	return "%02d" % current_door_number

func _on_dr_testing_gen_door_door_opened(door_node: Node3D, room_instance: Node3D) -> void: 
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

	if CurrentMonsterWeight >= 100:
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
	# Check if enemy weight is over 100
	if CurrentMonsterWeight >= 100:
		# 50% chance to spawn
		if randf() < 0.5:
			print("Spawning enemy! Monster weight was: ", CurrentMonsterWeight)
			
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
				
				print("Enemy spawned at world origin - multiplier reset to 1")
			else:
				print("Enemy scene not found at: ", enemy_scene_path)
		else:
			# Failed spawn - double the multiplier for next time
			spawn_fail_multiplier *= 2
			CurrentMonsterWeight = 0
			SpawnMonster = false
			print("Enemy spawn chance failed (50%), weight reset, multiplier increased to x", spawn_fail_multiplier)

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
