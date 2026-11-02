extends "res://scripts/level_02.gd"

const FUNERAL_GREYBOX: PackedScene = preload(
	"res://Purgatory_Act1_Blender_10_Levels/purgatory_act1_greybox/levels/level_05_grim_funeral.glb"
)
const FUNERAL_SPAWN := Vector3(0, 0.1, -5)
const MAZE_WALL_EXTENSION := 3.0


func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player.scream_jump_unlocked = true
	player.wall_run_unlocked = false
	_add_greybox()
	_add_karma_choices("", "", karma_points)
	_add_story_pickup()
	_add_finish()
	_make_hud()
	karma_label.hide()
	story_label.text = "Story item: not found"
	completion_label.text = "LEVEL 5 COMPLETE"
	player.dash_cooldown_changed.connect(_on_dash_changed)
	_on_dash_changed(0.0, player.dash_cooldown_max, true)


func _add_greybox() -> void:
	var model := FUNERAL_GREYBOX.instantiate() as Node3D
	model.name = "FuneralMaze"
	model.rotation.x = -PI * 0.5
	add_child(model)
	var world := model.get_child(0) as Node3D
	var geometry := StaticBody3D.new()
	geometry.name = "FuneralCollision"
	world.add_child(geometry)
	for part in world.get_children():
		if not part is MeshInstance3D:
			continue
		var visual := part as MeshInstance3D
		var part_name := String(visual.name)
		if part_name.begins_with("KARMA_PICKUP"):
			karma_points.append(visual.global_transform * visual.mesh.get_aabb().get_center())
		if part_name.begins_with("KARMA_PICKUP") \
				or part_name.begins_with("STORY_ITEM_PICKUP") \
				or part_name.begins_with("PLAYER_SPAWN") \
				or part_name.begins_with("LEVEL_COMPLETION_TRIGGER") \
				or part_name.begins_with("SCREAM_JUMP_CUE"):
			visual.hide()
			continue
		if not (part_name.begins_with("FUNERAL_ARRIVAL") \
				or part_name.begins_with("CEMETERY_MAZE_WALKABLE") \
				or part_name.begins_with("MAZE_") \
				or part_name.begins_with("CHAPEL_") \
				or part_name.begins_with("COFFIN_") \
				or part_name.begins_with("STORY_ITEM_PEDESTAL")):
			continue
		var bounds := visual.mesh.get_aabb()
		var shape := BoxShape3D.new()
		shape.size = bounds.size
		var collision_center := bounds.get_center()
		if part_name.begins_with("MAZE_"):
			shape.size.z += MAZE_WALL_EXTENSION
			collision_center.z += MAZE_WALL_EXTENSION * 0.5
			var cap := MeshInstance3D.new()
			cap.name = "Raised_" + part_name
			var cap_mesh := BoxMesh.new()
			cap_mesh.size = Vector3(bounds.size.x, bounds.size.y, MAZE_WALL_EXTENSION)
			cap.mesh = cap_mesh
			cap.material_override = visual.get_active_material(0)
			cap.transform = visual.transform * Transform3D(Basis(),
				bounds.get_center() + Vector3(0, 0,
					(bounds.size.z + MAZE_WALL_EXTENSION) * 0.5))
			world.add_child(cap)
		var collision := CollisionShape3D.new()
		collision.name = "Collision_" + part_name
		collision.shape = shape
		collision.transform = visual.transform * Transform3D(
			Basis(), collision_center
		)
		geometry.add_child(collision)


func _add_story_pickup() -> void:
	var area := Area3D.new()
	area.position = Vector3(-16, 1.5, -26)
	area.collision_layer = 0
	area.collision_mask = 1
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 1.1
	collision.shape = shape
	area.add_child(collision)
	var visual := MeshInstance3D.new()
	var keepsake := BoxMesh.new()
	keepsake.size = Vector3(0.7, 0.8, 0.08)
	visual.mesh = keepsake
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.72, 0.55, 0.9)
	material.emission_enabled = true
	material.emission = material.albedo_color
	visual.material_override = material
	area.add_child(visual)
	add_child(area)
	area.body_entered.connect(_collect_story.bind(area))


func _collect_story(body: Node3D, area: Area3D) -> void:
	if body != player or area.is_queued_for_deletion():
		return
	area.set_deferred("monitoring", false)
	area.queue_free()
	story_found = true
	story_label.text = "Story item: funeral recollection"


func _add_finish() -> void:
	var area := Area3D.new()
	area.position = Vector3(0, 1.2, -85)
	area.collision_layer = 0
	area.collision_mask = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.2, 2.4, 1.0)
	collision.shape = shape
	area.add_child(collision)
	add_child(area)
	area.body_entered.connect(_on_finish)


func _on_finish(body: Node3D) -> void:
	if body != player or completed:
		return
	completed = true
	player.set_physics_process(false)
	completion_label.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().call_deferred("change_scene_to_file", "res://scenes/level_06.tscn")


func _process(_delta: float) -> void:
	if not completed and player.global_position.y < -5.0:
		set_process(false)
		get_tree().call_deferred("reload_current_scene")
