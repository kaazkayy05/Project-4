extends CharacterBody3D
class_name Player3D

signal dash_cooldown_changed(current: float, maximum: float, is_ready: bool)
signal jump_charge_changed(charge_percent: float, is_charging: bool)
signal state_changed(new_state_name: String)

enum State {
	NORMAL,
	DASHING,
	WALL_RUNNING
}

# --- Movement Parameters ---
@export var walk_speed: float = 8.5
@export var acceleration: float = 40.0
@export var friction: float = 30.0
@export var air_acceleration: float = 20.0
@export var air_friction: float = 5.0
@export var normal_gravity: float = 24.0

# --- Dash Parameters ---
@export var dash_speed: float = 25.0
@export var dash_duration: float = 0.22
@export var dash_cooldown_max: float = 3.0

# --- Wall Run Parameters ---
@export var wall_run_speed: float = 14.0
@export var wall_gravity_scale: float = 0.3 # Gravity applies at 30% during wall run
@export var wall_run_max_duration: float = 2.5
@export var wall_jump_away_force: float = 11.0
@export var wall_jump_up_force: float = 10.0

# --- Jump Parameters (Microphone Placeholder: Hold to Charge) ---
@export var min_jump_velocity: float = 7.5
@export var max_jump_velocity: float = 16.0
@export var jump_charge_rate: float = 1.8 # Reaches full charge in ~0.55s
@export var coyote_time_duration: float = 0.15
@export var jump_buffer_duration: float = 0.15

# --- Camera Sensitivity ---
@export var mouse_sensitivity: float = 0.0028

# State Variables
var current_state: State = State.NORMAL
var dash_timer: float = 0.0
var dash_cooldown: float = 0.0
var dash_direction: Vector3 = Vector3.ZERO

var wall_normal: Vector3 = Vector3.ZERO
var wall_tangent: Vector3 = Vector3.ZERO
var wall_run_timer: float = 0.0

var is_charging_jump: bool = false
var jump_charge: float = 0.0 # 0.0 to 1.0
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var buffered_jump_velocity: float = 0.0

# Node References
@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var mesh_body: MeshInstance3D = $Visuals/Body
@onready var mesh_visor: MeshInstance3D = $Visuals/Visor
@onready var ray_left: RayCast3D = $RayCastLeft
@onready var ray_right: RayCast3D = $RayCastRight
@onready var ray_forward: RayCast3D = $RayCastForward
@onready var dash_particles: CPUParticles3D = get_node_or_null("DashParticles")

var mat_body: StandardMaterial3D
var mat_visor: StandardMaterial3D

func _init() -> void:
	_setup_inputs()

func _ready() -> void:
	_setup_inputs()
	_setup_materials()
	dash_cooldown = 0.0
	emit_signal("dash_cooldown_changed", dash_cooldown, dash_cooldown_max, true)
	emit_signal("jump_charge_changed", 0.0, false)
	emit_signal("state_changed", "NORMAL")

func _setup_inputs() -> void:
	# Ensure default input bindings exist even if project.godot doesn't have them defined
	_add_key_if_missing("move_forward", KEY_W)
	_add_key_if_missing("move_backward", KEY_S)
	_add_key_if_missing("move_left", KEY_A)
	_add_key_if_missing("move_right", KEY_D)
	_add_key_if_missing("dash", KEY_SHIFT)
	_add_key_if_missing("jump", KEY_SPACE)
	_add_key_if_missing("toggle_mouse", KEY_TAB)

