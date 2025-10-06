extends SubViewport

func _ready():
	# Set initial size to match the main viewport
	size = get_viewport().size
	
	# Connect to the main viewport's size_changed signal to keep them in sync
	get_viewport().size_changed.connect(_on_main_viewport_size_changed)

func _on_main_viewport_size_changed():
	# Update SubViewport size to match the main viewport
	size = get_viewport().size
