extends "res://scripts/level_02.gd"

const HALLOWEEN_SPAWN := Vector3(-20, 0.1, 0)
const REQUIRED_COLLECTIBLES := 5
const FINAL_GAP := 8.0
const HALLOWEEN_MODELS: PackedScene = preload("res://Models/HALLOWEEN_STREET_10_HOUSES_5_TREES.glb")
const SIDEWALK_WIDTH := 1.2
const GRASS_VERGE_WIDTH := 3.6
const HOUSE_PLOTS := [
	[1, Vector2(-30, -23), Vector2(0, 1)],
	[2, Vector2(-8, -6), Vector2(1, 0)],
	[3, Vector2(38, -23), Vector2(0, 1)],
	[4, Vector2(-8, 5), Vector2(1, 0)],
	[5, Vector2(-14, -16), Vector2(0, -1)],
	[6, Vector2(3, -12), Vector2(0, 1)],
	[7, Vector2(22, -16), Vector2(0, -1)],
	[8, Vector2(22, -12), Vector2(0, 1)],
	[9, Vector2(-28, -27), Vector2(0, -1)],
	[10, Vector2(37, -27), Vector2(0, -1)],
]
const WALKABLE_RECTS := [
	Rect2(-24, -4, 8, 8), Rect2(-18, -2, 8, 4),
	Rect2(-12, -14, 4, 24), Rect2(-22, -16, 32, 4),
	Rect2(-24, -25, 4, 11), Rect2(-36, -27, 14, 4),
	Rect2(-38, -31, 4, 6), Rect2(15, -16, 15, 4),
	Rect2(28, -25, 4, 11), Rect2(30, -27, 14, 4),
	Rect2(-12, 18, 4, 4),
]

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
	_solid_box(floor_name, center, size, Color(0.075, 0.07, 0.095))
	_visual_box(Vector3(center.x, 0.018, center.z),
		Vector3(size.x, 0.035, size.z), Color(0.115, 0.105, 0.13))
	var horizontal := size.x > size.z
	if floor_name == "EntranceYard":
		horizontal = true
	var half_width := (size.z if horizontal else size.x) * 0.5
	var road_length := size.x if horizontal else size.z
	# Narrow concrete gutters and pale shoulder lines frame the asphalt.
	for side in [-1.0, 1.0]:
		_add_road_curb(center, size, horizontal, side)
		if horizontal:
			_visual_box(Vector3(center.x, 0.038, center.z + side * (half_width - 0.43)),
				Vector3(road_length, 0.012, 0.065), Color(0.58, 0.51, 0.43))
		else:
			_visual_box(Vector3(center.x + side * (half_width - 0.43), 0.038, center.z),
				Vector3(0.065, 0.012, road_length), Color(0.58, 0.51, 0.43))
	# Uneven amber center dashes make the existing route read as a street.
	for index in range(maxi(1, floori(road_length / 2.9))):
		var along := -road_length * 0.5 + 1.4 + index * 2.9
		if absf(along) > road_length * 0.5 - 0.65:
			continue
		if horizontal:
			_visual_box(Vector3(center.x + along, 0.043, center.z),
				Vector3(1.15, 0.012, 0.08), Color(0.78, 0.47, 0.14))
		else:
			_visual_box(Vector3(center.x, 0.043, center.z + along),
				Vector3(0.08, 0.012, 1.15), Color(0.78, 0.47, 0.14))


func _add_road_curb(center: Vector3, size: Vector3,
		horizontal: bool, side: float) -> void:
	var length := size.x if horizontal else size.z
	var half_width := (size.z if horizontal else size.x) * 0.5
	var count := maxi(1, ceili(length / 1.0))
	var segment_length := length / count
	var outward := Vector2(0, side) if horizontal else Vector2(side, 0)
	for index in range(count):
		var along := -length * 0.5 + (index + 0.5) * segment_length
		var edge := Vector2(center.x + along, center.z + side * half_width) if horizontal else Vector2(center.x + side * half_width, center.z + along)
		if not _scenery_footprint_clear(edge + outward * 0.18, Vector2(0.2, 0.2)):
			continue
		var at_house_path := false
		for plot in HOUSE_PLOTS:
			var house_edge: Vector2 = plot[1]
			var house_outward: Vector2 = plot[2]
			if outward == house_outward and edge.distance_to(house_edge) < 1.05:
				at_house_path = true
				break
		if at_house_path:
			continue
		var at := Vector3(edge.x - outward.x * 0.13, 0.055,
			edge.y - outward.y * 0.13)
		var curb_size := Vector3(segment_length, 0.11, 0.25) if horizontal else Vector3(0.25, 0.11, segment_length)
		_visual_box(at, curb_size, Color(0.31, 0.28, 0.31))


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
	_add_neighborhood_screen()
	_add_sign(Vector3(-20, 3.0, -3.0), "TRICK OR TREAT")
	_add_sign(Vector3(-10, 3.0, 19.0), "THE WAY OUT")
	# The lighted posts mark the launch edge without filling the gap.
	for x in [-11.65, -8.35]:
		_rod(Vector3(x, 0, 9.6), Vector3(x, 1.4, 9.6),
			0.08, Color(0.41, 0.28, 0.26))
		_visual_box(Vector3(x, 1.5, 9.6), Vector3(0.32, 0.23, 0.32),
			Color(0.88, 0.37, 0.1))


