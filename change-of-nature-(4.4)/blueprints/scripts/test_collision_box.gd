extends Area3D
signal collision_box_triggered(area)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	var trauma_areas := get_overlapping_areas()
	for area in trauma_areas:
		if area.has_method("trauma_ready") && area.trauma_ready("yes"):
			emit_signal("collision_box_triggered", area)
			collision_box_triggered.emit(area)
	pass
