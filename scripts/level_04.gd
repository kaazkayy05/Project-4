extends "res://scripts/level_02.gd"

const FOOTBALL_GREYBOX: PackedScene = preload("res://Purgatory_Act1_Blender_10_Levels/purgatory_act1_greybox/levels/level_04_football__starts_in_locke.glb")
const STADIUM_SPAWN := Vector3(0, 0.1, -3)
const WALKABLE_PARTS := [
	"LOCKER_ROOM_0001", "LOCKER_TUNNEL_0002", "THREE_ROUTE_SPLIT_0003",
	"END_ZONE_MERGE_0004", "LEFT_STANDS_LOWER_0010",
	"RIGHT_STANDS_LOWER_0011", "FIELD_LOWER_0012",
	"LEFT_STANDS_UPPER_0013", "RIGHT_STANDS_UPPER_0014",
	"FIELD_UPPER_0015",
]
const BLOCKING_PARTS := [
	"LOCKER_0005", "LOCKER_0006", "LOCKER_0007", "LOCKER_0008",
	"LOCKER_ROOM_BENCH_0009", "RAISED_BLOCKING_ROW_0019",
	"RAISED_BLOCKING_ROW_0020", "RAISED_BLOCKING_ROW_0021",
	"STORY_ITEM_PEDESTAL_0039", "STORY_ITEM_PEDESTAL_0041",
]

var voice_unlocked := true
var story_count := 0
var voice_label: Label
var football_found := 0


func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player.scream_jump_unlocked = true
	player.wall_run_unlocked = false
	_add_greybox()
	_add_locker_room()
	_add_karma_choices("", "", [Vector3(-9, 0, -5.5), Vector3(9, 0, -5.5)])
	_add_karma_path(true, Vector3(-12, 0, -60), Vector3(-12, 3, -72), 4.0)
	_add_karma_path(false, Vector3(12, 0, -60), Vector3(12, 3, -72), 4.0)
	_add_stadium_atmosphere()
	_add_stadium_details()
	_add_voice_unlock()
	_add_level_pickups()
	_add_finish_stairs()
	_make_hud()
	karma_label.text = "Football karma: 0 / 3"
	story_label.text = "Stands memories: 0 / 2"
	completion_label.text = "LEVEL 4 COMPLETE"
	completion_label.position.y = 145
	voice_label = _label(dash_label.get_parent(), "SCREAM JUMP: HOLD SPACE, RELEASE TO RISE", Vector2(20, 105))
	player.dash_cooldown_changed.connect(_on_dash_changed)
	_on_dash_changed(0.0, player.dash_cooldown_max, true)
	player.jump_charge_changed.connect(_on_jump_charge)
	if OS.is_debug_build():
		assert(is_equal_approx(player.dash_speed, 25.0),
			"Level 4 must reset the Level 3 dash upgrade")
		assert(not player.wall_run_unlocked, "Wall Run unlocks later")


func _add_greybox() -> void:
	var model := FOOTBALL_GREYBOX.instantiate() as Node3D
	model.name = "FootballStadium"
	# The supplied mesh uses Blender's Z-up coordinates.
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
		if part_name.begins_with("KARMA_PICKUP") or part_name.begins_with("STORY_ITEM_PICKUP") or part_name.begins_with("PLAYER_SPAWN") or part_name.begins_with("LEVEL_COMPLETION_TRIGGER") or part_name.begins_with("EXIT_ARCH") or part_name.begins_with("SCREAM_JUMP_CUE"):
			visual.hide()
			continue
		if part_name.begins_with("GOALPOST_"):
			visual.position.y += 8.0
		if part_name.begins_with("FIELD_"):
			var turf := StandardMaterial3D.new()
			turf.albedo_color = Color(0.18, 0.38, 0.25)
			turf.roughness = 1.0
			visual.material_override = turf
		elif part_name.begins_with("LOCKER_000") or part_name.begins_with("LOCKER_ROOM_BENCH"):
			var locker_finish := StandardMaterial3D.new()
			locker_finish.albedo_color = Color(0.26, 0.17, 0.22)
			locker_finish.roughness = 0.7
			visual.material_override = locker_finish
		elif part_name.begins_with("BLEACHERS_STEP_"):
			var bleacher_finish := StandardMaterial3D.new()
			bleacher_finish.albedo_color = Color(0.55, 0.14, 0.19) if visual.mesh.get_aabb().get_center().x < 0.0 else Color(0.14, 0.29, 0.57)
			bleacher_finish.roughness = 0.8
			visual.material_override = bleacher_finish
		if part_name in WALKABLE_PARTS or part_name in BLOCKING_PARTS:
			var bounds := visual.mesh.get_aabb()
			var shape := BoxShape3D.new()
			shape.size = bounds.size
			var collision := CollisionShape3D.new()
			collision.name = "Collision_" + part_name
			collision.shape = shape
			collision.transform = visual.transform * Transform3D(Basis(), bounds.get_center())
			geometry.add_child(collision)