func _add_neighborhood_screen() -> void:
	# Each frontage faces a platform edge. The short sides stay open at both dash gaps.
	var frontages := [
		[Vector2(-24, -4), Vector2(-16, -4), Vector2(0, -1)],
		[Vector2(-24, 4), Vector2(-16, 4), Vector2(0, 1)],
		[Vector2(-18, -2), Vector2(-12, -2), Vector2(0, -1)],
		[Vector2(-18, 2), Vector2(-12, 2), Vector2(0, 1)],
		[Vector2(-12, -14), Vector2(-12, 10), Vector2(-1, 0)],
		[Vector2(-8, -12), Vector2(-8, 10), Vector2(1, 0)],
		[Vector2(-22, -16), Vector2(10, -16), Vector2(0, -1)],
		[Vector2(-20, -12), Vector2(10, -12), Vector2(0, 1)],
		[Vector2(-24, -25), Vector2(-24, -16), Vector2(-1, 0)],
		[Vector2(-20, -25), Vector2(-20, -16), Vector2(1, 0)],
		[Vector2(-36, -27), Vector2(-24, -27), Vector2(0, -1)],
		[Vector2(-34, -23), Vector2(-24, -23), Vector2(0, 1)],
		[Vector2(-38, -31), Vector2(-38, -27), Vector2(-1, 0)],
		[Vector2(15, -16), Vector2(30, -16), Vector2(0, -1)],
		[Vector2(15, -12), Vector2(28, -12), Vector2(0, 1)],
		[Vector2(28, -25), Vector2(28, -16), Vector2(-1, 0)],
		[Vector2(32, -25), Vector2(32, -16), Vector2(1, 0)],
		[Vector2(32, -27), Vector2(44, -27), Vector2(0, -1)],
		[Vector2(32, -23), Vector2(44, -23), Vector2(0, 1)],
		[Vector2(-12, 18), Vector2(-12, 22), Vector2(-1, 0)],
		[Vector2(-8, 18), Vector2(-8, 22), Vector2(1, 0)],
	]
	var source := HALLOWEEN_MODELS.instantiate()
	var house_models: Dictionary = {}
	var tree_models: Dictionary = {}
	for part in source.get_children():
		if part.name.contains("HOUSE_"):
			for number in range(1, 11):
				if part.name.contains("HOUSE_%02d" % number):
					source.remove_child(part)
					house_models[number] = part
					break
		elif part.name.contains("SPOOKY_TREE_"):
			for number in range(1, 6):
				if part.name.contains("SPOOKY_TREE_%02d" % number):
					source.remove_child(part)
					tree_models[number] = part
					break
	source.free() # Discard the asset's straight presentation road and cameras.
	# Road-edge anchors keep every modeled walkway connected to the existing route.
	_add_neighborhood_ground(frontages)
	var house_scale := 0.45
	for plot in HOUSE_PLOTS:
		var number: int = plot[0]
		var edge: Vector2 = plot[1]
		var outward: Vector2 = plot[2]
		var house: Node3D = house_models[number]
		var root_at := edge + outward * (18.0 * house_scale)
		house.position = Vector3(root_at.x, 0, root_at.y)
		house.rotation.y = atan2(-outward.x, -outward.y)
		house.scale = Vector3.ONE * house_scale
		add_child(house)
		_make_model_walkway_walkable(house)
	var tree_index := 0
	for frontage in frontages:
		var start: Vector2 = frontage[0]
		var finish: Vector2 = frontage[1]
		var outward: Vector2 = frontage[2]
		var length := start.distance_to(finish)
		var tangent := (finish - start) / length
		var count := maxi(1, ceili(length / 5.0))
		for slot in range(count):
			var edge := start + tangent * ((slot + 0.5) * length / count)
			var tree_at := edge + outward * 3.0
			var by_house := false
			for plot in HOUSE_PLOTS:
				var house_edge: Vector2 = plot[1]
				var house_outward: Vector2 = plot[2]
				var along_path := clampf((tree_at - house_edge).dot(house_outward), 0.0, 6.5)
				var nearest_path := house_edge + house_outward * along_path
				if tree_at.distance_to(nearest_path) < 3.2 or (
					outward == house_outward and edge.distance_to(house_edge) < 5.5):
					by_house = true
					break
			if by_house:
				continue
			if not _scenery_footprint_clear(tree_at, Vector2(2.0, 2.0)):
				continue
			var tree_type := tree_index % 5 + 1
			var tree: Node3D = tree_models[tree_type].duplicate()
			tree.position = Vector3(tree_at.x, 0, tree_at.y)
			tree.rotation.y = float(tree_index % 7) * 0.43
			tree.scale = Vector3.ONE * 0.45
			add_child(tree)
			tree_index += 1
	for template in tree_models.values():
		template.free()


