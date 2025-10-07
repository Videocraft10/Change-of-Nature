extends Node3D

func _ready():
	# Create a unique material instance for this light
	var mesh_instance = $FloodLight
	if mesh_instance and mesh_instance is MeshInstance3D:
		var original_material = mesh_instance.get_surface_override_material(1)
		if original_material and original_material is StandardMaterial3D:
			# Create a duplicate of the material so each instance is unique
			var unique_material = original_material.duplicate()
			mesh_instance.set_surface_override_material(1, unique_material)
			print("Created unique material for light instance: ", name)
	

func light_out():
	# Toggle the emission of this instance's unique material
	var mesh_instance = $FloodLight
	if mesh_instance and mesh_instance is MeshInstance3D:
		var material = mesh_instance.get_surface_override_material(1)
		if material and material is StandardMaterial3D:
			# Toggle emission enabled on this instance's unique material
			material.emission_enabled = !material.emission_enabled
			print("Light ", name, " emission: ", material.emission_enabled)

			###work on testing this a t home
