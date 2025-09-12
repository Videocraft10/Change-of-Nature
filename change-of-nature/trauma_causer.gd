extends Area3D

@export var set_trauma_amount := 1.0
@export var set_trauma_reduction := 1.0

func cause_trauma():
	var trauma_areas := get_overlapping_areas()
	for area in trauma_areas:
		if area.has_method("trauma_ready") && area.trauma_ready("yes"):
			area.add_trauma_transmit(set_trauma_amount)
			
func trauma_reduction_rate():
	var trauma_areas := get_overlapping_areas()
	for area in trauma_areas:
		if area.has_method("trauma_ready") && area.trauma_ready("yes"):
			area.trauma_reduction(set_trauma_reduction)


		#if area.has_method("add_trauma"):
			#print("has trauma")
			#area.add_trauma(trauma_amount)
