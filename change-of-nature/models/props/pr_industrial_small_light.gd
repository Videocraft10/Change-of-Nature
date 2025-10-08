extends Node3D

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
	# Toggle the emission of this instance's unique material and the visibility of the SmallOmniLight
	var mesh_instance = $IndustiralLightSmall
	if mesh_instance and mesh_instance is MeshInstance3D:
		var material = mesh_instance.get_surface_override_material(0)
		if material and material is StandardMaterial3D:
			# Toggle emission enabled on this instance's unique material
			material.emission_enabled = !material.emission_enabled
			# Toggle visibility of the SmallOmniLight
			$SmallOmniLight.visible = !$SmallOmniLight.visible
			print("Light ", name, " emission: ", material.emission_enabled, ", SmallOmniLight visibility: ", $SmallOmniLight.visible)

func _input(event):
	if event.is_action_pressed("debug"):
		light_out()
