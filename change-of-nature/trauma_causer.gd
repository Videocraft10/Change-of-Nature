extends Area3D

@export var trauma_amount := 1.0

func cause_trauma():
	var trauma_areas := get_overlapping_areas()
	for area in trauma_areas:
		if area.has_method("trauma_ready") && area.trauma_ready("yes"):
			area.add_trauma_transmit(trauma_amount)
			
	func trauma_reduction_rate():
		area.
			
	


		#if area.has_method("add_trauma"):
			#print("has trauma")
			#area.add_trauma(trauma_amount)
