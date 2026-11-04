extends Node3D

const SPAWN := Vector3(0, 0.1, 4)
const SETTINGS_PATH := "user://settings.cfg"
const ADMIN_LEVEL_SELECT = preload("res://scripts/admin_level_select.gd")
const KARMA_CHOICE = preload("res://scripts/karma_choice.gd")
const KARMA_BAR = preload("res://scripts/karma_bar.gd")

@onready var player: Player3D = $Player3D

var dash_label: Label
var karma_label: Label
var story_label: Label
var completion_label: Label
var pause_menu: Control
var settings_screen: Control
var settings_box: VBoxContainer
var sensitivity_slider: HSlider
var karma_collected := 0
var karma_choices
var karma_bar
var karma_points: Array[Vector3] = []
var karma_paths: Array[Dictionary] = []
var story_found := false
var completed := false
var mesh_materials: Dictionary = {}


func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player.get_node("CameraPivot").rotation.y = PI
	karma_choices = KARMA_CHOICE.new()
	add_child(karma_choices)
	karma_choices.setup(player,
		"res://assets/karma pictures/Child places clothes in donation box.png",
		"res://assets/karma pictures/Walking Away With Donated Clothes.png",
		Rect2(0, 0, 1254, 740), Rect2(0, 0, 750, 1254))
	karma_choices.choice_made.connect(_on_karma_choice)
	_add_floor("DropOff", Vector3(0, -0.35, 7), Vector3(18, 0.7, 16))
	_add_floor("Sorting", Vector3(0, -0.35, 32.5), Vector3(18, 0.7, 23))
	_add_floor("ExitHall", Vector3(0, -0.35, 61.5), Vector3(18, 0.7, 25))
	_add_floor("SideCorridor", Vector3(14, -0.35, 32.5), Vector3(16, 0.7, 6))
	_add_floor("DonationRoom", Vector3(29, -0.35, 32.5), Vector3(18, 0.7, 13))
	_add_walls()
	_add_atmosphere()
	_add_donation_props()
	_add_pickup(Vector3(30, 1, 35), true)
	_add_finish()
	_make_hud()
	player.dash_cooldown_changed.connect(_on_dash_changed)
	_on_dash_changed(0.0, player.dash_cooldown_max, true)
	if OS.is_debug_build():
		assert(21.0 - 15.0 > 5.5, "First gap must require a dash")
		assert(49.0 - 44.0 >= 5.0, "Second gap must require a dash")
		assert(22.0 < 20.0 + 18.0, "Dead end must connect to the side corridor")


func _add_floor(floor_name: String, center: Vector3, size: Vector3) -> void:
	_solid_box(floor_name, center, size, Color(0.36, 0.36, 0.42))
	_visual_box(center + Vector3(0, size.y * 0.5 + 0.015, 0),
		Vector3(size.x, 0.03, size.z), Color(0.51, 0.49, 0.5))


func _solid_box(box_name: String, center: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = box_name
	body.position = center
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	_visual_box(center, size, color)
	add_child(body)


func _visual_box(at: Vector3, size: Vector3, color: Color) -> void:
	var box := BoxMesh.new()
	box.size = size
	_mesh(box, at, color)


func _mesh(shape: Mesh, at: Vector3, color: Color, glowing := false) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.mesh = shape
	visual.position = at
	var material_key := color.to_html() + (":glow" if glowing else ":flat")
	var material: StandardMaterial3D = mesh_materials.get(material_key)
	if material == null:
		material = StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.8
		if glowing:
			material.emission_enabled = true
			material.emission = color
			material.emission_energy_multiplier = 2.0
		mesh_materials[material_key] = material
	visual.material_override = material
	add_child(visual)
	return visual


func _rod(start: Vector3, finish: Vector3, radius: float, color: Color) -> void:
	var rod := CylinderMesh.new()
	rod.top_radius = radius
	rod.bottom_radius = radius
	rod.height = start.distance_to(finish)
	var visual := _mesh(rod, (start + finish) * 0.5, color)
	visual.quaternion = Quaternion(Vector3.UP, (finish - start).normalized())


func _add_walls() -> void:
	var wall := Color(0.28, 0.28, 0.35)
	for room in [Vector3(7, 7, 16), Vector3(32.5, 32.5, 23),
		Vector3(61.5, 61.5, 25)]:
		var z_center: float = room.x
		var length: float = room.z
		_solid_box("LeftWall", Vector3(-9.15, 1.55, z_center),
			Vector3(0.3, 3.1, length), wall)
		if z_center != 32.5:
			_solid_box("RightWall", Vector3(9.15, 1.55, z_center),
				Vector3(0.3, 3.1, length), wall)
	_solid_box("SortingRightFront", Vector3(9.15, 1.55, 25),
		Vector3(0.3, 3.1, 8), wall)
	_solid_box("SortingRightBack", Vector3(9.15, 1.55, 40),
		Vector3(0.3, 3.1, 8), wall)
	_solid_box("SideCorridorFront", Vector3(14.5, 1.5, 29.3),
		Vector3(11, 3, 0.3), wall)
	_solid_box("SideCorridorBack", Vector3(14.5, 1.5, 35.7),
		Vector3(11, 3, 0.3), wall)
	_solid_box("DonationEndWall", Vector3(38.15, 1.6, 32.5),
		Vector3(0.3, 3.2, 13), wall)
	_solid_box("DonationFrontWall", Vector3(29, 1.5, 25.9),
		Vector3(18, 3, 0.3), wall)
	_solid_box("DonationBackWall", Vector3(29, 1.5, 39.1),
		Vector3(18, 3, 0.3), wall)
	_solid_box("ExitBackWall", Vector3(0, 1.5, 74.2),
		Vector3(18, 3, 0.3), wall)


func _add_atmosphere() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.055, 0.052, 0.075)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.7, 0.65, 0.68)
	environment.ambient_light_energy = 0.5
	environment.ambient_light_sky_contribution = 0.0
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.17, 0.15, 0.2)
	environment.fog_density = 0.006
	world.environment = environment
	add_child(world)
	for at in [Vector3(0, 4, 8), Vector3(0, 4, 31),
		Vector3(0, 4, 61), Vector3(29, 4, 32.5)]:
		var light := OmniLight3D.new()
		light.position = at
		light.light_color = Color(1.0, 0.83, 0.64)
		light.light_energy = 1.3
		light.omni_range = 15
		add_child(light)
		_visual_box(at + Vector3(0, 0.1, 0), Vector3(3.8, 0.08, 0.55),
			Color(0.95, 0.88, 0.69))


