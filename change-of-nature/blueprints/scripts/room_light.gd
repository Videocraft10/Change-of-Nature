extends OmniLight3D
var LightBroken = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


func light_out():
	if not LightBroken:
		$".".visible = !$".".visible
		LightBroken = true
		queue_free()
	

func _input(event):
	if LightBroken:
		LightBroken = !LightBroken
	if event.is_action_pressed("debug"):
		light_out()


func _on_room_light_area_3d_area_entered(_area: Area3D) -> void:
	# Check if the area is the kill area (not trauma area)
	if _area.is_in_group("kill_area"):
		#print("Test angler kill area detected by room light - turning OFF")
		# Only trigger if not already broken
		if not LightBroken:
			light_out()  # This will set LightBroken = true inside the function

# Node references:
# $RoomLightArea3D
# $RoomLightArea3D/RoomLightCollision3D
