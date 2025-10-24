extends Node3D

@export var variants: Array[PackedScene] = []
@export var pick_random_on_ready: bool = true
@export var pick_nothing_chance: float = 0.0 # 0.0 = never pick nothing, 1.0 = always pick nothing

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$"Prop Bounds".visible = false
	# If variants are provided and the flag is enabled, pick one at random and instantiate it
	if pick_random_on_ready and not variants.is_empty():
		var rng = RandomNumberGenerator.new()
		rng.randomize()

		# Chance to pick nothing
		if rng.randf() < pick_nothing_chance:
			print("medium_prop: roll chosen to pick NOTHING (chance: ", pick_nothing_chance, ")")
			return
		var idx = rng.randi_range(0, variants.size() - 1)
		var scene : PackedScene = variants[idx]
		if scene:
			var inst = scene.instantiate()
			add_child(inst)
			# If the instantiated node is 3D, reset its transform so it sits at this node's origin
			if inst is Node3D:
				inst.transform = Transform3D.IDENTITY
			print("medium_prop: instantiated variant ", idx)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
