extends "res://scripts/level_02.gd"

const HALLOWEEN_SPAWN := Vector3(-20, 0.1, 0)
const REQUIRED_COLLECTIBLES := 5
const FINAL_GAP := 8.0

var collected_items := 0
var dash_upgraded := false
var base_dash_speed := 0.0
var upgrade_label: Label


func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player.get_node("CameraPivot").rotation.y = -PI * 0.5
	base_dash_speed = player.dash_speed
	_add_floor("EntranceYard", Vector3(-20, -0.35, 0), Vector3(8, 0.7, 8))
	_add_floor("EntranceWalk", Vector3(-14, -0.35, 0), Vector3(8, 0.7, 4))
	_add_floor("CentralStem", Vector3(-10, -0.35, -2), Vector3(4, 0.7, 24))
	_add_floor("UpperLeftRun", Vector3(-6, -0.35, -14), Vector3(32, 0.7, 4))
	_add_floor("LeftRise", Vector3(-22, -0.35, -19.5), Vector3(4, 0.7, 11))
	_add_floor("LeftEnd", Vector3(-29, -0.35, -25), Vector3(14, 0.7, 4))
	_add_floor("LeftTip", Vector3(-36, -0.35, -28), Vector3(4, 0.7, 6))
	_add_floor("UpperRightRun", Vector3(22.5, -0.35, -14), Vector3(15, 0.7, 4))
	_add_floor("RightRise", Vector3(30, -0.35, -19.5), Vector3(4, 0.7, 11))
	_add_floor("RightEnd", Vector3(37, -0.35, -25), Vector3(14, 0.7, 4))
	_add_floor("ExitYard", Vector3(-10, -0.35, 20), Vector3(4, 0.7, 4))
	_add_atmosphere()
	_add_halloween_props()
	_add_pickup(Vector3(-36, 1.0, -28), false)
	_add_pickup(Vector3(-28, 1.0, -25), false)
	_add_pickup(Vector3(0, 1.0, -14), false)
	_add_pickup(Vector3(38, 1.0, -25), false)
	_add_pickup(Vector3(30, 1.0, -20), true)
	_add_finish()
	_make_hud()
	karma_label.text = "Candy karma: 0"
	completion_label.text = "LEVEL 3 COMPLETE"
	completion_label.position.y = 142
	upgrade_label = _label(dash_label.get_parent(), "DASH DISTANCE +50%", Vector2(20, 105))
	upgrade_label.hide()
	player.dash_cooldown_changed.connect(_on_dash_changed)
	_on_dash_changed(0.0, player.dash_cooldown_max, true)
	if OS.is_debug_build():
		assert(base_dash_speed * player.dash_duration < FINAL_GAP,
			"Original dash must not cross the final gap")
		assert(base_dash_speed * 1.5 * player.dash_duration > FINAL_GAP,
			"Upgraded dash must cross the final gap")
		assert(18.0 - 10.0 == FINAL_GAP, "Lower stem gap must match dash gate")
		assert(15.0 - 10.0 < base_dash_speed * player.dash_duration,
			"Upper branch gap must be crossable with the original dash")


func _add_floor(floor_name: String, center: Vector3, size: Vector3) -> void:
	_solid_box(floor_name, center, size, Color(0.17, 0.13, 0.19))
	_visual_box(center + Vector3(0, size.y * 0.5 + 0.02, 0),
		Vector3(size.x, 0.04, size.z), Color(0.28, 0.23, 0.3))
	# Sparse paving breaks up the otherwise solid memory-platform surface.
	var count := maxi(1, floori(size.z / 3.5))
	for index in range(count):
		var z := center.z - size.z * 0.5 + (index + 0.5) * size.z / count
		_visual_box(Vector3(center.x, 0.055, z),
			Vector3(minf(size.x - 0.35, 4.0), 0.02, 0.055),
			Color(0.36, 0.3, 0.39))


func _add_atmosphere() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.016, 0.009, 0.035)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.4, 0.32, 0.58)
	environment.ambient_light_energy = 0.4
	environment.ambient_light_sky_contribution = 0.0
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.2, 0.1, 0.28)
	environment.fog_density = 0.012
	world.environment = environment
	add_child(world)
	for at in [Vector3(-20, 3, 0), Vector3(-10, 3, -14),
		Vector3(-30, 3, -25), Vector3(22, 3, -14),
		Vector3(38, 3, -25), Vector3(-10, 3, 20)]:
		var glow := OmniLight3D.new()
		glow.position = at
		glow.light_color = Color(1.0, 0.38, 0.12)
		glow.light_energy = 1.4
		glow.omni_range = 12.0
		add_child(glow)


