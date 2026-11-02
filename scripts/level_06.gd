extends "res://scripts/level_02.gd"

const FOOTBALL_GREYBOX: PackedScene = preload(
	"res://Purgatory_Act1_Blender_10_Levels/purgatory_act1_greybox/levels/level_06_football__starts_in_locke.glb"
)
const STADIUM_SPAWN := Vector3(0, 0.1, -7)
const LOWER_PLATFORM_LENGTH := 6.0
const WALKABLE_PARTS := [
	"LOCKER_ROOM_0001", "LOCKER_TUNNEL_0002", "THREE_ROUTE_SPLIT_0003",
	"END_ZONE_MERGE_0004", "LEFT_STANDS_LOWER_0010",
	"RIGHT_STANDS_LOWER_0011", "FIELD_LOWER_0012",
	"LEFT_STANDS_FINAL_0013", "RIGHT_STANDS_FINAL_0014",
	"FIELD_FINAL_0015",
]

var story_count := 0


func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player.scream_jump_unlocked = true
	player.wall_run_unlocked = true
	_add_greybox()
	_add_story_pickup(Vector3(-36, 4.0, -94))
	_add_story_pickup(Vector3(35, 4.0, -92))
	_add_finish()
	_make_hud()
	karma_label.hide()
	story_label.text = "Stands memories: 0 / 2"
	completion_label.text = "LEVEL 6 COMPLETE"
	player.dash_cooldown_changed.connect(_on_dash_changed)
	_on_dash_changed(0.0, player.dash_cooldown_max, true)


func _add_greybox() -> void:
	var model := FOOTBALL_GREYBOX.instantiate() as Node3D
	model.name = "FootballStadiumRevisited"
	model.rotation.x = -PI * 0.5
	add_child(model)
	var world := model.get_child(0) as Node3D
	var geometry := StaticBody3D.new()
	geometry.name = "StadiumCollision"
	world.add_child(geometry)
	for part in world.get_children():
		if not part is MeshInstance3D:
			continue
		var visual := part as MeshInstance3D
		var part_name := String(visual.name)
		if part_name.begins_with("KARMA_PICKUP") \
				or part_name.begins_with("STORY_ITEM_PICKUP") \
				or part_name.begins_with("PLAYER_SPAWN") \
				or part_name.begins_with("LEVEL_COMPLETION_TRIGGER") \
				or part_name.begins_with("VOID_DEBUG"):
			visual.hide()
			continue
		if part_name in WALKABLE_PARTS and part_name.contains("_LOWER_"):
			_shorten_lower_platform(visual)
		if not (part_name in WALKABLE_PARTS \
				or part_name.begins_with("LOCKER_000") \
				or part_name.begins_with("LOCKER_ROOM_BENCH") \
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


func _shorten_lower_platform(visual: MeshInstance3D) -> void:
	var bounds := visual.mesh.get_aabb()
	var material := visual.get_active_material(0)
	var center := bounds.get_center()
	center.y -= (bounds.size.y - LOWER_PLATFORM_LENGTH) * 0.5
	var platform := BoxMesh.new()
	platform.size = Vector3(bounds.size.x, LOWER_PLATFORM_LENGTH, bounds.size.z)
	visual.transform = visual.transform * Transform3D(Basis(), center)
	visual.mesh = platform
	visual.material_override = material


func _add_story_pickup(at: Vector3) -> void:
	var area := Area3D.new()
	area.position = at
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
	material.albedo_color = Color(0.75, 0.55, 0.92)
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
	story_count += 1
	story_found = true
	story_label.text = "Stands memories: %d / 2" % story_count


func _add_finish() -> void:
	var area := Area3D.new()
	area.position = Vector3(0, 1.2, -111)
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
	get_tree().call_deferred("change_scene_to_file", "res://scenes/level_07.tscn")


func _process(_delta: float) -> void:
	if not completed and player.global_position.y < -8.0:
		set_process(false)
		get_tree().call_deferred("reload_current_scene")
