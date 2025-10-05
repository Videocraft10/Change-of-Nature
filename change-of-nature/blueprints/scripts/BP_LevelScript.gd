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

# Door Numbering
var current_door_number = 1

func get_current_door_number() -> String:
	# Format as two-digit string (01, 02, 03, etc.)
	return "%02d" % current_door_number

func _on_dr_testing_gen_door_door_opened(door_node: Node3D, room_instance: Node3D) -> void: 
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
	var current_monster_increase = randi_range(1, 20)
	
	CurrentMonsterWeight += current_monster_increase
	FinalRoomWeight += final_room_increase
	TurnRoomWeight += turn_room_increase
	print("Increased FinalRoomWeight by ", final_room_increase, " (now: ", FinalRoomWeight, ")")
	print("Increased TurnRoomWeight by ", turn_room_increase, " (now: ", TurnRoomWeight, ")")
	print("Increased CurrentMonsterWeight by ", current_monster_increase, " (now: ", CurrentMonsterWeight, ")")

	# Handle forced room logic - you can modify the door's ForceNextRoom here if needed
	# For example: door_node.ForceNextRoom = "res://some/special/room.tscn"
	
	# Increment door number for next room
	current_door_number += 1
	print("Door number incremented to: ", current_door_number)
	
	print("Door opened: ", door_node.name, " - Room generated: ", room_instance.name)