func _add_halloween_props() -> void:
	for at in [Vector3(-22.8, 0, -2.7), Vector3(-17, 0, 2.7),
		Vector3(-11.4, 0, -8), Vector3(-20.5, 0, -14.8),
		Vector3(-27, 0, -25.8), Vector3(-35, 0, -29.7),
		Vector3(5, 0, -15.4), Vector3(18, 0, -12.7),
		Vector3(29, 0, -19), Vector3(40, 0, -26)]:
		_add_pumpkin(at)
	for at in [Vector3(-23.3, 0, 2.8), Vector3(-21.1, 0, -23.9),
		Vector3(23, 0, -15.3)]:
		_add_gravestone(at)
	_add_house(Vector3(-22.3, 0, 3.0), Vector3(2.8, 2.8, 2.0))
	_add_house(Vector3(-36, 0, -32), Vector3(3.2, 3.0, 2.2))
	_add_house(Vector3(43.5, 0, -25), Vector3(2.8, 3.3, 2.0))
	_add_sign(Vector3(-20, 3.0, -3.0), "TRICK OR TREAT")
	_add_sign(Vector3(-10, 3.0, 19.0), "THE WAY OUT")
	# The lighted posts mark the launch edge without filling the gap.
	for x in [-11.65, -8.35]:
		_rod(Vector3(x, 0, 9.6), Vector3(x, 1.4, 9.6),
			0.08, Color(0.41, 0.28, 0.26))
		_visual_box(Vector3(x, 1.5, 9.6), Vector3(0.32, 0.23, 0.32),
			Color(0.88, 0.37, 0.1))


func _add_house(at: Vector3, size: Vector3) -> void:
	var wall := Color(0.16, 0.12, 0.2)
	var roof := Color(0.09, 0.08, 0.14)
	_solid_box("HouseFoundation", at + Vector3(0, -0.18, 0),
		Vector3(size.x + 1.2, 0.36, size.z + 1.2), Color(0.24, 0.2, 0.28))
	_visual_box(at + Vector3(0, size.y * 0.5, 0), size, wall)
	for side in [-1.0, 1.0]:
		var slope := BoxMesh.new()
		slope.size = Vector3(size.x * 0.65, 0.14, size.z + 0.3)
		var visual := _mesh(slope,
			at + Vector3(side * size.x * 0.23, size.y + 0.35, 0), roof)
		visual.rotation.z = side * 0.43
	var front_z := at.z + size.z * 0.5 + 0.04
	_visual_box(Vector3(at.x, 0.86, front_z), Vector3(0.78, 1.72, 0.08),
		Color(0.31, 0.14, 0.1))
	for side in [-1.0, 1.0]:
		var window := BoxMesh.new()
		window.size = Vector3(0.43, 0.5, 0.08)
		_mesh(window, Vector3(at.x + side * size.x * 0.31, 1.75, front_z),
			Color(0.98, 0.62, 0.2), true)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(at.x, 2.2, front_z + 0.2)
	lamp.light_color = Color(1.0, 0.62, 0.27)
	lamp.light_energy = 0.9
	lamp.omni_range = 5.0
	add_child(lamp)
	var bowl := CylinderMesh.new()
	bowl.top_radius = 0.34
	bowl.bottom_radius = 0.22
	bowl.height = 0.18
	_mesh(bowl, Vector3(at.x + 0.7, 0.22, front_z + 0.48),
		Color(0.48, 0.16, 0.09))


func _add_pumpkin(at: Vector3) -> void:
	var orange := Color(0.78, 0.24, 0.055)
	var core := SphereMesh.new()
	core.radius = 0.53
	core.height = 0.78
	_mesh(core, at + Vector3(0, 0.4, 0), orange)
	for index in range(8):
		var angle := TAU * index / 8.0
		var rib := SphereMesh.new()
		rib.radius = 0.25
		rib.height = 0.69
		_mesh(rib, at + Vector3(cos(angle) * 0.36, 0.39,
			sin(angle) * 0.36), Color(0.82, 0.29, 0.06))
	_rod(at + Vector3(0, 0.72, 0), at + Vector3(0.08, 1.02, 0),
		0.075, Color(0.13, 0.36, 0.14))
	var lamp := OmniLight3D.new()
	lamp.position = at + Vector3(0, 0.55, 0)
	lamp.light_color = Color(1.0, 0.35, 0.08)
	lamp.light_energy = 0.35
	lamp.omni_range = 3.2
	add_child(lamp)


