extends "res://scripts/level_02.gd"

const HEARTBROKEN_GREYBOX: PackedScene = preload(
	"res://Purgatory_Act1_Blender_10_Levels/purgatory_act1_greybox/levels/level_10_heartbroken.glb"
)
const HEARTBROKEN_SPAWN := Vector3(0, 0.1, -4)
const FIRST_PLATFORM_LENGTH := 8.0
const WALKABLE_PARTS := [
	"SHATTERED_ENTRY_0001", "ISOLATED_PLATFORM_A_0002",
	"ISOLATED_PLATFORM_B_0003", "ISOLATED_PLATFORM_C_0004",
	"ACT_ONE_END_PLATFORM_0005",
]


func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player.scream_jump_unlocked = true
	player.wall_run_unlocked = true
	_add_greybox()
	_add_karma_choices("", "", karma_points)
	_add_karma_path(true, Vector3(-3, 2, -26.5), Vector3(-3, 2, -47.5), 3.0)
	_add_karma_path(false, Vector3(3, 2, -57.5), Vector3(3, 5, -66.5), 3.0)
	_add_story_pickup()
	_add_finish()
	_make_hud()
	karma_label.hide()
	story_label.text = "Story item: not found"
	completion_label.text = "ACT 1 COMPLETE"
	player.dash_cooldown_changed.connect(_on_dash_changed)
	_on_dash_changed(0.0, player.dash_cooldown_max, true)


func _add_greybox() -> void:
	var model := HEARTBROKEN_GREYBOX.instantiate() as Node3D
	model.name = "HeartbrokenMemory"
	model.rotation.x = -PI * 0.5
	add_child(model)
	var world := model.get_child(0) as Node3D
	var geometry := StaticBody3D.new()
	geometry.name = "HeartbrokenCollision"
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
				or part_name.begins_with("VOID_DEBUG"):
			visual.hide()
			continue
		if part_name == "ISOLATED_PLATFORM_A_0002":
			_shorten_first_platform(visual)
		if not (part_name in WALKABLE_PARTS \
				or part_name.begins_with("WALL_RUN_SURFACE") \
				or part_name.begins_with("STORY_ITEM_PEDESTAL")):
			continue
		var bounds := visual.mesh.get_aabb()
		var shape := BoxShape3D.new()
		shape.size = bounds.size
		var collision := CollisionShape3D.new()
		collision.name = "Collision_" + part_name
		collision.shape = shape
		collision.transform = visual.transform * Transform3D(
			Basis(), bounds.get_center()
		)
		geometry.add_child(collision)


func _shorten_first_platform(visual: MeshInstance3D) -> void:
	var bounds := visual.mesh.get_aabb()
	var material := visual.get_active_material(0)
	var center := bounds.get_center()
	center.y -= (bounds.size.y - FIRST_PLATFORM_LENGTH) * 0.5
	var platform := BoxMesh.new()
	platform.size = Vector3(bounds.size.x, FIRST_PLATFORM_LENGTH, bounds.size.z)
	visual.transform = visual.transform * Transform3D(Basis(), center)
	visual.mesh = platform
	visual.material_override = material


func _add_story_pickup() -> void:
	var area := Area3D.new()
	area.position = Vector3(6, 6.5, -93)
	area.collision_layer = 0
	area.collision_mask = 1
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 1.1
	collision.shape = shape
	area.add_child(collision)
	var visual := MeshInstance3D.new()
	var keepsake := BoxMesh.new()
	keepsake.size = Vector3(0.72, 0.56, 0.08)
	visual.mesh = keepsake
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.8, 0.38, 0.86)
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
	story_label.text = "Story item: final contradiction"


func _add_finish() -> void:
	var area := Area3D.new()
	area.position = Vector3(0, 6.2, -98)
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


func _process(_delta: float) -> void:
	if not completed and player.global_position.y < -8.0:
		set_process(false)
		get_tree().call_deferred("reload_current_scene")
