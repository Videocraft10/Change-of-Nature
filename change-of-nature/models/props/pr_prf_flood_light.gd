extends Node3D

func _ready():
	# Force a light update after the scene is ready
	$FloodLight2/SpotLight3D/OmniLight3D.hide()
	await get_tree().create_timer(0.1).timeout # Wait a frame
	$FloodLight2/SpotLight3D/OmniLight3D.show()