func _add_gravestone(at: Vector3) -> void:
	var stone := Color(0.43, 0.43, 0.5)
	_visual_box(at + Vector3(0, 0.55, 0), Vector3(0.85, 1.1, 0.25), stone)
	var top := SphereMesh.new()
	top.radius = 0.43
	top.height = 0.42
	_mesh(top, at + Vector3(0, 1.1, 0), stone)
	_visual_box(at + Vector3(0, 0.7, -0.14),
		Vector3(0.09, 0.42, 0.02), Color(0.26, 0.25, 0.3))
	_visual_box(at + Vector3(0, 0.78, -0.15),
		Vector3(0.3, 0.08, 0.02), Color(0.26, 0.25, 0.3))


func _add_pickup(at: Vector3, is_story: bool) -> void:
	var area := Area3D.new()
	area.position = at
	area.collision_layer = 0
	area.collision_mask = 1
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 1.0
	collision.shape = shape
	area.add_child(collision)
	var color := Color(0.78, 0.35, 0.92) if is_story else Color(1.0, 0.71, 0.13)
	if is_story:
		var photo := BoxMesh.new()
		photo.size = Vector3(0.7, 0.85, 0.06)
		_pickup_visual(area, photo, Vector3.ZERO, color)
		var image := BoxMesh.new()
		image.size = Vector3(0.52, 0.5, 0.065)
		_pickup_visual(area, image, Vector3(0, 0.1, -0.01),
			Color(0.22, 0.17, 0.34))
	else:
		var candy := SphereMesh.new()
		candy.radius = 0.42
		candy.height = 0.48
		_pickup_visual(area, candy, Vector3.ZERO, color)
		for side in [-1.0, 1.0]:
			var wrapper := CylinderMesh.new()
			wrapper.top_radius = 0.22
			wrapper.bottom_radius = 0.04
			wrapper.height = 0.4
			var visual := _pickup_visual(area, wrapper,
				Vector3(side * 0.52, 0, 0), Color(1.0, 0.42, 0.1))
			visual.rotation.z = side * PI * 0.5
	add_child(area)
	area.body_entered.connect(_collect.bind(area, is_story))


func _pickup_visual(parent: Node3D, shape: Mesh, at: Vector3,
		color: Color) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.mesh = shape
	visual.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.3
	visual.material_override = material
	parent.add_child(visual)
	return visual


func _collect(body: Node3D, area: Area3D, is_story: bool) -> void:
	if body != player or area.is_queued_for_deletion():
		return
	area.set_deferred("monitoring", false)
	area.queue_free()
	collected_items += 1
	if is_story:
		story_found = true
		story_label.text = "Story item: torn Halloween photo"
	else:
		karma_collected += 1
		karma_label.text = "Candy karma: %d" % karma_collected
	if collected_items == REQUIRED_COLLECTIBLES:
		dash_upgraded = true
		player.dash_speed = base_dash_speed * 1.5
		upgrade_label.show()


func _add_finish() -> void:
	var pale := Color(0.88, 0.78, 1.0)
	_visual_box(Vector3(-11.4, 1.7, 21), Vector3(0.18, 3.4, 0.25), pale)
	_visual_box(Vector3(-8.6, 1.7, 21), Vector3(0.18, 3.4, 0.25), pale)
	_visual_box(Vector3(-10, 3.4, 21), Vector3(3.0, 0.18, 0.25), pale)
	var area := Area3D.new()
	area.position = Vector3(-10, 1.2, 21)
	area.collision_layer = 0
	area.collision_mask = 1
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.6, 2.4, 0.7)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	area.add_child(collision)
	add_child(area)
	area.body_entered.connect(_on_finish)
	var glow := OmniLight3D.new()
	glow.position = Vector3(-10, 2.4, 20.5)
	glow.light_color = pale
	glow.light_energy = 1.5
	glow.omni_range = 7.0
	add_child(glow)


func _on_finish(body: Node3D) -> void:
	if body != player or completed:
		return
	if not dash_upgraded:
		upgrade_label.text = "COLLECT ALL CANDY AND THE STORY ITEM"
		upgrade_label.show()
		return
	completed = true
	player.set_physics_process(false)
	completion_label.text = "LEVEL 3 COMPLETE | CANDY KARMA %d" % karma_collected
	completion_label.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(_delta: float) -> void:
	if not completed and player.global_position.y < -5.0:
		player.respawn(HALLOWEEN_SPAWN)
