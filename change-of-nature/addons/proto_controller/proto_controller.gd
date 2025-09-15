# ProtoController v1.0 by Brackeys
# CC0 License
# Intended for rapid prototyping of first-person games.
# Happy prototyping!

extends CharacterBody3D

#region @exports
## Can we move around?
@export var can_move : bool = true
## Are we affected by gravity?
@export var has_gravity : bool = true
## Can we press to jump?
@export var can_jump : bool = true
## Can we hold to run?
@export var can_sprint : bool = false
## Can we press to enter freefly mode (noclip)?
@export var can_freefly : bool = false

@export_group("Speeds")
## Look around rotation speed.
@export var look_speed : float = 0.002
## Normal speed.
@export var base_speed : float = 7.0
## Speed of jump.
@export var jump_velocity : float = 4.5
## How fast do we run?
@export var sprint_speed : float = 10.0
## How fast do we freefly?
@export var freefly_speed : float = 25.0

#Auto-Death Hight
@export_group("Gameplay")
@export var void_death_hight : float = -50
@export var void_respwan_loc : Vector3 = Vector3.ZERO
@export var fall_gravity_multiplier : float = 1.0

@export_group("Camera Shake")
@export var trauma_reduction_rate := 1.0
@export var noise : FastNoiseLite
@export var noise_speed := 50.0
@export var max_x := 10.0
@export var max_y := 10.0
@export var max_z := 5.0

@export_group("Input Actions")
## Name of Input Action to move Left.
@export var input_left : String = "ui_left"
## Name of Input Action to move Right.
@export var input_right : String = "ui_right"
## Name of Input Action to move Forward.
@export var input_forward : String = "ui_up"
## Name of Input Action to move Backward.
@export var input_back : String = "ui_down"
## Name of Input Action to Jump.
@export var input_jump : String = "ui_accept"
## Name of Input Action to Sprint.
@export var input_sprint : String = "sprint"
## Name of Input Action to toggle freefly mode.
@export var input_freefly : String = "freefly"
#endregion

#region var's
var mouse_captured : bool = false
var look_rotation : Vector2
var move_speed : float = 0.0
var freeflying : bool = false
var is_falling_after_jump : bool = false
var trauma := 0.0
var time := 0.0
var max_trauma := 1.0
#endregion

## IMPORTANT REFERENCES
@onready var head: Node3D = $Head
@onready var collider: CollisionShape3D = $Collider
@onready var camera := $Head/Camera3D as Camera3D
var inital_rotation : Vector3


#region Func's
func is_it(what):
	return "Player" == what

func _ready() -> void:
	check_input_mappings()
	inital_rotation = camera.rotation
	look_rotation.y = rotation.y
	look_rotation.x = head.rotation.x

func _unhandled_input(event: InputEvent) -> void:
	# Mouse capturing
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		capture_mouse()
	if Input.is_key_pressed(KEY_ESCAPE):
		release_mouse()
	
	# Look around
	if mouse_captured and event is InputEventMouseMotion:
		rotate_look(event.relative)
	
	# Toggle freefly mode
	if can_freefly and Input.is_action_just_pressed(input_freefly):
		if not freeflying:
			enable_freefly()
		else:
			disable_freefly()

#var infTrauma := false # Trauma Testing

func _process(_delta):
	time += _delta
	trauma = max(trauma - _delta * trauma_reduction_rate, 0.0)
	
	camera.rotation_degrees.x = inital_rotation.x + max_x * get_shake_intensity() * get_noise_from_seed(0)
	camera.rotation_degrees.y = inital_rotation.y + max_y * get_shake_intensity() * get_noise_from_seed(1)
	camera.rotation_degrees.z = inital_rotation.z + max_z * get_shake_intensity() * get_noise_from_seed(2)
	
	#if infTrauma:
		#add_trauma(.1) # Continuous trauma for testing
		
	## Testing input
	#if Input.is_action_just_pressed("sprint"):
		#print("sprint")
		#add_trauma(5)
		#trauma_reduction_rate = 5
		#await get_tree().create_timer(5).timeout
		#add_trauma(2)
		#if infTrauma:
			#infTrauma = false
			#print("false")
		#else:
			#infTrauma = true
			#print("true")
		
		
