extends Node3D

@onready var interactable: Area3D = $Interactable
@onready var locker_2: Node3D = $Locker2
@onready var enter_loc: Node3D = $EnterLoc
@onready var exit_loc: Node3D = $ExitLoc

var player_ref = null
var is_transitioning = false
var stored_enter_rotation: Vector3  # Store the rotation when player enters

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# 75% chance to delete the locker (only 25% chance to appear)
	if randf() < 0.50:
		print("Locker deleted - random spawn chance")
		queue_free()
		return
	
	print("Locker spawned - survived random chance")
	interactable.interact = _on_interact


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func _on_interact():
	if is_transitioning:
		return  # Prevent multiple interactions during transition
	
	print("locker interacted")
	
	# Find the player (assuming it's the one calling interact)
	player_ref = get_tree().get_first_node_in_group("player")
	if not player_ref:
		return
	
	# Check if player is already in locker
	if "in_locker" in player_ref and player_ref.in_locker:
		# Player wants to exit locker
		print("Player exiting locker")
		handle_locker_exit()
	else:
		# Player wants to enter locker
		print("Player entering locker")
		$Locker2.locker_open()
		interactable.is_interactable = false
		
		# Set flag to trigger locker animations in player controller
		if "locker_interaction_triggered" in player_ref:
			player_ref.locker_interaction_triggered = true
		
		teleport_and_move_player()

func teleport_and_move_player():
	if not player_ref or not enter_loc or not exit_loc:
		print("Missing player reference or location nodes")
		return
	
	is_transitioning = true
	
	# Lock camera rotation during transition
	var original_mouse_captured = false
	if "mouse_captured" in player_ref:
		original_mouse_captured = player_ref.mouse_captured
		player_ref.mouse_captured = false  # Disable camera rotation
	
	# Immediately teleport player to enter location with rotation
	player_ref.global_position = enter_loc.global_position
	player_ref.global_rotation = enter_loc.global_rotation
	stored_enter_rotation = enter_loc.global_rotation  # Store the enter rotation for exit
	print("Player teleported to enter location")
	
	# Wait 0.8 seconds then teleport to exit location
	await get_tree().create_timer(0.8).timeout
	
	# Teleport to exit location with only 180 degree rotation
	player_ref.global_position = exit_loc.global_position
	player_ref.global_rotation = Vector3(0, PI, 0)  # Set rotation to only 180 degrees on Y axis
	
	# Update the player's internal look rotation to match the new rotation
	if "look_rotation" in player_ref:
		player_ref.look_rotation.y = PI  # Update internal Y rotation tracking
	
	# Re-enable camera rotation
	if "mouse_captured" in player_ref:
		player_ref.mouse_captured = original_mouse_captured
	
	print("Player teleported to exit location with 180 degree rotation")
	
	is_transitioning = false
	interactable.is_interactable = true  # Re-enable interaction

func handle_locker_exit():
	if not player_ref or not enter_loc:
		print("Missing player reference or enter location")
		return
	
	is_transitioning = true
	
	# Play the locker animation when exiting
	$Locker2.locker_open()
	
	# Set flag to trigger locker_out animation in player controller
	if "locker_interaction_triggered" in player_ref:
		player_ref.locker_interaction_triggered = true
	
	# Wait a moment for the locker_out animation to start, then teleport to enter position
	await get_tree().create_timer(0.1).timeout
	
	# Teleport player back to enter location with 180 degree rotation from stored enter angle
	player_ref.global_position = enter_loc.global_position
	var exit_rotation = stored_enter_rotation  # Use the stored rotation from when player entered
	exit_rotation.y += PI  # Add 180 degrees (PI radians) to the stored enter rotation Y
	player_ref.global_rotation = exit_rotation
	
	# Update the player's internal look rotation to match the new rotation
	if "look_rotation" in player_ref:
		player_ref.look_rotation.y = exit_rotation.y
	
	print("Player teleported back to enter location")
	
	# Re-enable movement and interaction
	if "can_move" in player_ref:
		player_ref.can_move = true
	
	is_transitioning = false
	interactable.is_interactable = true  # Re-enable interaction

func set_player_position(pos: Vector3):
	if player_ref:
		player_ref.global_position = pos

func set_player_rotation(rot: Vector3):
	if player_ref:
		player_ref.global_rotation = rot