func _add_neighborhood_ground(frontages: Array) -> void:
	for frontage in frontages:
		var start: Vector2 = frontage[0]
		var finish: Vector2 = frontage[1]
		var outward: Vector2 = frontage[2]
		var length := start.distance_to(finish)
		var tangent := (finish - start) / length
		var count := maxi(1, ceili(length / 1.8))
		var segment_length := length / count
		for index in range(count):
			var edge := start + tangent * ((index + 0.5) * segment_length)
			var sidewalk_at := edge + outward * (SIDEWALK_WIDTH * 0.5)
			var sidewalk_size := Vector2(segment_length, SIDEWALK_WIDTH) if outward.y != 0 else Vector2(SIDEWALK_WIDTH, segment_length)
			if _scenery_footprint_clear(sidewalk_at, sidewalk_size):
				_add_walkable_ground("NeighborhoodSidewalk", sidewalk_at,
					sidewalk_size, Color(0.29, 0.28, 0.28), 0.012)
			var grass_at := edge + outward * (SIDEWALK_WIDTH + GRASS_VERGE_WIDTH * 0.5)
			var grass_size := Vector2(segment_length, GRASS_VERGE_WIDTH) if outward.y != 0 else Vector2(GRASS_VERGE_WIDTH, segment_length)
			if _scenery_footprint_clear(grass_at, grass_size):
				_add_walkable_ground("NeighborhoodGrass", grass_at,
					grass_size, Color(0.15, 0.22, 0.145), -0.012)


func _add_walkable_ground(ground_name: String, at: Vector2,
		size: Vector2, color: Color, visual_offset: float) -> void:
	var body := StaticBody3D.new()
	body.name = ground_name
	body.position = Vector3(at.x, -0.18, at.y)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x, 0.36, size.y)
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	var surface := BoxMesh.new()
	surface.size = shape.size
	_mesh(surface, body.position + Vector3(0, visual_offset, 0), color)


func _make_model_walkway_walkable(house: Node3D) -> void:
	var path_body := StaticBody3D.new()
	path_body.name = "DoorPathCollision"
	house.add_child(path_body)
	var backing_material := StandardMaterial3D.new()
	backing_material.albedo_color = Color(0.13, 0.11, 0.12)
	backing_material.roughness = 1.0
	var paver_count := 0
	for piece in house.get_children():
		if piece.name.begins_with("WALKWAY "):
			var shape := BoxShape3D.new()
			shape.size = Vector3(3.6, 0.28, 0.91)
			var collision := CollisionShape3D.new()
			collision.name = "PaverCollision%02d" % paver_count
			collision.shape = shape
			collision.position = piece.position + Vector3(0, -0.11, 0)
			path_body.add_child(collision)
			var backing := MeshInstance3D.new()
			var backing_box := BoxMesh.new()
			backing_box.size = Vector3(3.6, 0.24, 0.91)
			backing.mesh = backing_box
			backing.position = piece.position + Vector3(0, -0.15, 0)
			backing.material_override = backing_material
			path_body.add_child(backing)
			paver_count += 1
		elif piece.name.begins_with("Door stone threshold"):
			var threshold := CollisionShape3D.new()
			var threshold_shape := BoxShape3D.new()
			threshold_shape.size = Vector3(3.2, 0.28, 1.1)
			threshold.shape = threshold_shape
			threshold.position = piece.position + Vector3(0, -0.11, 0)
			path_body.add_child(threshold)
		elif piece.name.begins_with("FRONT DOOR"):
			var door_stop := CollisionShape3D.new()
			var stop_shape := BoxShape3D.new()
			stop_shape.size = Vector3(4.5, 3.1, 0.3)
			door_stop.shape = stop_shape
			door_stop.position = piece.position
			path_body.add_child(door_stop)
		elif piece.name.begins_with("Individual lawn"):
			# The imported lawn is visual-only. Lift its top to the road height.
			piece.position.y = -0.25
			var lawn := CollisionShape3D.new()
			lawn.name = "LawnCollision"
			var lawn_shape := BoxShape3D.new()
			lawn_shape.size = Vector3(25, 0.5, 31)
			lawn.shape = lawn_shape
			lawn.position = piece.position
			path_body.add_child(lawn)
	if paver_count < 12:
		push_error("A Halloween house has an incomplete modeled door path: " + house.name)


func _scenery_footprint_clear(center: Vector2, size: Vector2) -> bool:
	var footprint := Rect2(center - size * 0.5, size)
	for walkable in WALKABLE_RECTS:
		if footprint.intersects(walkable):
			return false
	return true


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
