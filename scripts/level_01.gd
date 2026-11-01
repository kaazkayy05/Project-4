extends Node3D

const SPAWN := Vector3(-27, 0.1, 0)
const SETTINGS_PATH := "user://settings.cfg"
const TREE_TIERS := [
	Vector3(3.5, 4.2, 5.2),
	Vector3(5.6, 3.5, 4.8),
	Vector3(7.7, 2.8, 4.2),
	Vector3(9.5, 2.0, 3.6),
	Vector3(10.9, 1.15, 2.6),
]

@onready var player: Player3D = $Player3D

var dash_label: Label
var karma_label: Label
var story_label: Label
var completion_label: Label
var pause_menu: Control
var settings_box: VBoxContainer
var sensitivity_slider: HSlider
var karma_collected := 0
var story_found := false
var completed := false


func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player.get_node("CameraPivot").rotation.y = -PI / 2.0

	_add_box("StartRun", Vector3(-19.7, -0.35, 0), Vector3(20.6, 0.7, 4))
	_add_box("FirstLanding", Vector3(0.5, -0.35, 0), Vector3(10.6, 0.7, 4))
	_add_box("NorthTurn", Vector3(5.8, -0.35, -6.9), Vector3(4, 0.7, 13.8))
	_add_box("UpperRun", Vector3(15, -0.35, -13.8), Vector3(10, 0.7, 4))
	_add_box("UpperRight", Vector3(20, -0.35, -10.8), Vector3(4, 0.7, 6))
	_add_box("FinalRun", Vector3(20, -0.35, 3.9), Vector3(4, 0.7, 17))

	_add_tree()
	_add_staircase()
	_add_winter_atmosphere()
	_add_christmas_decorations()
	_add_sky_lights()
	_add_exit_door()

	_add_pickup(Vector3(-17, 1, 0), false)
	_add_pickup(Vector3(15, 1, -13.8), false)
	_add_pickup(Vector3(20, 1, 7), true)

	var exit_area := Area3D.new()
	exit_area.position = Vector3(20, 3.4, 24.65)
	exit_area.collision_layer = 0
	exit_area.collision_mask = 1
	var exit_shape := CollisionShape3D.new()
	var doorway := BoxShape3D.new()
	doorway.size = Vector3(2.3, 2.9, 0.38)
	exit_shape.shape = doorway
	exit_area.add_child(exit_shape)
	add_child(exit_area)
	exit_area.body_entered.connect(_on_exit)

	_make_hud()
	player.dash_cooldown_changed.connect(_on_dash_changed)
	_on_dash_changed(0.0, player.dash_cooldown_max, true)
	_wake()


