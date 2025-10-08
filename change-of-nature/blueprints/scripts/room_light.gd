extends OmniLight3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func light_out():
	$".".visible = !$".".visible

func _input(event):
	if event.is_action_pressed("debug"):
		light_out()
