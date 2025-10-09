extends Node3D
var LightBroken = false

@onready var DoorNumber = $DoorNumber

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Find the level script and get the current door number
	var level_script = find_level_script()
	if level_script and level_script.has_method("get_current_door_number"):
		DoorNumber.text = level_script.get_current_door_number()
		print("Next Door sign set to: ", DoorNumber.text)
	else:
		print("Warning: Could not find BP_LevelScript or get_current_door_number method")
		DoorNumber.text = "??"
		

func find_level_script() -> Node:
	# Look for BP_LevelScript in the scene tree
	var current_scene = get_tree().current_scene
	
	# First, try to find a node with BP_LevelScript script
	var nodes_to_check = [current_scene]
	
	while nodes_to_check.size() > 0:
		var node = nodes_to_check.pop_front()
		
		# Check if this node has the BP_LevelScript
		if node.get_script() != null:
			var script_path = node.get_script().get_path()
			if script_path.ends_with("BP_LevelScript.gd"):
				return node
		
		# Add children to check
		for child in node.get_children():
			nodes_to_check.append(child)
	
	return null

func light_out():
	if not LightBroken:
		LightBroken = true
		$DoorNumber.shaded = !$DoorNumber.shaded
		$DoorLightArea3D.queue_free()

func _input(event):
	if LightBroken:
		LightBroken = !LightBroken
	if event.is_action_pressed("debug"):
		light_out()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_door_light_area_3d_area_entered(area: Area3D) -> void:
	# Check if the area is the kill area (not trauma area)
	if area.is_in_group("kill_area"):
		#print("Test angler kill area detected by door sign - turning OFF")
		# Only trigger if not already broken
		if not LightBroken:
			light_out()