func _add_box(box_name: String, center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = box_name
	body.position = center
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	_visual_box(body, Vector3.ZERO, size, Color(0.82, 0.9, 0.96))
	_add_snow_surface(body, size)
	add_child(body)


func _add_snow_surface(body: StaticBody3D, size: Vector3) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 7101
	noise.frequency = 0.18
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	var x_steps := maxi(2, ceili(size.x / 0.32))
	var z_steps := maxi(2, ceili(size.z / 0.32))
	var stride := z_steps + 1
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for x_index in range(x_steps + 1):
		for z_index in range(z_steps + 1):
			var point := _snow_vertex(body, size, noise, x_index, z_index, x_steps, z_steps)
			vertices.append(point)
			var snow_depth := point.y - size.y * 0.5
			colors.append(Color(0.94, 0.97, 1.0).lerp(
				Color(0.71, 0.8, 0.91), clampf(snow_depth * 0.38, 0.0, 0.3)))
	for x_index in range(x_steps + 1):
		for z_index in range(z_steps + 1):
			var left := vertices[maxi(0, x_index - 1) * stride + z_index]
			var right := vertices[mini(x_steps, x_index + 1) * stride + z_index]
			var back := vertices[x_index * stride + maxi(0, z_index - 1)]
			var front := vertices[x_index * stride + mini(z_steps, z_index + 1)]
			normals.append((front - back).cross(right - left).normalized())
	for x_index in range(x_steps):
		for z_index in range(z_steps):
			var a := x_index * stride + z_index
			var b := (x_index + 1) * stride + z_index
			var c := a + 1
			var d := b + 1
			indices.append_array(PackedInt32Array([a, c, b, b, c, d]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var terrain := ArrayMesh.new()
	terrain.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var snow := MeshInstance3D.new()
	snow.name = "UnevenSnow"
	snow.mesh = terrain
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	snow.material_override = material
	body.add_child(snow)


func _snow_vertex(body: StaticBody3D, size: Vector3, noise: FastNoiseLite,
		x_index: int, z_index: int, x_steps: int, z_steps: int) -> Vector3:
	var x := (float(x_index) / x_steps - 0.5) * size.x
	var z := (float(z_index) / z_steps - 0.5) * size.z
	var world_x := body.position.x + x
	var world_z := body.position.z + z
	var main_drift := 0.5 + 0.5 * sin(world_x * 0.33 + 0.65 * sin(world_z * 0.22))
	var crossing_drift := 0.5 + 0.5 * sin(world_z * 0.55 - world_x * 0.21)
	var fine := noise.get_noise_2d(world_x * 1.8, world_z * 1.8)
	var height := (size.y * 0.5 + 0.035 + 0.28 * main_drift
		+ 0.12 * crossing_drift + 0.025 * fine)
	return Vector3(x, height, z)


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
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.55
	sphere_mesh.height = 1.1
	_mesh(area, sphere_mesh, Vector3.ZERO,
		Color(0.7, 0.4, 0.9) if is_story else Color(1, 0.78, 0.15))
	add_child(area)
	area.body_entered.connect(_collect.bind(area, is_story))


func _collect(body: Node3D, area: Area3D, is_story: bool) -> void:
	if body != player:
		return
	area.set_deferred("monitoring", false)
	area.queue_free()
	if is_story:
		story_found = true
		story_label.text = "Story item found"
	else:
		karma_collected += 1
		karma_label.text = "Karma collected: %d" % karma_collected


func _visual_box(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> void:
	var box := BoxMesh.new()
	box.size = size
	_mesh(parent, box, at, color)


func _mesh(parent: Node3D, shape: Mesh, at: Vector3, color: Color) -> void:
	var visual := MeshInstance3D.new()
	visual.mesh = shape
	visual.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	visual.material_override = material
	parent.add_child(visual)


func _tree_cone(parent: Node3D, height_at: float, radius: float, height: float, color: Color) -> void:
	var cone := CylinderMesh.new()
	cone.top_radius = 0
	cone.bottom_radius = radius
	cone.height = height
	cone.radial_segments = 12
	_mesh(parent, cone, Vector3(0, height_at, 0), color)


func _tree_radius_at(y: float) -> float:
	var radius := 0.0
	for tier in TREE_TIERS:
		var bottom: float = tier.x - tier.z * 0.5
		var top: float = tier.x + tier.z * 0.5
		if y >= bottom and y <= top:
			radius = maxf(radius, tier.y * (top - y) / tier.z)
	return radius


func _add_tree() -> void:
	var tree := Node3D.new()
	tree.name = "MassiveChristmasTree"
	tree.position = Vector3(13, -1.5, -4.4)
	add_child(tree)

	var base := CylinderMesh.new()
	base.top_radius = 4.3
	base.bottom_radius = 4.3
	base.height = 0.6
	_mesh(tree, base, Vector3(0, -0.3, 0), Color(0.82, 0.9, 0.96))

	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.9
	trunk.bottom_radius = 1.1
	trunk.height = 3.0
	_mesh(tree, trunk, Vector3(0, 1.5, 0), Color(0.3, 0.13, 0.06))

	var greens := [
		Color(0.035, 0.24, 0.12), Color(0.045, 0.31, 0.15),
		Color(0.025, 0.27, 0.13), Color(0.05, 0.34, 0.16),
		Color(0.035, 0.29, 0.14),
	]
	for index in range(TREE_TIERS.size()):
		var tier: Vector3 = TREE_TIERS[index]
		_tree_cone(tree, tier.x, tier.y, tier.z, greens[index])
		# Smaller overlapping boughs interrupt the straight cone silhouette.
		if index < TREE_TIERS.size() - 1:
			for branch in range(8):
				var angle := TAU * (float(branch) + 0.35 * index) / 8.0
				var branch_radius: float = tier.y * 0.47
				var bough := Node3D.new()
				bough.position = Vector3(cos(angle), 0, sin(angle)) * branch_radius
				bough.position.y = tier.x - tier.z * 0.2
				bough.rotation.z = 0.12 * cos(angle)
				bough.rotation.x = -0.12 * sin(angle)
				tree.add_child(bough)
				if OS.is_debug_build():
					assert(branch_radius < _tree_radius_at(bough.position.y) + tier.y * 0.46,
						"Branch cluster must intersect the tree")
				_tree_cone(bough, 0, tier.y * 0.46, tier.z * 0.75,
					greens[(index + branch + 1) % greens.size()])

	_add_tree_ornaments(tree)
	_add_tree_star(tree)
	if OS.is_debug_build():
		_validate_tree_connections()


func _add_tree_ornaments(tree: Node3D) -> void:
	var colors := [Color(0.95, 0.08, 0.12), Color(1.0, 0.72, 0.12),
		Color(0.13, 0.78, 0.86), Color(0.91, 0.15, 0.31)]
	var levels := [2.7, 3.7, 4.8, 5.8, 6.8, 7.8, 8.8, 9.7, 10.6]
	for row in range(levels.size()):
		var height: float = levels[row]
		for side in range(5):
			var angle := TAU * (float(side) / 5.0 + 0.12 * row)
			var direction := Vector3(cos(angle), 0, sin(angle))
			var ball_radius := 0.22 if row > 6 else 0.29
			var surface_radius := _tree_radius_at(height)
			var at := direction * (surface_radius + ball_radius * 0.45)
			at.y = height
			if OS.is_debug_build():
				assert(surface_radius > 0.0 and
					at.distance_to(Vector3(0, height, 0)) - surface_radius < ball_radius,
					"Ornament must intersect the foliage")
			var ball := SphereMesh.new()
			ball.radius = ball_radius
			ball.height = ball_radius * 2.0
			var visual := _colored_mesh(tree, ball, at, colors[(row + side) % colors.size()])
			visual.name = "Ornament"
			var cap := CylinderMesh.new()
			cap.top_radius = ball_radius * 0.37
			cap.bottom_radius = ball_radius * 0.37
			cap.height = ball_radius * 0.22
			_mesh(tree, cap, at + Vector3(0, ball_radius * 0.94, 0),
				Color(0.93, 0.78, 0.38))


func _add_tree_star(tree: Node3D) -> void:
	var star := ArrayMesh.new()
	var vertices := PackedVector3Array()
	var center := Vector3(0, 12.65, 0)
	var outline: Array[Vector3] = []
	for point in range(10):
		var angle := -PI * 0.5 + point * PI / 5.0
		var radius := 0.95 if point % 2 == 0 else 0.42
		outline.append(Vector3(cos(angle) * radius, center.y + sin(angle) * radius, 0))
	for point in range(10):
		var next := (point + 1) % 10
		for depth in [-0.12, 0.12]:
			vertices.append(Vector3(center.x, center.y, depth))
			vertices.append(outline[point] + Vector3(0, 0, depth))
			vertices.append(outline[next] + Vector3(0, 0, depth))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	star.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var star_visual := _colored_mesh(tree, star, Vector3.ZERO, Color(1.0, 0.78, 0.2), true)
	star_visual.name = "Star"
	star_visual.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
	var stem := CylinderMesh.new()
	stem.top_radius = 0.12
	stem.bottom_radius = 0.12
	stem.height = 0.8
	_mesh(tree, stem, Vector3(0, 12.1, 0), Color(0.98, 0.8, 0.25))


func _validate_tree_connections() -> void:
	for index in range(1, TREE_TIERS.size()):
		var lower: Vector3 = TREE_TIERS[index - 1]
		var upper: Vector3 = TREE_TIERS[index]
		assert(upper.x - upper.z * 0.5 < lower.x + lower.z * 0.5,
			"Christmas tree branch tiers must overlap")
	assert(TREE_TIERS[0].x - TREE_TIERS[0].z * 0.5 < 3.0,
		"Lowest branches must overlap the trunk")
	assert(12.65 - 0.95 < TREE_TIERS[-1].x + TREE_TIERS[-1].z * 0.5,
		"Star must touch the treetop")
	for height in [2.7, 3.7, 4.8, 5.8, 6.8, 7.8, 8.8, 9.7, 10.6]:
		assert(_tree_radius_at(height) > 0.0,
			"Every ornament must intersect a branch tier")


func _add_staircase() -> void:
	for index in range(8):
		var step_height := (index + 1) * 0.25
		var step_z := 12.9 + index * 1.1
		_visual_box(self, Vector3(20, step_height * 0.5, step_z),
			Vector3(4, step_height, 1.1), Color(0.86, 0.91, 0.96))
		_visual_box(self, Vector3(20, step_height + 0.02, step_z + 0.43),
			Vector3(3.7, 0.04, 0.12), Color(1.0, 0.79, 0.3))

	var ramp := StaticBody3D.new()
	ramp.name = "StairRamp"
	ramp.position = Vector3(20, 1.0, 16.75)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4, 0.2, 9.03)
	collision.shape = shape
	collision.rotation.x = -atan(2.0 / 8.8)
	ramp.add_child(collision)
	add_child(ramp)
	_add_box("StairLanding", Vector3(20, 1.65, 23), Vector3(4, 0.7, 4.5))


func _add_winter_atmosphere() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.008, 0.012, 0.035)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.38, 0.5, 0.78)
	environment.ambient_light_energy = 0.38
	environment.ambient_light_sky_contribution = 0.0
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.16, 0.22, 0.39)
	environment.fog_density = 0.013
	world.environment = environment
	add_child(world)

	var flake := SphereMesh.new()
	flake.radius = 0.035
	flake.height = 0.07
	for origin in [Vector3(-14, 10, -2), Vector3(14, 10, -2)]:
		var snow := CPUParticles3D.new()
		snow.position = origin
		snow.amount = 260
		snow.lifetime = 7.0
		snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		snow.emission_box_extents = Vector3(19, 0.5, 17)
		snow.direction = Vector3(0, -1, 0)
		snow.spread = 12.0
		snow.gravity = Vector3(0, -0.7, 0)
		snow.initial_velocity_min = 0.4
		snow.initial_velocity_max = 0.9
		snow.mesh = flake
		add_child(snow)


