extends Area3D
var is_open: bool = false

func _on_body_entered(body: Node3D) -> void:
	if is_open:
		return
	else:
		if body.is_in_group("player"):
			var anim_player = get_node("SmallDoor/AnimationPlayer")
			anim_player.play("ArmatureAction")
			$StaticBody3D/CollisionShape3D.set_deferred("disabled", true)
			print("Door Opened")
			is_open = true
		
#func _on_body_exited(body: Node3D) -> void:
	#if body.is_in_group("player"):
		#var anim_player = get_node("SmallDoor/AnimationPlayer")
		#anim_player.play_backwards("ArmatureAction")
		#$StaticBody3D/CollisionShape3D.set_deferred("disabled", false)
		#print("Door Closed")
