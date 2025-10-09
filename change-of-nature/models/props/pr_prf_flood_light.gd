extends Node3D

var LightBroken = false

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
	if not LightBroken:
		# Toggle the emission of this instance's unique material
		var mesh_instance = $FloodLight
		if mesh_instance and mesh_instance is MeshInstance3D:
			var material = mesh_instance.get_surface_override_material(1)
			if material and material is StandardMaterial3D:
				# Toggle emission enabled on this instance's unique material
				material.emission_enabled = !material.emission_enabled
				print("Light ", name, " emission: ", material.emission_enabled)
				LightBroken = true

func _input(event):
	if LightBroken:
		LightBroken = !LightBroken
	if event.is_action_pressed("debug"):
		light_out()


func _on_flood_light_area_3d_area_entered(_area: Area3D) -> void:
	# Check if the area belongs to a test angler enemy
	var parent_node = _area.get_parent()
	if parent_node and parent_node.is_in_group("e_angler"):
		#print("Test angler detected by flood light - turning OFF")
		# Only trigger if not already broken
		if not LightBroken:
			light_out()

# Node references:
# $FloodLightArea3D
# $FloodLightArea3D/FloodLightCollision3D
