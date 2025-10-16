extends CanvasLayer

@onready var info_contain = $"Control/MarginContainer/Demo Info Container"
@onready var vid = $Control/MarginContainer/VideoStreamPlayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Hide video initially
	vid.visible = false
	
	# Start the fade sequence
	await fade_in_out_info()
	
	# Once fade is complete, show and play video
	vid.visible = true
	vid.play()

func fade_in_out_info():
	# Start with info_contain fully transparent
	info_contain.modulate.a = 0.0
	
	# Fade in over 2 seconds
	var tween = create_tween()
	tween.tween_property(info_contain, "modulate:a", 1.0, 2.0)
	await tween.finished
	
	# Stay visible for 5 seconds
	await get_tree().create_timer(5.0).timeout
	
	# Fade out over 2 seconds
	tween = create_tween()
	tween.tween_property(info_contain, "modulate:a", 0.0, 2.0)
	await tween.finished
	
	print("Info container fade sequence complete")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_video_stream_player_finished() -> void:
	print("Logo Fin")
	get_tree().change_scene_to_file("res://levels/scenes/title/lv_title.tscn")
	pass # Replace with function body.