func _colored_mesh(parent: Node3D, shape: Mesh, at: Vector3, color: Color,
		glowing := false) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.mesh = shape
	visual.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if glowing:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 2.0
	visual.material_override = material
	parent.add_child(visual)
	return visual


func _add_christmas_decorations() -> void:
	var gifts := [
		[Vector3(-23.0, 0, 1.25), Vector3(0.85, 0.65, 0.75), Color(0.62, 0.05, 0.11)],
		[Vector3(-21.8, 0, 1.2), Vector3(0.52, 0.46, 0.5), Color(0.04, 0.42, 0.22)],
		[Vector3(-3.5, 0, -1.25), Vector3(0.7, 0.58, 0.6), Color(0.76, 0.12, 0.2)],
		[Vector3(6.8, 0, -5.4), Vector3(0.58, 0.5, 0.58), Color(0.13, 0.35, 0.63)],
		[Vector3(12.8, 0, -15.1), Vector3(0.77, 0.6, 0.62), Color(0.62, 0.06, 0.11)],
		[Vector3(21.25, 0, 4.7), Vector3(0.68, 0.55, 0.7), Color(0.04, 0.42, 0.22)],
	]
	for gift in gifts:
		_add_present(gift[0], gift[1], gift[2])
	_add_candy_cane(Vector3(-27, 0, -1.45))
	_add_candy_cane(Vector3(4.35, 0, -4.1))
	_add_candy_cane(Vector3(18.45, 0, 5.0))
	_add_snowman(Vector3(-18.3, 0, 1.35))
	var tree_light := OmniLight3D.new()
	tree_light.position = Vector3(13, 8.5, -4.4)
	tree_light.light_color = Color(1.0, 0.76, 0.4)
	tree_light.light_energy = 1.4
	tree_light.omni_range = 13.0
	add_child(tree_light)


