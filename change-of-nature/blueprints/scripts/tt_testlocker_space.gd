extends Node3D

@onready var locker = $LockerSafeSpaceArea/Locker

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Add locker to a group so it can be detected by raycast
	if locker:
		locker.add_to_group("locker")

# This function will be called when the player's raycast hits this locker
func on_player_looking():
	print("Player is looking at locker: ", name)
	# Called continuously while player looks at this locker
	# You can show UI prompts here
	pass

func on_player_stop_looking():
	# Called when player looks away from this locker
	print("Player stopped looking at locker: ", name)
	# Hide UI prompts, reset highlights, etc.

func on_player_interact():
	print("Player interacted with locker: ", name)
	# Add your locker interaction code here when player presses interact button
	# For example: open locker door, enter safe space, etc.
