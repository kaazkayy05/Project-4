extends CharacterBody2D
## Prototype scale: 100 pixels = 1 meter. Scream Jump remains button based.
signal fell
@export var pixels_per_meter: float = 100.0
@export var run_speed: float = 300.0
@export var gravity: float = 1400.0
@export var jump_speed: float = 520.0
@export var dash_duration: float = 0.25
@export var wall_run_duration: float = 3.0
@export var scream_speed: float = 920.0

var karma: int = 0
var facing: float = 1.0
var dash_left: float = 0.0
var dash_cooldown_left: float = 0.0
var dash_cooldown_total: float = 3.0
var dash_direction := Vector2.ZERO
var dash_distance: float = 400.0
var scream_ready: bool = true
var scream_flash: float = 0.0
var controls_locked: bool = false
var interaction_available: bool = false
var movement_state: String = "Ready"
var wall_running: bool = false
var wall_time: float = 0.0
var wall_drift: float = 0.0
var wall_direction: float = -1.0
var wall_normal := Vector2.ZERO
var last_wall_id: int = 0
var chain_ready: bool = false

func _physics_process(delta: float) -> void:
	if controls_locked:
		velocity = Vector2.ZERO
		return
	var horizontal := Input.get_axis("kvon_left", "kvon_right")
	var vertical := Input.get_axis("kvon_up", "kvon_down")
	var aim := Vector2(signf(horizontal), signf(vertical)).normalized()
	if horizontal != 0.0:
		facing = horizontal
	dash_cooldown_left = maxf(0.0, dash_cooldown_left - delta)
	scream_flash = maxf(0.0, scream_flash - delta)
	if is_on_floor() and not wall_running:
		scream_ready = true
		last_wall_id = 0
		chain_ready = false
	if Input.is_action_just_pressed("kvon_dash") and dash_left <= 0.0 and dash_cooldown_left <= 0.0 and aim != Vector2.ZERO:
		dash_direction = aim
		dash_distance = (6.0 if karma <= -50 else 4.0) * pixels_per_meter
		wall_running = false
		dash_left = dash_duration
		dash_cooldown_total = 2.0 if karma >= 50 else 3.0
		dash_cooldown_left = dash_cooldown_total
	if dash_left > 0.0:
		_tick_dash(delta)
	elif wall_running:
		_tick_wall(delta, horizontal)
	else:
		velocity.x = horizontal * run_speed
		velocity.y += gravity * delta
		movement_state = "Run" if is_on_floor() else "Air"
		if Input.is_action_just_pressed("kvon_jump") and is_on_floor():
			velocity.y = -jump_speed
		_scream()
		move_and_slide()
		if not is_on_floor():
			var contact := _wall_contact()
			if contact != null and contact.get_collider_id() != last_wall_id:
				if chain_ready:
					_begin_wall(contact, -1.0)
				else:
					last_wall_id = 0
	if position.y > 850.0:
		fell.emit()
	queue_redraw()

func _tick_dash(delta: float) -> void:
	movement_state = "Dash"
	# move_and_collide permits an exact final partial tick and stops at solid objects.
	var step := minf(delta, dash_left)
	velocity = dash_direction * dash_distance / dash_duration
	var hit := move_and_collide(velocity * step)
	dash_left = maxf(0.0, dash_left - step)
	if hit == null and dash_direction.y != 0.0:
		hit = _wall_contact() # A parallel dash can run along a wall already touched.
	if hit != null:
		dash_left = 0.0
		var normal := hit.get_normal()
		var oblique := absf(dash_direction.y) >= sin(deg_to_rad(20.0))
		if not is_on_floor() and absf(normal.x) > 0.9 and dash_direction.dot(normal) <= 0.01 and oblique:
			_begin_wall(hit, signf(dash_direction.y))
		velocity = Vector2.ZERO
	elif dash_left <= 0.0:
		velocity = Vector2.ZERO

func _wall_contact() -> KinematicCollision2D:
	for side in [-1.0, 1.0]:
		var contact := KinematicCollision2D.new()
		if test_move(global_transform, Vector2(side * 4.0, 0), contact) and absf(contact.get_normal().x) > 0.9:
			return contact
	return null

func _begin_wall(contact: KinematicCollision2D, along: float) -> void:
	if contact.get_collider_id() == last_wall_id:
		return
	last_wall_id = contact.get_collider_id()
	wall_normal = contact.get_normal()
	wall_direction = along
	wall_running = true
	wall_time = 0.0
	wall_drift = 0.0
	velocity.y = 0.0
	movement_state = "Wall Run"

func _tick_wall(delta: float, horizontal: float) -> void:
	_scream()
	if not wall_running:
		velocity.x = horizontal * run_speed
		move_and_slide()
		return
	var contact := _wall_contact()
	if contact == null or contact.get_collider_id() != last_wall_id or horizontal * wall_normal.x > 0.0 or is_on_floor() or wall_time >= wall_run_duration:
		wall_running = false
		velocity = Vector2(horizontal * run_speed, velocity.y + gravity * delta)
		movement_state = "Air"
		move_and_slide()
		return
	wall_time = minf(wall_run_duration, wall_time + delta)
	wall_drift += gravity * 0.3 * delta
	velocity = Vector2(-wall_normal.x * 40.0, wall_direction * 8.0 * pixels_per_meter + wall_drift)
	movement_state = "Wall Run"
	move_and_slide()
	if wall_time >= wall_run_duration - 0.000001:
		wall_running = false

func _scream() -> void:
	# Same E boost, recharge, speed, and pulse as the original prototype.
	if Input.is_action_just_pressed("kvon_scream") and not interaction_available and scream_ready:
		velocity.y = -scream_speed
		scream_ready = false
		scream_flash = 0.35
		movement_state = "Scream Jump"
		if wall_running:
			wall_running = false
			chain_ready = true

func _draw() -> void:
	var tint := Color("82e2d1")
	if dash_left > 0.0:
		tint = Color("ffd18b")
	elif wall_running:
		tint = Color("b5a3ff")
	draw_rect(Rect2(-14, -24, 28, 48), tint)
	draw_circle(Vector2(facing * 6, -10), 3, Color("18212e"))
	draw_arc(Vector2.ZERO, 34, -PI / 2.0, TAU - PI / 2.0, 48, Color("4a4c60"), 3)
	var progress := 1.0 - dash_cooldown_left / dash_cooldown_total
	if progress > 0.0:
		draw_arc(Vector2.ZERO, 34, -PI / 2.0, -PI / 2.0 + TAU * progress, 48, Color("ffd18b"), 3)
	if scream_flash > 0.0:
		draw_arc(Vector2.ZERO, 30 + (0.35 - scream_flash) * 150, 0, TAU, 40, Color("f1cf91"), 3)