func _add_donation_props() -> void:
	for rack in [Vector3(-6.5, 0, 7), Vector3(6.5, 0, 10),
		Vector3(-6.5, 0, 29), Vector3(6.5, 0, 40),
		Vector3(-6.5, 0, 55), Vector3(6.5, 0, 65),
		Vector3(27, 0, 28.5)]:
		_add_clothing_rack(rack, 4.5)
		karma_choices.add_interaction(rack)
	for box_at in [Vector3(-4.5, 0, 5), Vector3(4.5, 0, 7),
		Vector3(5.5, 0, 29), Vector3(24, 0, 37), Vector3(35, 0, 28)]:
		_add_donation_box(box_at)


func _add_clothing_rack(at: Vector3, length: float) -> void:
	var metal := Color(0.58, 0.6, 0.65)
	for side in [-1.0, 1.0]:
		var z: float = at.z + side * length * 0.5
		_rod(Vector3(at.x, 0, z), Vector3(at.x, 1.85, z), 0.045, metal)
		_rod(Vector3(at.x - 0.48, 0.08, z), Vector3(at.x + 0.48, 0.08, z),
			0.04, metal)
	_rod(Vector3(at.x, 1.85, at.z - length * 0.5),
		Vector3(at.x, 1.85, at.z + length * 0.5), 0.05, metal)
	var colors := [Color(0.58, 0.21, 0.26), Color(0.22, 0.36, 0.53),
		Color(0.69, 0.58, 0.4), Color(0.26, 0.43, 0.36)]
	for index in range(7):
		var z := at.z - length * 0.39 + index * length * 0.13
		_rod(Vector3(at.x, 1.85, z), Vector3(at.x, 1.62, z), 0.014, metal)
		_visual_box(Vector3(at.x, 1.13, z), Vector3(0.11, 0.96, 0.46),
			colors[index % colors.size()])
		_visual_box(Vector3(at.x, 1.43, z - 0.3), Vector3(0.12, 0.37, 0.19),
			colors[index % colors.size()])
		_visual_box(Vector3(at.x, 1.43, z + 0.3), Vector3(0.12, 0.37, 0.19),
			colors[index % colors.size()])


func _add_donation_box(at: Vector3) -> void:
	var brown := Color(0.47, 0.31, 0.21)
	_visual_box(at + Vector3(0, 0.38, 0), Vector3(1.1, 0.76, 1.0), brown)
	_visual_box(at + Vector3(0, 0.78, 0), Vector3(1.16, 0.06, 1.06),
		Color(0.56, 0.39, 0.27))
	_visual_box(at + Vector3(0, 0.8, 0), Vector3(0.13, 0.08, 1.07),
		Color(0.79, 0.68, 0.48))


func _add_sign(at: Vector3, words: String) -> void:
	var sign := Label3D.new()
	sign.text = words
	sign.position = at
	sign.font_size = 64
	sign.pixel_size = 0.005
	sign.modulate = Color(0.96, 0.9, 0.75)
	sign.rotation.y = PI
	add_child(sign)


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
	var orb := SphereMesh.new()
	orb.radius = 0.48
	orb.height = 0.96
	var color := Color(0.68, 0.33, 0.9) if is_story else Color(1, 0.78, 0.18)
	var visual := MeshInstance3D.new()
	visual.mesh = orb
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.3
	visual.material_override = material
	area.add_child(visual)
	add_child(area)
	area.body_entered.connect(_collect.bind(area, is_story))


