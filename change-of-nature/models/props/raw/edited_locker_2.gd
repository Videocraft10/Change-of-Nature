extends Node3D

func locker_open():
	$AnimationPlayer.play("LockerArmAction")


func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