func _add_locker_room() -> void:
	var wall := Color(0.19, 0.24, 0.29)
	var trim := Color(0.46, 0.52, 0.54)
	for x in [-12.2, 12.2]:
		_solid_box("LockerSideWall", Vector3(x, 2.4, -8.5), Vector3(0.4, 4.8, 17), wall)
	_solid_box("LockerBackWall", Vector3(0, 2.4, 0.2), Vector3(24.4, 4.8, 0.4), wall)
	for x in [-9.5, 9.5]:
		_solid_box("LockerFrontWall", Vector3(x, 2.4, -17.2), Vector3(5.4, 4.8, 0.4), wall)
	for x in [-7.2, 7.2]:
		_solid_box("TunnelWall", Vector3(x, 2.3, -26), Vector3(0.4, 4.6, 18), wall)
	_visual_box(Vector3(0, 4.8, -8.5), Vector3(24.2, 0.22, 17), trim)
	_visual_box(Vector3(0, 4.7, -26), Vector3(14.2, 0.22, 18), trim)
	for z in [-5.0, -12.0, -21.0, -30.0]:
		var light := OmniLight3D.new()
		light.position = Vector3(0, 4.1, z)
		light.light_color = Color(0.67, 0.84, 1.0)
		light.light_energy = 1.8
		light.omni_range = 11.0
		add_child(light)
		_visual_box(Vector3(0, 4.47, z), Vector3(3.2, 0.08, 0.38),
			Color(0.64, 0.81, 0.94))
	for x in [-9.0, -5.0, 5.0, 9.0]:
		_visual_box(Vector3(x, 2.0, -3.97), Vector3(1.72, 3.75, 0.05),
			Color(0.29, 0.34, 0.39))
		_visual_box(Vector3(x, 3.8, -3.93), Vector3(1.5, 0.1, 0.07),
			Color(0.53, 0.19, 0.26))
		for vent in range(3):
			_visual_box(Vector3(x, 3.35 - vent * 0.21, -3.92),
				Vector3(1.0, 0.055, 0.04), Color(0.11, 0.15, 0.19))
		_visual_box(Vector3(x + 0.55, 1.55, -3.91),
			Vector3(0.1, 0.45, 0.06), Color(0.78, 0.78, 0.68))
	for z in [-7.55, -8.0, -8.45]:
		_visual_box(Vector3(0, 1.43, z), Vector3(7.7, 0.09, 0.35),
			Color(0.42, 0.25, 0.24))
	for side in [-1.0, 1.0]:
		for z in [-3.2, -6.0, -8.8, -11.6, -14.4]:
			var x: float = side * 11.8
			_visual_box(Vector3(x, 2.1, z), Vector3(0.28, 3.2, 2.25),
				Color(0.29, 0.35, 0.4))
			_visual_box(Vector3(x - side * 0.17, 2.8, z),
				Vector3(0.04, 0.12, 1.15), Color(0.1, 0.15, 0.2))
			_visual_box(Vector3(x - side * 0.17, 1.2, z),
				Vector3(0.04, 0.1, 1.15), Color(0.1, 0.15, 0.2))
			_visual_box(Vector3(x - side * 0.2, 2.0, z + 0.83),
				Vector3(0.05, 0.26, 0.1), Color(0.82, 0.8, 0.65))
	for z in [-2.0, -5.5, -9.0, -12.5, -16.0, -21.0, -26.0, -31.0]:
		_visual_box(Vector3(0, 0.03, z), Vector3(0.13, 0.02, 1.45),
			Color(0.57, 0.19, 0.28))


