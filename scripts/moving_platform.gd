extends AnimatableBody3D

@export var move_offset: Vector3 = Vector3(6.0, 0.0, 0.0)
@export var cycle_duration: float = 3.5

var start_pos: Vector3
var time_elapsed: float = 0.0

func _ready() -> void:
	sync_to_physics = false
	start_pos = position

func _physics_process(delta: float) -> void:
	time_elapsed += delta
	var progress := (sin((time_elapsed / cycle_duration) * TAU - (PI * 0.5)) + 1.0) * 0.5
	position = start_pos + move_offset * progress
