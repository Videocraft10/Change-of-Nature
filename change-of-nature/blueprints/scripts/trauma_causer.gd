extends Area3D

@export var set_trauma_amount := 1.0
@export var set_trauma_reduction := 1.0
@export var max_trauma := 1.0
@export var is_distance_based := false

func cause_trauma():
	var trauma_areas := get_overlapping_areas()
	for area in trauma_areas:
		if area.has_method("trauma_ready") && area.trauma_ready("yes"):
			area.set_max_trauma(max_trauma)
			 # Set max trauma on player
			if not is_distance_based:
				area.add_trauma_transmit(set_trauma_amount)
				print("Caused trauma(unscaled): ", set_trauma_amount)
			else:
				# Calculate distance from area to this object's origin
				var distance = global_transform.origin.distance_to(area.global_transform.origin)
				# Invert and scale trauma, closer = more trauma, farther = less
				var max_distance = 40 
				var scaled_trauma = set_trauma_amount * (1.0 - clamp(distance / max_distance, 0.0, 1.0))
				area.add_trauma_transmit(scaled_trauma)
				print("Caused trauma(distance): ", scaled_trauma)
			
func trauma_reduction_rate():
	var trauma_areas := get_overlapping_areas()
	for area in trauma_areas:
		if area.has_method("trauma_ready") && area.trauma_ready("yes"):
			area.trauma_reduction(set_trauma_reduction)


		#if area.has_method("add_trauma"):
			#print("has trauma")
			#area.add_trauma(trauma_amount)
