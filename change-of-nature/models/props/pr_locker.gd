extends Node3D

@onready var interactable: Area3D = $Interactable
@onready var locker_2: Node3D = $Locker2


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	interactable.interact = _on_interact
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_interact():
		print("locker interacted")
		$Locker2.locker_open()
		interactable.is_interactable = false