func _add_present(at: Vector3, size: Vector3, color: Color) -> void:
	_visual_box(self, at + Vector3(0, size.y * 0.5, 0), size, color)
	var gold := Color(0.96, 0.74, 0.2)
	_visual_box(self, at + Vector3(0, size.y * 0.5, 0),
		Vector3(0.1, size.y + 0.015, size.z + 0.015), gold)
	_visual_box(self, at + Vector3(0, size.y * 0.5, 0),
		Vector3(size.x + 0.015, size.y + 0.015, 0.1), gold)
	for side in [-1, 1]:
		var bow := SphereMesh.new()
		bow.radius = 0.17
		bow.height = 0.21
		_mesh(self, bow, at + Vector3(side * 0.13, size.y + 0.08, 0), gold)


func _add_candy_cane(at: Vector3) -> void:
	var path := [Vector3(0, 0, 0), Vector3(0, 0.55, 0),
		Vector3(0, 1.1, 0), Vector3(0, 1.55, 0),
		Vector3(0.08, 1.76, 0), Vector3(0.28, 1.88, 0),
		Vector3(0.48, 1.78, 0), Vector3(0.55, 1.57, 0)]
	for index in range(path.size() - 1):
		_add_rod(self, at + path[index], at + path[index + 1], 0.085,
			Color(0.88, 0.06, 0.1) if index % 2 == 0 else Color(0.98, 0.95, 0.87))