func _add_stadium_atmosphere() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.04, 0.055, 0.09)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.39, 0.47, 0.6)
	environment.ambient_light_energy = 0.55
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.12, 0.17, 0.24)
	environment.fog_density = 0.004
	world.environment = environment
	add_child(world)
	for x in [-48.0, 48.0]:
		for z in [-47.0, -98.0]:
			_rod(Vector3(x, -1.5, z), Vector3(x, 11.5, z),
				0.18, Color(0.22, 0.27, 0.34))
			_visual_box(Vector3(x, 11.6, z), Vector3(2.9, 0.55, 0.8),
				Color(0.9, 0.91, 0.78))
			var flood := OmniLight3D.new()
			flood.position = Vector3(x, 10.8, z)
			flood.light_color = Color(0.89, 0.9, 0.79)
			flood.light_energy = 2.7
			flood.omni_range = 34.0
			add_child(flood)


func _add_stadium_details() -> void:
	var chalk := Color(0.88, 0.9, 0.81)
	for z in [-49.0, -58.0]:
		_visual_box(Vector3(0, 0.06, z), Vector3(46, 0.025, 0.12), chalk)
	for z in [-77.0, -87.0, -97.0]:
		_visual_box(Vector3(0, 3.06, z), Vector3(46, 0.025, 0.12), chalk)
	for x in [-22.0, 22.0]:
		_visual_box(Vector3(x, 0.055, -55), Vector3(0.12, 0.025, 24), chalk)
		_visual_box(Vector3(x, 3.055, -84), Vector3(0.12, 0.025, 32), chalk)
	for side in [-1.0, 1.0]:
		for z in [-50.0, -58.0, -77.0, -86.0, -95.0]:
			for seat in range(5):
				var x: float = side * (28.0 + seat * 2.5)
				_visual_box(Vector3(x, 0.34 if z > -67.0 else 3.34, z),
					Vector3(1.45, 0.28, 1.3),
					Color(0.68, 0.2, 0.26) if side < 0.0 else Color(0.2, 0.39, 0.72))
	_visual_box(Vector3(0, 0.018, -105), Vector3(48, 0.035, 8),
		Color(0.17, 0.31, 0.22))


func _add_voice_unlock() -> void:
	var area := Area3D.new()
	area.name = "ScreamJumpUnlock"
	area.position = Vector3(0, 1.2, -11)
	area.collision_layer = 0
	area.collision_mask = 1
	var shape := BoxShape3D.new()
	shape.size = Vector3(14, 2.4, 3.2)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	area.add_child(collision)
	add_child(area)
	area.body_entered.connect(_unlock_voice)
	var sign := Label3D.new()
	sign.text = "SCREAM JUMP READY\nHOLD SPACE, THEN RELEASE"
	sign.position = Vector3(0, 2.7, -13.0)
	sign.font_size = 64
	sign.pixel_size = 0.005
	sign.modulate = Color(0.79, 0.62, 0.98)
	add_child(sign)
	var glow := OmniLight3D.new()
	glow.position = Vector3(0, 2.5, -12.0)
	glow.light_color = Color(0.67, 0.42, 0.95)
	glow.light_energy = 2.0
	glow.omni_range = 8.0
	add_child(glow)


func _unlock_voice(body: Node3D) -> void:
	if body != player or voice_unlocked:
		return
	voice_unlocked = true
	player.scream_jump_unlocked = true
	voice_label.text = "SCREAM JUMP: HOLD SPACE, RELEASE TO RISE"


func _on_jump_charge(charge: float, is_charging: bool) -> void:
	if not voice_unlocked:
		return
	voice_label.text = "SCREAM JUMP CHARGE: %d%%" % roundi(charge * 100.0) if is_charging else "SCREAM JUMP: HOLD SPACE, RELEASE TO RISE"


