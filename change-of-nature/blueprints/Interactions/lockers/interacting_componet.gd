extends Node3D

@onready var interact_label: Label3D = $InteractLabel
@onready var interact_range_ray: RayCast3D = $InteractRangeRay
var current_interactions := []
var can_interact := true
var raycast_target = null

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and can_interact:
		if current_interactions:
			can_interact = false
			interact_label.hide()
			
			await current_interactions[0].interact.call()
			
			can_interact = true

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	# Handle raycast interaction detection
	if interact_range_ray and interact_range_ray.is_enabled():
		if interact_range_ray.is_colliding():
			var collider = interact_range_ray.get_collider()
			if collider != raycast_target:
				# New target detected
				if raycast_target:
					handle_raycast_exit(raycast_target)
				raycast_target = collider
				handle_raycast_enter(collider)
		else:
			# No longer colliding
			if raycast_target:
				handle_raycast_exit(raycast_target)
				raycast_target = null
	
	# Handle regular area interactions
	if current_interactions and can_interact:
		current_interactions.sort_custom(_sort_by_nearest)
		if current_interactions[0].is_interactable:
			interact_label.text = current_interactions[0].interact_name
			interact_label.show()
		else:
			interact_label.hide()
	
func _sort_by_nearest(area1, area2):
	var area1_dist = global_position.distance_to(area1.global_position)
	var area2_dist = global_position.distance_to(area2.global_position)
	return area1_dist < area2_dist
	
func _on_interact_range_area_entered(area: Area3D) -> void:
	current_interactions.push_back(area)
	interact_label.visible = true

func _on_interact_range_area_exited(area: Area3D) -> void:
	current_interactions.erase(area)
	interact_label.visible = false

func handle_raycast_enter(collider) -> void:
	# Treat raycast collision like area entered
	if collider is Area3D:
		_on_interact_range_area_entered(collider)
	print("Raycast detected: ", collider.name if collider else "null")

func handle_raycast_exit(collider) -> void:
	# Treat raycast exit like area exited
	if collider is Area3D:
		_on_interact_range_area_exited(collider)
	print("Raycast lost: ", collider.name if collider else "null")
	