func _add_snowman(at: Vector3) -> void:
	for part in [Vector3(0.6, 0.62, 0.6), Vector3(0.44, 0.46, 0.44),
		Vector3(0.3, 0.32, 0.3)]:
		var snowball := SphereMesh.new()
		snowball.radius = 1
		snowball.height = 2
		var y := 0.5 if part.x > 0.5 else (1.35 if part.x > 0.4 else 1.95)
		var visual := _colored_mesh(self, snowball, at + Vector3(0, y, 0),
			Color(0.94, 0.97, 1.0))
		visual.scale = part
	_visual_box(self, at + Vector3(0, 2.26, 0), Vector3(0.58, 0.13, 0.58),
		Color(0.06, 0.08, 0.12))
	_visual_box(self, at + Vector3(0, 2.43, 0), Vector3(0.38, 0.3, 0.38),
		Color(0.06, 0.08, 0.12))


func _add_sky_lights() -> void:
	var moonlight := get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if moonlight:
		moonlight.light_energy = 0.23
		moonlight.light_color = Color(0.51, 0.65, 0.95)
		moonlight.shadow_enabled = true
	_add_light_string(Vector3(-25.5, 0, -1.7), Vector3(4.5, 0, -1.7))
	_add_light_string(Vector3(5.8, 0, -12.5), Vector3(19.4, 0, -12.5))
	_add_light_string(Vector3(21.55, 0, -10.2), Vector3(21.55, 0, 10.7))


func _add_light_string(start: Vector3, finish: Vector3) -> void:
	var pole_top_a := start + Vector3(0, 5.8, 0)
	var pole_top_b := finish + Vector3(0, 5.8, 0)
	var pole_color := Color(0.22, 0.17, 0.17)
	_add_rod(self, start, pole_top_a, 0.09, pole_color)
	_add_rod(self, finish, pole_top_b, 0.09, pole_color)
	var span := pole_top_a.distance_to(pole_top_b)
	var segments := maxi(8, ceili(span / 1.1))
	var colors := [Color(1, 0.18, 0.12), Color(1, 0.75, 0.16),
		Color(0.13, 0.95, 0.5), Color(0.25, 0.68, 1)]
	for index in range(segments):
		var a := _cable_point(pole_top_a, pole_top_b, float(index) / segments)
		var b := _cable_point(pole_top_a, pole_top_b, float(index + 1) / segments)
		_add_rod(self, a, b, 0.025, Color(0.14, 0.12, 0.12))
		if index % 2 == 0:
			var contact := a.lerp(b, 0.5)
			var bulb_at := contact - Vector3(0, 0.18, 0)
			_add_rod(self, contact, bulb_at, 0.025, pole_color)
			var bulb := SphereMesh.new()
			bulb.radius = 0.13
			bulb.height = 0.26
			_colored_mesh(self, bulb, bulb_at, colors[(index / 2) % colors.size()], true)
			if index % 6 == 0:
				var lamp := OmniLight3D.new()
				lamp.position = bulb_at
				lamp.light_color = colors[(index / 2) % colors.size()]
				lamp.light_energy = 0.8
				lamp.omni_range = 5.0
				add_child(lamp)
	if OS.is_debug_build():
		assert(_cable_point(pole_top_a, pole_top_b, 0.0).is_equal_approx(pole_top_a))
		assert(_cable_point(pole_top_a, pole_top_b, 1.0).is_equal_approx(pole_top_b))


func _cable_point(start: Vector3, finish: Vector3, t: float) -> Vector3:
	return start.lerp(finish, t) - Vector3(0, sin(PI * t) * 0.8, 0)


func _add_rod(parent: Node3D, start: Vector3, finish: Vector3,
		radius: float, color: Color) -> void:
	var rod := CylinderMesh.new()
	rod.top_radius = radius
	rod.bottom_radius = radius
	rod.height = start.distance_to(finish)
	var visual := _colored_mesh(parent, rod, (start + finish) * 0.5, color)
	visual.quaternion = Quaternion(Vector3.UP, (finish - start).normalized())


