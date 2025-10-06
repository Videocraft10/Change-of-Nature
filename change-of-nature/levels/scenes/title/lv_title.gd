extends CanvasLayer


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://levels/scenes/worlds/demo_1_world.tscn")
	pass # Replace with function body.


func _on_settings_pressed() -> void:
	pass # Replace with function body.


func _on_quit_pressed() -> void:
	print("Quiting Game...")
	get_tree().quit()
	pass # Replace with function body.
