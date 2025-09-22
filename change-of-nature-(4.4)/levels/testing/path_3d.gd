extends Path3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Find the collision box node in the scene tree
	var collision_box = get_node_or_null("../test_collision_box")
	if collision_box:
		collision_box.connect("collision_box_triggered", Callable(self, "_on_collision_box_triggered"))


# Called when the collision_box_triggered signal is received
func _on_collision_box_triggered(_area):
	var PathFollow3D = $test_angler_path_follow
	start_node_following_path(PathFollow3D)
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func start_node_following_path(path_follow_3d):
	var tween = get_tree().create_tween()
	tween.tween_property(path_follow_3d, "progress_ratio", 1.0, 5.0).set_trans(Tween.TRANS_LINEAR)
	tween.play()
