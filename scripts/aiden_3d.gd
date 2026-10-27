extends Node3D

@export var first_person := false

const GRAVITY := 19.0
const DASH_SPEED := 18.0
const WALL_RUN_SPEED := 10.0
const CAMERA_OFFSET := Vector3(8.0, 100.0, 68.0)
const CAMERA_DEAD_ZONE := 3.5

var player: CharacterBody3D
var character_art: Node3D
var camera: Camera3D
var camera_focus := Vector3.ZERO
var waking_up := false
var mouse_look_active := false
var hud: Label
var karma := 0
var karma_places := [Vector3(0, 1.1, -5), Vector3(3.1, 1.1, -13), Vector3(-3.1, 1.1, -20)]
var karma_nodes: Array[Node3D] = []
var story_place := Vector3(0, 1.1, -17)
var story_node: Node3D
var story_found := false
var scream_ready := true
var dash_left := 0.0
var dash_cooldown := 0.0
var dash_direction := Vector3.FORWARD
var dash_started_airborne := false
var wall_run_left := 0.0
var wall_run_direction := Vector3.FORWARD
var wall_normal := Vector3.ZERO
var finished := false
var message := "The room looks like age 16, but memories can lie."


func _ready() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("101a2b")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("8294ad")
	settings.ambient_light_energy = 0.7
	environment.environment = settings
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -25, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)
	_box(Vector3(0, -0.25, -12), Vector3(9, 0.5, 31), Color("45526a"))
	_box(Vector3(-4.5, 2, -12), Vector3(0.4, 4, 31), Color("71819b"))
	_box(Vector3(4.5, 2, -12), Vector3(0.4, 4, 31), Color("71819b"))
	for seam_z in range(-26, 4, 2):
		_box(Vector3(0, 0.01, seam_z), Vector3(8.6, 0.02, 0.035), Color("344157"), false)
	for seam_x in [-3.0, -1.0, 1.0, 3.0]:
		_box(Vector3(seam_x, 0.01, -12), Vector3(0.035, 0.02, 30), Color("344157"), false)
	_box(Vector3(0, 0.55, -9), Vector3(2.7, 1.1, 0.5), Color("b5897b"))
	_box(Vector3(-2.25, 1.5, -26), Vector3(2.8, 3, 0.2), Color("9288b9"), false)
	_box(Vector3(2.25, 1.5, -26), Vector3(2.8, 3, 0.2), Color("e5c477"), false)
	for z in [-2, -7, -12, -17, -22]:
		_box(Vector3(-4.27, 2.4, z), Vector3(0.05, 1.5, 1.5), Color("9db9cb"), false)
		_box(Vector3(4.27, 2.4, z), Vector3(0.05, 1.5, 1.5), Color("9db9cb"), false)
	for place in karma_places:
		karma_nodes.append(_pickup(place, Color("f4cf78"), false))
	story_node = _pickup(story_place, Color("85d3d0"), true)
	player = CharacterBody3D.new()
	player.position = Vector3(0, 1.1, 1.0)
	add_child(player)
	var hitbox := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.8
	hitbox.shape = capsule
	player.add_child(hitbox)
	_make_character()
	camera = Camera3D.new()
	camera.fov = 75.0 if first_person else 5.0
	camera.near = 0.1
	camera.far = 500.0
	camera.current = true
	if first_person:
		player.add_child(camera)
		camera.position.y = -0.2
		character_art.visible = false
		waking_up = true
		mouse_look_active = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		add_child(camera)
		camera_focus = Vector3(0.0, 0.8, player.global_position.z - 3.0)
		camera.global_position = camera_focus + CAMERA_OFFSET
		camera.look_at(camera_focus, Vector3.UP)
	_make_hud()
	if first_person:
		var waking := create_tween()
		waking.tween_property(camera, "position:y", 0.55, 1.4).set_trans(Tween.TRANS_SINE)
		waking.tween_callback(func() -> void: waking_up = false)
	else:
		var waking := create_tween().set_parallel(true)
		waking.tween_property(character_art, "rotation:z", 0.0, 1.4).set_trans(Tween.TRANS_SINE)
		waking.tween_property(character_art, "position:y", 0.0, 1.4).set_trans(Tween.TRANS_SINE)
	_update_hud()


