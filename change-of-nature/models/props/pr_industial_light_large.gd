extends Node3D

var LightBroken = false
var is_flickering = false

func _ready():
	# Create a unique material instance for this light
	var mesh_instance = $Cube
	if mesh_instance and mesh_instance is MeshInstance3D:
		var original_material = mesh_instance.get_surface_override_material(2)
		if original_material and original_material is StandardMaterial3D:
			# Create a duplicate of the material so each instance is unique
			var unique_material = original_material.duplicate()
			mesh_instance.set_surface_override_material(2, unique_material)
			print("Created unique material for light instance: ", name)
	
	# Connect to level script's enemy_spawned signal
	var level_script = find_level_script()
	if level_script and level_script.has_signal("enemy_spawned"):
		level_script.enemy_spawned.connect(_on_enemy_spawned)
		print("Large industrial light connected to enemy_spawned signal")
	

func light_out():
	if not LightBroken:
		# Toggle the emission of this instance's unique material
		var mesh_instance = $Cube
		if mesh_instance and mesh_instance is MeshInstance3D:
			var material = mesh_instance.get_surface_override_material(2)
			if material and material is StandardMaterial3D:
				# Toggle emission enabled on this instance's unique material
				material.emission_enabled = !material.emission_enabled
				print("Light ", name, " emission: ", material.emission_enabled)
				LightBroken = true
				$LargeLightArea3D.queue_free()
				
func _input(event):
	if LightBroken:
		LightBroken = !LightBroken
	if event.is_action_pressed("debug"):
		light_out()


func _on_large_light_area_3d_area_entered(_area: Area3D) -> void:
	# Check if the area is the kill area (not trauma area)
	if _area.is_in_group("kill_area"):
		#print("Test angler kill area detected by industrial large light - turning OFF")
		# Only trigger if not already broken
		if not LightBroken:
			light_out()

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
	if not LightBroken and not is_flickering:
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
		
		# Toggle emission
		var mesh_instance = $Cube
		if mesh_instance and mesh_instance is MeshInstance3D:
			var material = mesh_instance.get_surface_override_material(2)
			if material and material is StandardMaterial3D:
				material.emission_enabled = !material.emission_enabled
		
		elapsed_time += wait_time
	
	# Make sure light is back on after flickering
	var flicker_mesh_instance = $Cube
	if flicker_mesh_instance and flicker_mesh_instance is MeshInstance3D:
		var material = flicker_mesh_instance.get_surface_override_material(2)
		if material and material is StandardMaterial3D:
			material.emission_enabled = true
	
	is_flickering = false
	print("Large industrial light finished flickering")

# Node references:
# $LargeLightArea3D
# $LargeLightArea3D/LargeLightCollision3D
