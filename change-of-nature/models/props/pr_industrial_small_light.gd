extends Node3D
var RoomLightBroken = false
var DebugTrig = false
var light_is_on = false  # Track current light state - starts OFF

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Create a unique material instance for this light
	var mesh_instance = $IndustiralLightSmall
	if mesh_instance and mesh_instance is MeshInstance3D:
		# Try different surface indices to find the correct one
		for i in range(mesh_instance.get_surface_override_material_count()):
			var original_material = mesh_instance.get_surface_override_material(i)
			if original_material and original_material is StandardMaterial3D:
				# Create a duplicate of the material so each instance is unique
				var unique_material = original_material.duplicate()
				mesh_instance.set_surface_override_material(i, unique_material)
				print("Created unique material for light instance: ", name, " at surface: ", i)
				break


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
	#pass

func light_out():
	if not RoomLightBroken:
		# Toggle the light state
		if light_is_on:
			# Turn light OFF
			_turn_light_off()
		else:
			# Turn light ON (with delay unless debug) 
			_start_turn_on_sequence()

func _turn_light_off():
	light_is_on = false
	var mesh_instance = $IndustiralLightSmall
	if mesh_instance and mesh_instance is MeshInstance3D:
		var material = mesh_instance.get_surface_override_material(0)
		if material and material is StandardMaterial3D:
			# Turn off the light immediately
			material.emission_enabled = false
			material.emission_energy = 0.0
			$SmallOmniLight.visible = false
			$SmallOmniLight.light_energy = 0.0
			print("Light ", name, " turned off")

func _start_turn_on_sequence():
	# Start the delay timer (skip if debug)
	if DebugTrig:
		_turn_light_on()
		DebugTrig = false  # Reset debug flag after use
	else:
		# Create a timer for the delay
		var delay_timer = Timer.new()
		add_child(delay_timer)
		delay_timer.wait_time = 2.0  # 2 second delay
		delay_timer.one_shot = true
		delay_timer.timeout.connect(_on_timer_timeout)
		delay_timer.start()

func _on_timer_timeout():
	_turn_light_on()
	# Clean up the timer
	for child in get_children():
		if child is Timer:
			child.queue_free()

func _turn_light_on():
	light_is_on = true  # Update state to ON
	var mesh_instance = $IndustiralLightSmall
	if mesh_instance and mesh_instance is MeshInstance3D:
		var material = mesh_instance.get_surface_override_material(0)
		if material and material is StandardMaterial3D:
			
			# Enable emission and make light visible
			material.emission_enabled = true
			$SmallOmniLight.visible = true
			
			# Create tween for smooth interpolation
			var tween = create_tween()
			tween.set_parallel(true)  # Allow multiple tweens to run simultaneously
			
			# Interpolate material emission power from 0 to 3
			tween.tween_method(_set_emission_energy, 0.0, 3.0, 1.0)
			
			# Interpolate light energy from 0 to 1
			tween.tween_method(_set_light_energy, 0.0, 1.0, 1.0)
			
			print("Light ", name, " turning on with interpolation")

func _set_emission_energy(value: float):
	var mesh_instance = $IndustiralLightSmall
	if mesh_instance and mesh_instance is MeshInstance3D:
		var material = mesh_instance.get_surface_override_material(0)
		if material and material is StandardMaterial3D:
			material.emission_energy = value

func _set_light_energy(value: float):
	$SmallOmniLight.light_energy = value

func _input(event):
	if RoomLightBroken:
		RoomLightBroken = !RoomLightBroken
	if event.is_action_pressed("debug"):
		DebugTrig = true  # Set to true for debug mode
		light_out()
### first time tiggerd the lights dont turn on for some reason



func _on_small_light_area_3d_area_entered(_area: Area3D) -> void:
	# Check if the area belongs to a test angler enemy
	var parent_node = _area.get_parent()
	if parent_node and parent_node.is_in_group("e_angler"):
		print("Test angler detected by industrial small light - turning ON")
		# Set light to broken state so it can't be toggled again (except debug)
		RoomLightBroken = true
		# Force the light to turn on if it's currently off
		if not light_is_on:
			_turn_light_on()

# Node references:
# $SmallLightArea3D
# $SmallLightArea3D/SmallLightCollision3D