func _exit_tree() -> void:
	if first_person:
		mouse_look_active = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _make_character() -> void:
	character_art = Node3D.new()
	character_art.name = "CharacterArt"
	character_art.rotation.z = -PI / 2.0
	character_art.position.y = -0.4
	player.add_child(character_art)
	_character_box(Vector3(0, 0, 0), Vector3(0.62, 0.85, 0.36), Color("b7c9df"))
	_character_box(Vector3(-0.49, 0.02, 0), Vector3(0.24, 0.72, 0.3), Color("97abc7"))
	_character_box(Vector3(0.49, 0.02, 0), Vector3(0.24, 0.72, 0.3), Color("97abc7"))
	_character_box(Vector3(-0.19, -0.65, 0), Vector3(0.23, 0.53, 0.32), Color("273c5d"))
	_character_box(Vector3(0.19, -0.65, 0), Vector3(0.23, 0.53, 0.32), Color("273c5d"))
	var head := SphereMesh.new()
	head.radius = 0.28
	head.height = 0.56
	head.radial_segments = 8
	head.rings = 4
	var face := MeshInstance3D.new()
	face.mesh = head
	face.position = Vector3(0, 0.69, 0)
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color("e4bd9f")
	face.material_override = skin
	character_art.add_child(face)
	_character_box(Vector3(0, 0.71, -0.27), Vector3(0.23, 0.07, 0.035), Color("26364b"))


func _character_box(local_position: Vector3, size: Vector3, color: Color) -> void:
	var part := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	part.mesh = shape
	part.position = local_position
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	part.material_override = material
	character_art.add_child(part)


func _box(position_3d: Vector3, size: Vector3, color: Color, solid: bool = true) -> void:
	var holder: Node3D = StaticBody3D.new() if solid else Node3D.new()
	holder.position = position_3d
	add_child(holder)
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = size
	mesh.mesh = cube
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	mesh.material_override = material
	holder.add_child(mesh)
	if solid:
		var hitbox := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		hitbox.shape = shape
		holder.add_child(hitbox)


func _pickup(place: Vector3, color: Color, is_story: bool) -> Node3D:
	var marker := Node3D.new()
	marker.position = place
	add_child(marker)
	var mesh := MeshInstance3D.new()
	if is_story:
		var book := BoxMesh.new()
		book.size = Vector3(0.45, 0.6, 0.12)
		mesh.mesh = book
	else:
		var orb := SphereMesh.new()
		orb.radius = 0.28
		orb.height = 0.56
		mesh.mesh = orb
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.8
	mesh.material_override = material
	marker.add_child(mesh)
	return marker


func _make_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(24, 20)
	hud.add_theme_font_size_override("font_size", 19)
	hud.add_theme_color_override("font_color", Color("eff4ff"))
	layer.add_child(hud)
	var back := Button.new()
	back.name = "Back"
	back.text = "Back to Aiden"
	back.position = Vector2(1080, 20)
	back.custom_minimum_size = Vector2(170, 42)
	back.pressed.connect(_return_to_aiden)
	layer.add_child(back)
	if first_person:
		var crosshair := Label.new()
		crosshair.text = "+"
		crosshair.anchor_left = 0.5
		crosshair.anchor_right = 0.5
		crosshair.anchor_top = 0.5
		crosshair.anchor_bottom = 0.5
		crosshair.offset_left = -8.0
		crosshair.offset_top = -16.0
		crosshair.add_theme_font_size_override("font_size", 28)
		crosshair.add_theme_color_override("font_color", Color("d9e6fa"))
		layer.add_child(crosshair)
	var fade := ColorRect.new()
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.color = Color.BLACK
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fade)
	create_tween().tween_property(fade, "modulate:a", 0.0, 1.7).set_trans(Tween.TRANS_CUBIC)


func _return_to_aiden() -> void:
	mouse_look_active = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/aiden_test.tscn")


func _movement_input() -> Vector3:
	var direction := Vector3.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		direction.z -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		direction.z += 1.0
	if first_person:
		direction = direction.rotated(Vector3.UP, player.rotation.y)
	return direction.normalized()


func _input(event: InputEvent) -> void:
	if first_person and event is InputEventMouseMotion and mouse_look_active:
		player.rotate_y(-event.relative.x * 0.003)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * 0.003, -1.2, 1.2)
		return
	if first_person and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not mouse_look_active and event.position.y > 80.0:
		mouse_look_active = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		if first_person and mouse_look_active:
			mouse_look_active = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			_return_to_aiden()
	elif event.keycode == KEY_SPACE:
		if wall_run_left > 0.0:
			wall_run_left = 0.0
			player.velocity = wall_normal * 6.0 + Vector3.UP * 7.5
		elif player.is_on_floor():
			player.velocity.y = 7.0
	elif event.keycode == KEY_J and scream_ready and not player.is_on_floor():
		player.velocity.y = 9.0
		scream_ready = false
		message = "The words you swallowed become a lift."
		_update_hud()
	elif event.keycode == KEY_SHIFT and dash_cooldown <= 0.0 and wall_run_left <= 0.0:
		var direction := _movement_input()
		if direction != Vector3.ZERO:
			dash_direction = direction
			dash_started_airborne = not player.is_on_floor()
			dash_left = 0.25
			dash_cooldown = 0.85