func _add_level_pickups() -> void:
	for at in [Vector3(-35, 3.95, -86), Vector3(0, 3.95, -89),
		Vector3(35, 3.95, -85)]:
		_add_memory_pickup(at, false)
	for at in [Vector3(-36, 4.35, -94), Vector3(35, 4.35, -92)]:
		_add_memory_pickup(at, true)


func _add_memory_pickup(at: Vector3, is_story: bool) -> void:
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
	var material := StandardMaterial3D.new()
	if is_story:
		var ticket := BoxMesh.new()
		ticket.size = Vector3(0.72, 0.56, 0.08)
		visual.mesh = ticket
		material.albedo_color = Color(0.75, 0.55, 0.92)
	else:
		var football := SphereMesh.new()
		football.radius = 0.42
		football.height = 0.63
		visual.mesh = football
		material.albedo_color = Color(0.98, 0.74, 0.19)
	material.emission_enabled = true
	material.emission = material.albedo_color
	material.emission_energy_multiplier = 1.8
	visual.material_override = material
	area.add_child(visual)
	add_child(area)
	area.body_entered.connect(_collect_memory.bind(area, is_story))


func _collect_memory(body: Node3D, area: Area3D, is_story: bool) -> void:
	if body != player or area.is_queued_for_deletion():
		return
	area.set_deferred("monitoring", false)
	area.queue_free()
	if is_story:
		story_count += 1
		story_found = true
		story_label.text = "Stands memories: %d / 2" % story_count
	else:
		karma_collected += 1
		football_found += 1
		karma_label.text = "Football karma: %d / 3" % football_found


func _on_karma_choice(amount: int) -> void:
	karma_collected += amount


func _add_finish_stairs() -> void:
	var pale := Color(0.86, 0.88, 1.0)
	var ramp := StaticBody3D.new()
	ramp.name = "ExitStairRamp"
	ramp.position = Vector3(0, 0.64, -111)
	ramp.rotation.x = atan(1.4 / 6.0)
	var ramp_collision := CollisionShape3D.new()
	var ramp_shape := BoxShape3D.new()
	ramp_shape.size = Vector3(4.0, 0.22, 6.3)
	ramp_collision.shape = ramp_shape
	ramp.add_child(ramp_collision)
	add_child(ramp)
	for step in range(6):
		_visual_box(Vector3(0, 0.16 + step * 0.23, -108.45 - step * 0.95),
			Vector3(4.2, 0.12, 0.95), Color(0.42, 0.43, 0.51))
	_visual_box(Vector3(-2.0, 2.75, -114.1), Vector3(0.2, 2.7, 0.2), pale)
	_visual_box(Vector3(2.0, 2.75, -114.1), Vector3(0.2, 2.7, 0.2), pale)
	_visual_box(Vector3(0, 4.1, -114.1), Vector3(4.2, 0.2, 0.2), pale)
	_visual_box(Vector3(0, 2.75, -114.2), Vector3(3.8, 2.5, 0.08),
		Color(0.72, 0.73, 0.94))
	var area := Area3D.new()
	area.position = Vector3(0, 2.3, -114)
	area.collision_layer = 0
	area.collision_mask = 1
	var trigger := CollisionShape3D.new()
	var trigger_shape := BoxShape3D.new()
	trigger_shape.size = Vector3(3.8, 2.5, 1.0)
	trigger.shape = trigger_shape
	area.add_child(trigger)
	add_child(area)
	area.body_entered.connect(_on_finish)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 3.0, -113.5)
	light.light_color = pale
	light.light_energy = 2.0
	light.omni_range = 8.0
	add_child(light)


func _on_finish(body: Node3D) -> void:
	if body != player or completed:
		return
	completed = true
	player.set_physics_process(false)
	completion_label.text = "LEVEL 4 COMPLETE | FOOTBALL KARMA %d / 3" % football_found
	completion_label.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().call_deferred("change_scene_to_file", "res://scenes/level_05.tscn")


func _process(_delta: float) -> void:
	if not completed and player.global_position.y < -8.0:
		set_process(false)
		get_tree().call_deferred("reload_current_scene")
