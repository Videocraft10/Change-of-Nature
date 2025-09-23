extends Area3D

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		var anim_player = get_node("SmallDoor/AnimationPlayer")
		anim_player.play("ArmatureAction")
		$StaticBody3D/CollisionShape3D.set_deferred("disabled", true)
		
func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		var anim_player = get_node("SmallDoor/AnimationPlayer")
		anim_player.play_backwards("ArmatureAction")
		$StaticBody3D/CollisionShape3D.set_deferred("disabled", false)