func _physics_process(delta: float) -> void:
	# If freeflying, handle freefly and nothing else
	if can_freefly and freeflying:
		var input_dir := Input.get_vector(input_left, input_right, input_forward, input_back)
		var motion := (head.global_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		motion *= freefly_speed * delta
		move_and_collide(motion)
		return
	
	
	if is_on_floor():
		is_falling_after_jump = false
		
	# Apply gravity to velocity
	if has_gravity:
		if not is_on_floor():
			var gravity_to_apply = get_gravity()
			if is_falling_after_jump:
				gravity_to_apply *= fall_gravity_multiplier
			velocity += gravity_to_apply * delta

	# Apply jumping
	if can_jump:
		if Input.is_action_just_pressed(input_jump) and is_on_floor():
			velocity.y = jump_velocity
			is_falling_after_jump = true

	# Modify speed based on sprinting
	if can_sprint and Input.is_action_pressed(input_sprint):
			move_speed = sprint_speed
	else:
		move_speed = base_speed

	# Apply desired movement to velocity
	if can_move:
		var input_dir := Input.get_vector(input_left, input_right, input_forward, input_back)
		var move_dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		if move_dir:
			velocity.x = move_dir.x * move_speed
			velocity.z = move_dir.z * move_speed
		else:
			velocity.x = move_toward(velocity.x, 0, move_speed)
			velocity.z = move_toward(velocity.z, 0, move_speed)
	else:
		velocity.x = 0
		velocity.z = 0 # This was velocity.y before, corrected to Z for consistency.
	
	# Use velocity to actually move
	move_and_slide()
	
	# Check for hight death
	check_fall()

func trauma_reduction(reduction_rate:float):
	trauma_reduction_rate = reduction_rate

func add_trauma(trauma_amount:float):
	trauma = clamp(trauma + trauma_amount, 0.0, 5.0)
	
func get_shake_intensity() -> float:
	return trauma * trauma * max_trauma

func get_noise_from_seed(_seed : int) -> float:
	noise.seed = _seed
	return noise.get_noise_1d(time * noise_speed)

## Checks if a player has fallen enough to be reset
func check_fall():
	if global_transform.origin.y < void_death_hight:
		global_transform.origin = void_respwan_loc
		velocity = Vector3.ZERO # Reset Velocity

## Rotate us to look around.
## Base of controller rotates around y (left/right). Head rotates around x (up/down).
## Modifies look_rotation based on rot_input, then resets basis and rotates by look_rotation.
func rotate_look(rot_input : Vector2):
	look_rotation.x -= rot_input.y * look_speed
	look_rotation.x = clamp(look_rotation.x, deg_to_rad(-85), deg_to_rad(85))
	look_rotation.y -= rot_input.x * look_speed
	transform.basis = Basis()
	rotate_y(look_rotation.y)
	head.transform.basis = Basis()
	head.rotate_x(look_rotation.x)


func enable_freefly():
	collider.disabled = true
	freeflying = true
	velocity = Vector3.ZERO

func disable_freefly():
	collider.disabled = false
	freeflying = false


func capture_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	mouse_captured = true


func release_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	mouse_captured = false


## Checks if some Input Actions haven't been created.
## Disables functionality accordingly.
func check_input_mappings():
	if can_move and not InputMap.has_action(input_left):
		push_error("Movement disabled. No InputAction found for input_left: " + input_left)
		can_move = false
	if can_move and not InputMap.has_action(input_right):
		push_error("Movement disabled. No InputAction found for input_right: " + input_right)
		can_move = false
	if can_move and not InputMap.has_action(input_forward):
		push_error("Movement disabled. No InputAction found for input_forward: " + input_forward)
		can_move = false
	if can_move and not InputMap.has_action(input_back):
		push_error("Movement disabled. No InputAction found for input_back: " + input_back)
		can_move = false
	if can_jump and not InputMap.has_action(input_jump):
		push_error("Jumping disabled. No InputAction found for input_jump: " + input_jump)
		can_jump = false
	if can_sprint and not InputMap.has_action(input_sprint):
		push_error("Sprinting disabled. No InputAction found for input_sprint: " + input_sprint)
		can_sprint = false
	if can_freefly and not InputMap.has_action(input_freefly):
		push_error("Freefly disabled. No InputAction found for input_freefly: " + input_freefly)
		can_freefly = false
#endregion
