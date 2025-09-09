extends Area3D


func trauma_ready(isit):
	return "yes" == isit
	
func add_trauma_transmit(trauma_amount_transmit:float):
	$"../..".add_trauma(trauma_amount_transmit)
	
func trauma_reduction(reduction_amount_transmit:float):
	$"../..".trauma_reduction(reduction_amount_transmit)
