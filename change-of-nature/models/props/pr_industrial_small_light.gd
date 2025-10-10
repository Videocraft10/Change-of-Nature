extends Node3D
var RoomLightBroken = false
var DebugTrig = false
var light_is_on = false  # Track current light state - starts OFF
var is_flickering = false

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
	
	# Connect to level script's enemy_spawned signal
	var level_script = find_level_script()
	if level_script and level_script.has_signal("enemy_spawned"):
		level_script.enemy_spawned.connect(_on_enemy_spawned)
		print("Small industrial light connected to enemy_spawned signal")


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
	light_is_on = true # Update state to ON
	await get_tree().create_timer(10.0).timeout
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
	# Check if the area is the kill area (not trauma area)
	if _area.is_in_group("kill_area"):
		#print("Test angler kill area detected by industrial small light - turning ON")
		# Only trigger if not already broken
		if not RoomLightBroken:
			# Force the light to turn on if it's currently off
			if not light_is_on:
				_turn_light_on()
			# Set light to broken state so it can't be toggled again (except debug)
			RoomLightBroken = true

func find_level_script() -> Node:
	# Look for BP_LevelScript in the scene tree
	var current_scene = get_tree().current_scene
	var nodes_to_check = [current_scene]
	
	while nodes_to_check.size() > 0:
		var node = nodes_to_check.pop_front()
		if node.get_script() != null:
			var script_path = node.get_script().get_path()
			if script_path.ends_with("BP_LevelScript.gd"):
				return node
		for child in node.get_children():
			nodes_to_check.append(child)
	return null

func _on_enemy_spawned():
	# Only flicker if light is currently on and not broken
	if light_is_on and not RoomLightBroken and not is_flickering:
		flicker_light()

func flicker_light():
	is_flickering = true
	var flicker_duration = randf_range(0.5, 3.0)  # Random duration between 0.5 and 3 seconds
	var elapsed_time = 0.0
	
	# Random flicker pattern - each light gets different timing
	var flicker_interval_min = 0.05
	var flicker_interval_max = 0.2
	
	while elapsed_time < flicker_duration:
		# Random wait time for this flicker
		var wait_time = randf_range(flicker_interval_min, flicker_interval_max)
		await get_tree().create_timer(wait_time).timeout
		
		# Toggle emission and light visibility
		var mesh_instance = $IndustiralLightSmall
		if mesh_instance and mesh_instance is MeshInstance3D:
			var material = mesh_instance.get_surface_override_material(0)
			if material and material is StandardMaterial3D:
				material.emission_enabled = !material.emission_enabled
				$SmallOmniLight.visible = !$SmallOmniLight.visible
		
		elapsed_time += wait_time
	
	# Make sure light is back on after flickering (if it was on before)
	if light_is_on:
		var mesh_instance = $IndustiralLightSmall
		if mesh_instance and mesh_instance is MeshInstance3D:
			var material = mesh_instance.get_surface_override_material(0)
			if material and material is StandardMaterial3D:
				material.emission_enabled = true
				$SmallOmniLight.visible = true
	
	is_flickering = false
	print("Small industrial light finished flickering")

# Node references:
# $SmallLightArea3D
# $SmallLightArea3D/SmallLightCollision3D