func _add_exit_door() -> void:
	var frame_color := Color(0.84, 0.94, 1.0)
	_visual_box(self, Vector3(18.75, 3.5, 24.65), Vector3(0.16, 3.0, 0.22), frame_color)
	_visual_box(self, Vector3(21.25, 3.5, 24.65), Vector3(0.16, 3.0, 0.22), frame_color)
	_visual_box(self, Vector3(20, 5.0, 24.65), Vector3(2.66, 0.18, 0.22), frame_color)
	var door := BoxMesh.new()
	door.size = Vector3(2.34, 2.82, 0.08)
	var panel := _colored_mesh(self, door, Vector3(20, 3.5, 24.65), frame_color, true)
	panel.name = "LevelTwoDoor"
	var material := panel.material_override as StandardMaterial3D
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color.a = 0.42
	material.emission_energy_multiplier = 3.0
	var glow := OmniLight3D.new()
	glow.position = Vector3(20, 3.7, 23.8)
	glow.light_color = frame_color
	glow.light_energy = 2.0
	glow.omni_range = 7.0
	add_child(glow)


func _on_exit(body: Node3D) -> void:
	if body != player or completed:
		return
	completed = true
	player.set_physics_process(false)
	get_tree().call_deferred("change_scene_to_file", "res://scenes/level_02.tscn")


func _process(_delta: float) -> void:
	if not completed and player.global_position.y < -5.0:
		player.respawn(SPAWN)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_toggle_pause()
		get_viewport().set_input_as_handled()


func _toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
	pause_menu.visible = get_tree().paused
	if not pause_menu.visible:
		settings_box.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if get_tree().paused else Input.MOUSE_MODE_CAPTURED


func _return_to_menu() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _wake() -> void:
	player.set_physics_process(false)
	var visuals := player.get_node("Visuals") as Node3D
	var pivot := player.get_node("CameraPivot") as Node3D
	visuals.rotation_degrees.x = -75.0
	pivot.position.y = 0.5
	var tween := create_tween().set_parallel(true)
	tween.tween_property(visuals, "rotation_degrees:x", 0.0, 1.4)
	tween.tween_property(pivot, "position:y", 1.3, 1.4)
	tween.chain().tween_callback(func() -> void: player.set_physics_process(true))


func _make_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)

	dash_label = _label(hud, "DASH READY [SHIFT]", Vector2(20, 20))
	karma_label = _label(hud, "Karma collected: 0", Vector2(20, 48))
	story_label = _label(hud, "Story item: not found", Vector2(20, 76))
	completion_label = _label(hud, "LEVEL 1 COMPLETE", Vector2(20, 112))
	completion_label.hide()

	pause_menu = CenterContainer.new()
	pause_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_menu.hide()
	hud.add_child(pause_menu)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 220)
	pause_menu.add_child(panel)
	var options := VBoxContainer.new()
	panel.add_child(options)

	_button(options, "Resume", _toggle_pause)
	_button(options, "Settings", func() -> void: settings_box.show())
	_button(options, "Return to Main Menu", _return_to_menu)

	settings_box = VBoxContainer.new()
	settings_box.hide()
	options.add_child(settings_box)
	var title := Label.new()
	title.text = "Microphone sensitivity"
	settings_box.add_child(title)
	sensitivity_slider = HSlider.new()
	sensitivity_slider.min_value = 0
	sensitivity_slider.max_value = 100
	sensitivity_slider.step = 1
	sensitivity_slider.value = 50
	settings_box.add_child(sensitivity_slider)
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		sensitivity_slider.set_value_no_signal(config.get_value("audio", "microphone_sensitivity", 50))
	sensitivity_slider.value_changed.connect(_save_sensitivity)
	_button(settings_box, "Back", func() -> void: settings_box.hide())


func _label(parent: Node, value: String, at: Vector2) -> Label:
	var label := Label.new()
	label.text = value
	label.position = at
	parent.add_child(label)
	return label


func _button(parent: Node, value: String, action: Callable) -> void:
	var button := Button.new()
	button.text = value
	parent.add_child(button)
	button.pressed.connect(action)


func _save_sensitivity(value: float) -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("audio", "microphone_sensitivity", value)
	config.save(SETTINGS_PATH)


func _on_dash_changed(remaining: float, _maximum: float, ready: bool) -> void:
	dash_label.text = "DASH READY [SHIFT]" if ready else "DASH %.1fs" % remaining
