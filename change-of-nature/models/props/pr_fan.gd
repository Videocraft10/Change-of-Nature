extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var animation_player = $Fan2/Amin_FanSpin
	animation_player.play("fan_spin")
	# Set the animation to loop
	animation_player.get_animation("fan_spin").loop_mode = Animation.LOOP_LINEAR
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
