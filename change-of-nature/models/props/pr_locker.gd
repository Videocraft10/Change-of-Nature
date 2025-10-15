extends Node3D

@onready var interactable: Area3D = $Interactable
@onready var locker_2: Node3D = $Locker2
@onready var enter_loc: Node3D = $EnterLoc
@onready var exit_loc: Node3D = $ExitLoc

var player_ref = null
var is_transitioning = false
var stored_enter_rotation: Vector3  # Store the rotation when player enters
var animation_cooldown = false  # Prevent interactions during animation

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# 50% chance to delete the locker (only 50% chance to appear)
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
	if is_transitioning or animation_cooldown:
		return  # Prevent multiple interactions during transition or animation cooldown
	
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
		animation_cooldown = true  # Start cooldown
		$Locker2.locker_open()
		interactable.is_interactable = false
		
		# Set flag to trigger locker animations in player controller
		if "locker_interaction_triggered" in player_ref:
			player_ref.locker_interaction_triggered = true
		
		# Start cooldown timer in parallel (don't await here)
		start_cooldown_timer()
		
		teleport_and_move_player()

func start_cooldown_timer():
	# Start cooldown timer without blocking (runs in parallel)
	await get_tree().create_timer(1.5).timeout
	print("Locker animation cooldown finished")
	animation_cooldown = false

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
	
	# Disable player collision when entering locker
	if "collider" in player_ref:
		player_ref.collider.disabled = true
	
	print("Player teleported to enter location")
	
	# Wait 0.8 seconds then teleport to exit location
	await get_tree().create_timer(0.8).timeout
	
	# Teleport to exit location with locker's root rotation + 90 degrees left
	player_ref.global_position = exit_loc.global_position
	var locker_rotation = self.global_rotation
	locker_rotation.y -= PI/2  # Add 90 degrees to the left
	player_ref.global_rotation = locker_rotation
	
	# Update the player's internal look rotation to match the new rotation
	if "look_rotation" in player_ref:
		player_ref.look_rotation.y = locker_rotation.y  # Update internal Y rotation tracking
	
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
	animation_cooldown = true  # Start cooldown for exit
	
	# Play the locker animation when exiting
	$Locker2.locker_open()
	
	# Set flag to trigger locker_out animation in player controller
	if "locker_interaction_triggered" in player_ref:
		player_ref.locker_interaction_triggered = true
	
	# Start cooldown timer in parallel (don't await here)
	start_cooldown_timer()
	
	# Wait a moment for the locker_out animation to start, then teleport to enter position
	await get_tree().create_timer(0.1).timeout
	
	# Teleport player back to enter location with locker's root rotation + 90 degrees left
	player_ref.global_position = enter_loc.global_position
	var locker_rotation = self.global_rotation
	locker_rotation.y -= PI/2  # Add 90 degrees to the left
	player_ref.global_rotation = locker_rotation
	
	# Update the player's internal look rotation to match the new rotation
	if "look_rotation" in player_ref:
		player_ref.look_rotation.y = locker_rotation.y
	
	print("Player teleported back to enter location")
	
	# Re-enable movement, collision and interaction
	if "can_move" in player_ref:
		player_ref.can_move = true
	
	# Re-enable player collision when exiting locker
	if "collider" in player_ref:
		player_ref.collider.disabled = false
	
	is_transitioning = false
	interactable.is_interactable = true  # Re-enable interaction

func set_player_position(pos: Vector3):
	if player_ref:
		player_ref.global_position = pos

func set_player_rotation(rot: Vector3):
	if player_ref:
		player_ref.global_rotation = rot
