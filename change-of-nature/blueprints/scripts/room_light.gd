extends OmniLight3D
var LightBroken = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func light_out():
	if not LightBroken:
		$".".visible = !$".".visible
		LightBroken = true
	

func _input(event):
	if LightBroken:
		LightBroken = !LightBroken
	if event.is_action_pressed("debug"):
		light_out()
