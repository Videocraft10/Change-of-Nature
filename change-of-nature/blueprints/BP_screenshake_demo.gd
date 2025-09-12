extends Node3D

func _process(_delta):
	$trauma_causer.cause_trauma()
	$trauma_causer.trauma_reduction_rate()
	pass