func _collect(body: Node3D, area: Area3D, is_story: bool) -> void:
	if body != player:
		return
	area.set_deferred("monitoring", false)
	area.queue_free()
	if is_story:
		story_found = true
		story_label.text = "Story item: donation receipt"
	else:
		karma_collected += 1
		karma_label.text = "Karma collected: %d" % karma_collected


func _on_karma_choice(amount: int) -> void:
	karma_collected += amount
	karma_label.text = "Karma: %d" % karma_collected


func _add_karma_choices(positive_path: String, negative_path: String, points: Array) -> void:
	karma_choices = KARMA_CHOICE.new()
	add_child(karma_choices)
	karma_choices.setup(player, positive_path, negative_path, Rect2(), Rect2())
	karma_choices.choice_made.connect(_on_karma_choice)
	for at in points:
		karma_choices.add_interaction(at)


func _add_karma_path(high: bool, from: Vector3, to: Vector3, width: float) -> void:
	var body := StaticBody3D.new()
	body.name = "HighKarmaPath" if high else "LowKarmaPath"
	body.transform = Transform3D(Basis.looking_at(to - from, Vector3.UP),
		(from + to) * 0.5 - Vector3(0, 0.2, 0))
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, 0.4, from.distance_to(to))
	collision.shape = shape
	collision.disabled = true
	body.add_child(collision)
	var visual := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = shape.size
	visual.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.94, 0.82, 0.35) if high else Color(0.45, 0.06, 0.08)
	material.emission_enabled = true
	material.emission = material.albedo_color
	visual.material_override = material
	body.add_child(visual)
	body.visible = false
	add_child(body)
	karma_paths.append({"high": high, "body": body, "collision": collision})


func _update_karma_paths(karma: int) -> void:
	for path in karma_paths:
		var open: bool = karma >= 50 if path["high"] else karma <= -50
		path["body"].visible = open
		path["collision"].disabled = not open


func _add_finish() -> void:
	var white := Color(0.86, 0.92, 1.0)
	_visual_box(Vector3(-1.4, 1.7, 71.5), Vector3(0.18, 3.4, 0.3), white)
	_visual_box(Vector3(1.4, 1.7, 71.5), Vector3(0.18, 3.4, 0.3), white)
	_visual_box(Vector3(0, 3.4, 71.5), Vector3(3.0, 0.18, 0.3), white)
	var area := Area3D.new()
	area.position = Vector3(0, 1.2, 71.5)
	area.collision_layer = 0
	area.collision_mask = 1
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.6, 2.4, 1.0)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	area.add_child(collision)
	add_child(area)
	area.body_entered.connect(_on_finish)


func _on_finish(body: Node3D) -> void:
	if body != player or completed:
		return
	completed = true
	player.set_physics_process(false)
	get_tree().call_deferred("change_scene_to_file", "res://scenes/level_03.tscn")


func _process(_delta: float) -> void:
	if not completed and player.global_position.y < -5.0:
		set_process(false)
		get_tree().call_deferred("reload_current_scene")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if settings_screen:
			_close_settings_screen()
		else:
			_toggle_pause()
		get_viewport().set_input_as_handled()


func _toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
	pause_menu.visible = get_tree().paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if get_tree().paused else Input.MOUSE_MODE_CAPTURED


func _return_to_menu() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _open_settings_screen() -> void:
	var menu_scene := load("res://scenes/main_menu.tscn") as PackedScene
	settings_screen = menu_scene.instantiate() as Control
	settings_screen.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_menu.get_parent().add_child(settings_screen)
	pause_menu.hide()
	settings_screen.call("_open_settings")
	var back := settings_screen.get_node("Center/SettingsPanel/Margin/VBox/BackButton") as Button
	back.pressed.connect(_close_settings_screen)


func _close_settings_screen() -> void:
	settings_screen.queue_free()
	settings_screen = null
	pause_menu.show()


func _make_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)
	dash_label = _label(hud, "DASH READY [SHIFT]", Vector2(20, 20))
	karma_label = _label(hud, "Karma: 0", Vector2(20, 48))
	story_label = _label(hud, "Story item: not found", Vector2(20, 76))
	karma_label.hide()
	story_label.hide()
	completion_label = _label(hud, "LEVEL 2 COMPLETE", Vector2(20, 112))
	completion_label.hide()
	karma_bar = KARMA_BAR.new()
	hud.add_child(karma_bar)
	karma_bar.setup(self)
	karma_label.text = "Karma: %d" % karma_collected
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
	_button(options, "Settings", _open_settings_screen)
	options.add_child(ADMIN_LEVEL_SELECT.new())
	_button(options, "Main Menu", _return_to_menu)


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
