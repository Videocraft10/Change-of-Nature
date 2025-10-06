extends CanvasLayer


func _on_start_butt_pressed() -> void:
	get_tree().change_scene_to_file("res://levels/scenes/worlds/demo_1_world.tscn")
	pass # Replace with function body.


func _on_settings_butt_pressed() -> void:
	pass # Replace with function body.


func _on_quit_butt_pressed() -> void:
	print("Quiting Game...")
	get_tree().quit()
	pass # Replace with function body.


func _on_demo_info_pressed() -> void:
	$"Control/MarginContainer/Main Container".hide()
	$"Control/MarginContainer/Demo Info Container".show()
	pass # Replace with function body.

func _on_exit_info_pressed() -> void:
	$"Control/MarginContainer/Demo Info Container".hide()
	$"Control/MarginContainer/Main Container".show()
	pass # Replace with function body.