func _add_key_if_missing(action: String, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = keycode
		InputMap.action_add_event(action, ev)

func _setup_materials() -> void:
	if mesh_body:
		mat_body = StandardMaterial3D.new()
		mat_body.albedo_color = Color(0.18, 0.65, 0.95, 1.0) # Bright Cyan
		mat_body.roughness = 0.3
		mat_body.emission_enabled = true
		mat_body.emission = Color(0.1, 0.4, 0.7)
		mat_body.emission_energy_multiplier = 0.6
		mesh_body.material_override = mat_body

	if mesh_visor:
		mat_visor = StandardMaterial3D.new()
		mat_visor.albedo_color = Color(0.08, 0.12, 0.16, 1.0)
		mat_visor.emission_enabled = true
		mat_visor.emission = Color(0.3, 0.8, 1.0)
		mat_visor.emission_energy_multiplier = 1.2
		mesh_visor.material_override = mat_visor

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_pivot.rotate_y(-event.relative.x * mouse_sensitivity)
		spring_arm.rotate_x(-event.relative.y * mouse_sensitivity)
		spring_arm.rotation.x = clamp(spring_arm.rotation.x, deg_to_rad(-75.0), deg_to_rad(60.0))

func _physics_process(delta: float) -> void:
	if is_on_floor():
		coyote_timer = coyote_time_duration
	else:
		coyote_timer = max(0.0, coyote_timer - delta)

	if jump_buffer_timer > 0.0:
		jump_buffer_timer -= delta
		if is_on_floor():
			velocity.y = buffered_jump_velocity
			jump_buffer_timer = 0.0
			coyote_timer = 0.0

	_update_cooldowns(delta)
	_handle_jump_charge(delta)

	match current_state:
		State.NORMAL:
			_physics_normal(delta)
		State.DASHING:
			_physics_dashing(delta)
		State.WALL_RUNNING:
			_physics_wall_running(delta)

	_update_camera_tilt(delta)
	move_and_slide()
	_update_visual_feedback()

func _update_camera_tilt(delta: float) -> void:
	if not camera:
		return
	var target_roll: float = 0.0
	if current_state == State.WALL_RUNNING:
		var side: float = wall_tangent.cross(wall_normal).y
		target_roll = deg_to_rad(12.0) if side > 0.0 else deg_to_rad(-12.0)
	camera.rotation.z = lerp_angle(camera.rotation.z, target_roll, 8.0 * delta)

func _update_cooldowns(delta: float) -> void:
	# Dash cooldown of 3 seconds only refreshes while grounded
	if is_on_floor() and dash_cooldown > 0.0:
		dash_cooldown = max(0.0, dash_cooldown - delta)
		var is_ready: bool = dash_cooldown <= 0.0
		emit_signal("dash_cooldown_changed", dash_cooldown, dash_cooldown_max, is_ready)

func _handle_jump_charge(delta: float) -> void:
	if current_state == State.WALL_RUNNING:
		# In wall-run state, pressing jump immediately ejects from the wall
		if Input.is_action_just_pressed("jump"):
			_wall_jump_eject()
		return

	if current_state == State.DASHING:
		# Do not charge jump while actively dashing
		return

	var can_jump_now := is_on_floor() or coyote_timer > 0.0

	if Input.is_action_pressed("jump") and can_jump_now:
		is_charging_jump = true
		jump_charge = min(1.0, jump_charge + delta * jump_charge_rate)
		emit_signal("jump_charge_changed", jump_charge, true)
	elif is_charging_jump:
		var jump_vel: float = lerp(min_jump_velocity, max_jump_velocity, jump_charge)
		if can_jump_now:
			velocity.y = jump_vel
			coyote_timer = 0.0
		else:
			# Buffer jump for touchdown
			buffered_jump_velocity = jump_vel
			jump_buffer_timer = jump_buffer_duration
		is_charging_jump = false
		jump_charge = 0.0
		emit_signal("jump_charge_changed", 0.0, false)

func _face_direction(dir: Vector3) -> void:
	if not is_inside_tree() or not has_node("Visuals"):
		return
	var visuals_node := get_node_or_null("Visuals") as Node3D
	if not visuals_node or not visuals_node.is_inside_tree():
		return
	if dir.length_squared() > 0.001:
		var target := visuals_node.global_position + dir
		target.y = visuals_node.global_position.y
		if not target.is_equal_approx(visuals_node.global_position):
			visuals_node.look_at(target, Vector3.UP)

func _physics_normal(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y -= normal_gravity * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	# 8-Directional Input relative to Camera Yaw
	var move_input := _get_movement_input_vector()
	var cam_yaw: float = camera_pivot.rotation.y if camera_pivot else 0.0
	var cam_forward := -Vector3(sin(cam_yaw), 0.0, cos(cam_yaw)).normalized()
	var cam_right := Vector3(cos(cam_yaw), 0.0, -sin(cam_yaw)).normalized()

	var desired_dir := (cam_right * move_input.x + cam_forward * move_input.y).normalized()

	# Horizontal acceleration / friction
	var current_h_vel := Vector3(velocity.x, 0.0, velocity.z)
	var target_h_vel := desired_dir * walk_speed
	var accel := acceleration if is_on_floor() else air_acceleration
	var deccel := friction if is_on_floor() else air_friction

	if desired_dir.length_squared() > 0.001:
		current_h_vel = current_h_vel.move_toward(target_h_vel, accel * delta)
		_face_direction(desired_dir)
	else:
		current_h_vel = current_h_vel.move_toward(Vector3.ZERO, deccel * delta)

	velocity.x = current_h_vel.x
	velocity.z = current_h_vel.z

	# Check Dash Input
	if Input.is_action_just_pressed("dash") and dash_cooldown <= 0.0:
		_start_dash(desired_dir, cam_forward)

func _get_movement_input_vector() -> Vector2:
	var x: float = 0.0
	var y: float = 0.0
	if Input.is_action_pressed("move_right") or Input.is_key_pressed(KEY_D):
		x += 1.0
	if Input.is_action_pressed("move_left") or Input.is_key_pressed(KEY_A):
		x -= 1.0
	if Input.is_action_pressed("move_forward") or Input.is_key_pressed(KEY_W):
		y += 1.0
	if Input.is_action_pressed("move_backward") or Input.is_key_pressed(KEY_S):
		y -= 1.0
	return Vector2(x, y).normalized()

func _start_dash(desired_dir: Vector3, cam_forward: Vector3) -> void:
	current_state = State.DASHING
	dash_timer = dash_duration
	dash_cooldown = dash_cooldown_max
	emit_signal("dash_cooldown_changed", dash_cooldown, dash_cooldown_max, false)
	emit_signal("state_changed", "DASHING")

	# If no direction key is held, dash straight forward in camera view
	if desired_dir.length_squared() > 0.01:
		dash_direction = desired_dir.normalized()
	else:
		dash_direction = cam_forward.normalized()

	# Zero-G Snap: cancels vertical gravity drop completely
	velocity = dash_direction * dash_speed
	velocity.y = 0.0

	_face_direction(dash_direction)

	if dash_particles:
		dash_particles.restart()
		dash_particles.emitting = true

func _physics_dashing(delta: float) -> void:
	dash_timer -= delta
	# Zero-G: Keep velocity snapped horizontally and vertically zero
	velocity.x = dash_direction.x * dash_speed
	velocity.z = dash_direction.z * dash_speed
	velocity.y = 0.0

	# Check if dashing into a wall to trigger Wall Run!
	var wall_hit := _check_wall_collision()
	if wall_hit.hit:
		_start_wall_run(wall_hit.normal)
		return

	if dash_timer <= 0.0:
		# Dash duration finished
		current_state = State.NORMAL
		emit_signal("state_changed", "NORMAL")
		# Retain some residual forward velocity
		velocity = dash_direction * walk_speed * 1.2

func _check_wall_collision() -> Dictionary:
	# Primary check: CharacterBody3D is_on_wall()
	if is_on_wall():
		var norm := get_wall_normal()
		if abs(norm.y) < 0.4: # Wall is vertical enough
			return {"hit": true, "normal": norm}

	# Secondary check: Raycasts
	if ray_forward and ray_forward.is_colliding():
		var norm := ray_forward.get_collision_normal()
		if abs(norm.y) < 0.4:
			return {"hit": true, "normal": norm}
	if ray_left and ray_left.is_colliding():
		var norm := ray_left.get_collision_normal()
		if abs(norm.y) < 0.4:
			return {"hit": true, "normal": norm}
	if ray_right and ray_right.is_colliding():
		var norm := ray_right.get_collision_normal()
		if abs(norm.y) < 0.4:
			return {"hit": true, "normal": norm}

	return {"hit": false, "normal": Vector3.ZERO}

func _start_wall_run(norm: Vector3) -> void:
	current_state = State.WALL_RUNNING
	wall_normal = norm.normalized()
	wall_run_timer = wall_run_max_duration
	emit_signal("state_changed", "WALL_RUNNING")

	# Calculate horizontal wall tangent
	# Tangent perpendicular to wall normal in XZ plane: (-normal.z, 0, normal.x)
	var t1 := Vector3(-wall_normal.z, 0.0, wall_normal.x).normalized()
	var t2 := -t1

	# Choose tangent that best matches player's incoming dash direction
	if dash_direction.dot(t1) >= dash_direction.dot(t2):
		wall_tangent = t1
	else:
		wall_tangent = t2

	# Point visuals along wall run direction
	_face_direction(wall_tangent)

func _physics_wall_running(delta: float) -> void:
	wall_run_timer -= delta

	var move_input := _get_movement_input_vector()
	var cam_yaw: float = camera_pivot.rotation.y if camera_pivot else 0.0
	var cam_forward := -Vector3(sin(cam_yaw), 0.0, cos(cam_yaw)).normalized()
	var cam_right := Vector3(cos(cam_yaw), 0.0, -sin(cam_yaw)).normalized()

	# Check dismount triggers:
	# 1. Backward input (S key) or steering away from the wall
	if move_input.y < -0.3:
		_detach_wall_run()
		return
	var steer_vector := (cam_right * move_input.x + cam_forward * move_input.y)
	if steer_vector.length_squared() > 0.1 and steer_vector.normalized().dot(wall_normal) > 0.4:
		_detach_wall_run()
		return

	# 2. Dashing off wall
	if Input.is_action_just_pressed("dash") and dash_cooldown <= 0.0:
		var desired_dir := (cam_right * move_input.x + cam_forward * move_input.y).normalized()
		_start_dash(desired_dir, cam_forward)
		return

	# 3. Time expired or reached floor
	if wall_run_timer <= 0.0 or is_on_floor():
		_detach_wall_run()
		return

	# Check if wall still present (with brief grace period on entry)
	var can_detach_for_no_wall: bool = (wall_run_max_duration - wall_run_timer) > 0.15
	var wall_hit := _check_wall_collision()
	if wall_hit.hit:
		wall_normal = wall_hit.normal.normalized()
		var t1 := Vector3(-wall_normal.z, 0.0, wall_normal.x).normalized()
		var t2 := -t1
		wall_tangent = t1 if wall_tangent.dot(t1) >= wall_tangent.dot(t2) else t2
	elif can_detach_for_no_wall and not is_on_wall():
		# Slipped past the end of the wall
		_detach_wall_run()
		return

	# Movement: run along wall tangent with 30% gravity applied
	var target_vel := wall_tangent * wall_run_speed
	# Gentle push toward wall to maintain contact with surface
	target_vel -= wall_normal * 1.5

	velocity.x = target_vel.x
	velocity.z = target_vel.z
	velocity.y -= (normal_gravity * wall_gravity_scale) * delta

func _wall_jump_eject() -> void:
	# Eject jump: Kicks away from the wall normal and upward, carrying forward momentum
	current_state = State.NORMAL
	emit_signal("state_changed", "NORMAL")

	velocity = (wall_normal * wall_jump_away_force) + (Vector3.UP * wall_jump_up_force) + (wall_tangent * (wall_run_speed * 0.5))

func _detach_wall_run() -> void:
	current_state = State.NORMAL
	emit_signal("state_changed", "NORMAL")
	# Small detachment velocity away from wall
	velocity = (wall_tangent * walk_speed) + (wall_normal * 2.0)

func _update_visual_feedback() -> void:
	if not mat_body or not mat_visor:
		return

	match current_state:
		State.DASHING:
			# Bright golden / orange glow during dash
			mat_body.emission = Color(1.0, 0.6, 0.0)
			mat_body.emission_energy_multiplier = 2.5
			mat_visor.emission = Color(1.0, 0.9, 0.2)
		State.WALL_RUNNING:
			# Neon green / lime glow while wall running
			mat_body.emission = Color(0.1, 1.0, 0.4)
			mat_body.emission_energy_multiplier = 2.0
			mat_visor.emission = Color(0.2, 1.0, 0.6)
		State.NORMAL:
			if is_charging_jump:
				# Magenta / purple pulsing charge glow
				var pulse: float = 1.0 + jump_charge * 2.5
				mat_body.emission = Color(0.8, 0.1, 0.9)
				mat_body.emission_energy_multiplier = pulse
				mat_visor.emission = Color(1.0, 0.3, 0.9)
			else:
				# Standard calm cyan glow
				mat_body.emission = Color(0.1, 0.4, 0.7)
				mat_body.emission_energy_multiplier = 0.6
				mat_visor.emission = Color(0.3, 0.8, 1.0)
				mat_visor.emission_energy_multiplier = 1.2

func respawn(spawn_pos: Vector3) -> void:
	global_position = spawn_pos
	velocity = Vector3.ZERO
	current_state = State.NORMAL
	dash_timer = 0.0
	dash_cooldown = 0.0
	is_charging_jump = false
	jump_charge = 0.0
	emit_signal("dash_cooldown_changed", 0.0, dash_cooldown_max, true)
	emit_signal("jump_charge_changed", 0.0, false)
	emit_signal("state_changed", "NORMAL")