func _physics_process(delta: float) -> void:
	if finished:
		return
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	var dashing := dash_left > 0.0
	var crouching := Input.is_key_pressed(KEY_CTRL) and wall_run_left <= 0.0
	if wall_run_left > 0.0:
		wall_run_left = maxf(0.0, wall_run_left - delta)
		player.velocity.x = wall_run_direction.x * WALL_RUN_SPEED - wall_normal.x * 0.5
		player.velocity.z = wall_run_direction.z * WALL_RUN_SPEED - wall_normal.z * 0.5
		player.velocity.y = maxf(player.velocity.y - GRAVITY * 0.2 * delta, -1.0)
	elif dashing:
		player.velocity.x = dash_direction.x * DASH_SPEED
		player.velocity.z = dash_direction.z * DASH_SPEED
		player.velocity.y -= GRAVITY * delta
	else:
		var speed := 2.5 if crouching else 5.5
		var travel := _movement_input() * speed
		player.velocity.x = travel.x
		player.velocity.z = travel.z
		player.velocity.y -= GRAVITY * delta
	character_art.scale.y = move_toward(character_art.scale.y, 0.72 if crouching else 1.0, delta * 3.0)
	player.move_and_slide()
	_update_camera(delta)
	if dashing and dash_started_airborne:
		for index in range(player.get_slide_collision_count()):
			var normal := player.get_slide_collision(index).get_normal()
			if absf(normal.y) < 0.2 and dash_direction.dot(normal) < -0.1:
				var along_wall := dash_direction.slide(normal)
				if along_wall.length() >= 0.7:
					_start_wall_run(normal, along_wall.normalized())
					break
	if wall_run_left <= 0.0:
		dash_left = maxf(0.0, dash_left - delta)
	if player.is_on_floor():
		scream_ready = true
	if player.position.y < -5.0:
		player.position = Vector3(0, 1.1, 1.0)
		player.velocity = Vector3.ZERO
	for index in range(karma_places.size() - 1, -1, -1):
		if player.global_position.distance_to(karma_places[index]) < 1.25:
			karma_places.remove_at(index)
			karma_nodes[index].queue_free()
			karma_nodes.remove_at(index)
			karma += 1
			message = "Karma remembers this choice."
			_update_hud()
	if not story_found and player.global_position.distance_to(story_place) < 1.3:
		story_found = true
		story_node.queue_free()
		message = "Story item: You left before hearing their answer."
		_update_hud()
	if player.position.z < -24.0:
		if player.position.x > 1.0 and karma >= 2:
			finished = true
			message = "High karma path: a clearer door opens."
		elif player.position.x < -1.0 and karma < 2:
			finished = true
			message = "Low karma path: a fractured door opens."
		elif karma >= 2:
			message = "Your karma opens the gold door on the right."
		else:
			message = "Your karma opens the violet door on the left."
		_update_hud()
	_update_hud()


func _update_camera(delta: float) -> void:
	if first_person:
		if not waking_up:
			var target_height := 0.2 if Input.is_key_pressed(KEY_CTRL) and wall_run_left <= 0.0 else 0.55
			camera.position.y = move_toward(camera.position.y, target_height, delta * 2.0)
		return
	var player_z := player.global_position.z
	if player_z < camera_focus.z - CAMERA_DEAD_ZONE:
		camera_focus.z = move_toward(camera_focus.z, player_z + CAMERA_DEAD_ZONE, delta * 12.0)
	elif player_z > camera_focus.z + CAMERA_DEAD_ZONE:
		camera_focus.z = move_toward(camera_focus.z, player_z - CAMERA_DEAD_ZONE, delta * 12.0)
	var desired_position := camera_focus + CAMERA_OFFSET
	camera.global_position = camera.global_position.lerp(desired_position, minf(1.0, delta * 5.0))
	camera.look_at(camera_focus, Vector3.UP)
	if wall_run_left > 0.0:
		camera.rotate_object_local(Vector3.FORWARD, deg_to_rad(wall_normal.x * 4.0))


func _start_wall_run(normal: Vector3, along_wall: Vector3) -> void:
	wall_run_direction = along_wall
	wall_normal = normal
	wall_run_left = 1.3
	player.velocity.y = maxf(player.velocity.y, 2.5)
	dash_left = 0.0
	message = "Wall running: crouch is unavailable. Space jumps away."
	_update_hud()


func _update_hud() -> void:
	var movement := "WALL RUN" if wall_run_left > 0.0 else "DASH" if dash_left > 0.0 else "CROUCH" if Input.is_key_pressed(KEY_CTRL) else "WALK" if _movement_input() != Vector3.ZERO else "STILL"
	var camera_hint := "Mouse: look  •  Esc: release cursor / menu" if first_person else "Overhead camera"
	hud.text = "AGE 16  •  RECONSTRUCTED HALL     Karma: %d / 3     Story item: %s     %s\nWASD: move  •  Y: yap  •  Hold Ctrl: crouchwalk  •  Space: jump  •  Shift + direction: dash  •  J: scream jump\n%s\nHigh karma (2+): gold right door  •  Low karma: violet left door     %s" % [karma, "found" if story_found else "missing", movement, camera_hint, message]
