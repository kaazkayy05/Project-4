extends CharacterBody2D
## Adjustable prototype values. Distances are pixels; durations are seconds.
@export var run_speed: float = 300.0
@export var gravity: float = 1400.0
@export var jump_speed: float = 520.0
@export var dash_speed: float = 1000.0
@export var dash_duration: float = 0.24
@export var wall_run_speed: float = 300.0
@export var wall_run_duration: float = 1.2
@export var scream_speed: float = 920.0

var facing: float = 1.0
var dash_left: float = 0.0
var dash_ready: bool = true
var scream_ready: bool = true
var wall_time: float = 0.0
var controls_locked: bool = false
var movement_state: String = "Ready"
var checkpoint: Vector2 = Vector2(100, 570)
var scream_flash: float = 0.0

func _physics_process(delta: float) -> void:
	if controls_locked:
		velocity = Vector2.ZERO
		return
	var direction := Input.get_axis("kvon_left", "kvon_right")
	if direction != 0.0:
		facing = direction
	if is_on_floor():
		dash_ready = true
		scream_ready = true
		wall_time = 0.0
	scream_flash = maxf(0.0, scream_flash - delta)
	if Input.is_action_just_pressed("kvon_dash") and dash_ready:
		dash_left = dash_duration
		dash_ready = false
	if dash_left > 0.0:
		dash_left = maxf(0.0, dash_left - delta)
		velocity = Vector2(facing * dash_speed, 0)
		movement_state = "Dash"
	else:
		velocity.x = direction * run_speed
		velocity.y += gravity * delta
		movement_state = "Run" if is_on_floor() else "Air"
		var against_wall := is_on_wall() and direction != 0.0 and direction * get_wall_normal().x < 0.0
		if against_wall and Input.is_action_pressed("kvon_wall") and wall_time < wall_run_duration:
			velocity.y = -wall_run_speed
			wall_time += delta
			movement_state = "Wall Run"
		if Input.is_action_just_pressed("kvon_jump"):
			if is_on_floor():
				velocity.y = -jump_speed
		if Input.is_action_just_pressed("kvon_scream") and scream_ready:
			velocity.y = -scream_speed
			scream_ready = false
			scream_flash = 0.35
			movement_state = "Scream Jump"
	move_and_slide()
	if position.y > 850.0:
		respawn()
	queue_redraw()

func respawn() -> void:
	position = checkpoint
	velocity = Vector2.ZERO
	dash_left = 0.0
	dash_ready = true
	scream_ready = true
	wall_time = 0.0

func _draw() -> void:
	var tint := Color("82e2d1")
	if dash_left > 0.0:
		tint = Color("ffd18b")
	elif movement_state == "Wall Run":
		tint = Color("b5a3ff")
	draw_rect(Rect2(-14, -24, 28, 48), tint)
	draw_circle(Vector2(facing * 6, -10), 3, Color("18212e"))
	if scream_flash > 0.0:
		draw_arc(Vector2.ZERO, 30 + (0.35 - scream_flash) * 150, 0, TAU, 40, Color("f1cf91"), 3)
