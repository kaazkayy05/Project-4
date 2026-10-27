extends Node3D

const Player3D = preload("res://scripts/player_3d.gd")

@onready var player: CharacterBody3D = $Player3D
@onready var spawn_point: Marker3D = $SpawnPoint
@onready var kill_zone: Area3D = $KillZone
@onready var goal_area: Area3D = $CourseGeometry/GoalArea
@onready var goal_confetti: CPUParticles3D = get_node_or_null("CourseGeometry/GoalPlatform/GoalConfetti")

# UI References
@onready var hud: CanvasLayer = $HUD
@onready var back_button: Button = $HUD/TopBar/BackButton
@onready var mouse_hint_label: Label = $HUD/TopBar/MouseHintLabel
@onready var timer_label: Label = get_node_or_null("HUD/TopBar/TimerLabel")
@onready var state_label: Label = $HUD/BottomPanel/Margin/HBox/StateBox/StateLabel
@onready var dash_bar: ProgressBar = $HUD/BottomPanel/Margin/HBox/DashBox/DashBar
@onready var dash_label: Label = $HUD/BottomPanel/Margin/HBox/DashBox/DashLabel
@onready var jump_bar: ProgressBar = $HUD/BottomPanel/Margin/HBox/JumpBox/JumpBar
@onready var jump_label: Label = $HUD/BottomPanel/Margin/HBox/JumpBox/JumpLabel
@onready var victory_banner: PanelContainer = $HUD/VictoryBanner
@onready var stats_label: Label = get_node_or_null("HUD/VictoryBanner/VBox/StatsLabel")
@onready var restart_goal_button: Button = $HUD/VictoryBanner/VBox/RestartButton

var is_cursor_visible: bool = false
var current_checkpoint_pos: Vector3

var run_time: float = 0.0
var falls_count: int = 0
var is_course_completed: bool = false

func _ready() -> void:
	# Start with captured mouse for smooth third-person look
	_set_mouse_mode(true)

	if spawn_point:
		current_checkpoint_pos = spawn_point.global_position

	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	if restart_goal_button:
		restart_goal_button.pressed.connect(_on_restart_course_pressed)

	if kill_zone:
		kill_zone.body_entered.connect(_on_kill_zone_body_entered)
	if goal_area:
		goal_area.body_entered.connect(_on_goal_reached)

	if player:
		player.dash_cooldown_changed.connect(_on_dash_cooldown_changed)
		player.jump_charge_changed.connect(_on_jump_charge_changed)
		player.state_changed.connect(_on_player_state_changed)

	if victory_banner:
		victory_banner.visible = false

	_update_timer_display()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_mouse") or (event is InputEventKey and event.pressed and (event.keycode == KEY_ESCAPE or event.keycode == KEY_TAB)):
		_toggle_mouse_mode()
	elif event is InputEventMouseButton and event.pressed:
		if is_cursor_visible and not _is_mouse_over_ui():
			_set_mouse_mode(true)

func _toggle_mouse_mode() -> void:
	_set_mouse_mode(not (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED))

func _set_mouse_mode(captured: bool) -> void:
	if captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		is_cursor_visible = false
		if mouse_hint_label:
			mouse_hint_label.text = "Mouse: Look around (Press [Tab] or [Esc] to show cursor)"
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		is_cursor_visible = true
		if mouse_hint_label:
			mouse_hint_label.text = "Cursor Active: Click anywhere to look around"

func _is_mouse_over_ui() -> bool:
	if back_button and back_button.get_global_rect().has_point(get_viewport().get_mouse_position()):
		return true
	if victory_banner and victory_banner.visible and victory_banner.get_global_rect().has_point(get_viewport().get_mouse_position()):
		return true
	return false

func _process(delta: float) -> void:
	if not is_course_completed:
		run_time += delta
		_update_timer_display()

func _physics_process(_delta: float) -> void:
	# Safety check: if player somehow falls past killzone y-boundary
	if player and player.global_position.y < -30.0:
		_respawn_player()

func _on_kill_zone_body_entered(body: Node) -> void:
	if body == player:
		_respawn_player()

func _on_goal_reached(body: Node) -> void:
	if body == player and not is_course_completed:
		is_course_completed = true
		if victory_banner:
			victory_banner.visible = true
		if stats_label:
			stats_label.text = "Time: %s | Falls: %d" % [_format_time(run_time), falls_count]
		if goal_confetti:
			goal_confetti.restart()
			goal_confetti.emitting = true
		_set_mouse_mode(false)

func set_checkpoint(new_pos: Vector3) -> void:
	current_checkpoint_pos = new_pos
	if mouse_hint_label:
		mouse_hint_label.text = "Checkpoint saved! (Press [Tab] or [Esc] to show cursor)"

func _on_restart_course_pressed() -> void:
	if victory_banner:
		victory_banner.visible = false
	if goal_confetti:
		goal_confetti.emitting = false
	if spawn_point:
		current_checkpoint_pos = spawn_point.global_position
	run_time = 0.0
	falls_count = 0
	is_course_completed = false
	_respawn_player(false) # Don't count restarting as a fall
	_set_mouse_mode(true)

func _respawn_player(increment_falls: bool = true) -> void:
	if player:
		if increment_falls:
			falls_count += 1
			_update_timer_display()
		var target := current_checkpoint_pos if current_checkpoint_pos != Vector3.ZERO else (spawn_point.global_position if spawn_point else Vector3.ZERO)
		player.respawn(target)

func _update_timer_display() -> void:
	if timer_label:
		timer_label.text = "TIME: %s | FALLS: %d" % [_format_time(run_time), falls_count]

func _format_time(seconds: float) -> String:
	var mins := int(seconds) / 60
	var secs := int(seconds) % 60
	var msecs := int((seconds - int(seconds)) * 100)
	return "%02d:%02d.%02d" % [mins, secs, msecs]

func _on_dash_cooldown_changed(current: float, maximum: float, is_ready: bool) -> void:
	if dash_bar:
		dash_bar.max_value = maximum
		dash_bar.value = maximum - current
	if dash_label:
		if is_ready:
			dash_label.text = "DASH: READY [SHIFT]"
			dash_label.modulate = Color(0.3, 1.0, 0.4)
		else:
			dash_label.text = "DASH REFRESH (touch floor): %.1fs" % current
			dash_label.modulate = Color(1.0, 0.7, 0.2)

func _on_jump_charge_changed(charge_percent: float, is_charging: bool) -> void:
	if jump_bar:
		jump_bar.value = charge_percent * 100.0
	if jump_label:
		if is_charging:
			jump_label.text = "CHARGING JUMP: %d%%" % int(charge_percent * 100.0)
			jump_label.modulate = Color(1.0, 0.3, 0.9)
		else:
			jump_label.text = "JUMP: HOLD [SPACE] TO CHARGE"
			jump_label.modulate = Color(0.8, 0.9, 1.0)

func _on_player_state_changed(new_state_name: String) -> void:
	if state_label:
		match new_state_name:
			"NORMAL":
				state_label.text = "STATE: GROUND / AIR"
				state_label.modulate = Color(0.8, 0.9, 1.0)
			"DASHING":
				state_label.text = "STATE: ZERO-G DASH"
				state_label.modulate = Color(1.0, 0.7, 0.1)
			"WALL_RUNNING":
				state_label.text = "STATE: WALL RUN (30% GRAVITY)"
				state_label.modulate = Color(0.2, 1.0, 0.5)

func _on_back_pressed() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
