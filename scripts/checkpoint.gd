extends Area3D

@export var respawn_offset: Vector3 = Vector3(0, 1.5, 0)
var is_active: bool = false

@onready var mesh_indicator: MeshInstance3D = get_node_or_null("Indicator")

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_update_visual(false)

func _on_body_entered(body: Node) -> void:
	if body is CharacterBody3D and not is_active:
		is_active = true
		_update_visual(true)
		var level = get_tree().current_scene
		if level and level.has_method("set_checkpoint"):
			level.set_checkpoint(global_position + respawn_offset)

func _update_visual(active: bool) -> void:
	if mesh_indicator and mesh_indicator.material_override is StandardMaterial3D:
		var mat := mesh_indicator.material_override as StandardMaterial3D
		if active:
			mat.albedo_color = Color(0.2, 1.0, 0.4, 1.0)
			mat.emission = Color(0.2, 1.0, 0.4, 1.0)
		else:
			mat.albedo_color = Color(0.2, 0.6, 0.9, 0.7)
			mat.emission = Color(0.1, 0.4, 0.8, 1.0)
