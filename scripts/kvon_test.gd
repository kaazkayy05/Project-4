extends Node2D
## Self-contained course: runtime input bindings do not change project.godot.
const PlayerScript = preload("res://scripts/kvon_player.gd")
const PIECE_POSITIONS: Array[Vector2] = [Vector2(780, 550), Vector2(1240, 300), Vector2(1770, 70)]
const BINDS: Dictionary = {
	"kvon_left": [KEY_A, KEY_LEFT], "kvon_right": [KEY_D, KEY_RIGHT],
	"kvon_jump": [KEY_SPACE], "kvon_dash": [KEY_SHIFT],
	"kvon_wall": [KEY_W, KEY_UP], "kvon_scream": [KEY_E],
	"kvon_reset": [KEY_R], "kvon_menu": [KEY_ESCAPE]
}
var player: CharacterBody2D
var collected: int = 0
var karma: int = 0
var choice_made: bool = false
var hud: Label
var memory_panel: PanelContainer
var memory_text: Label
var help_button: Button
var leave_button: Button
var added_actions: Array[StringName] = []
var old_clear_color: Color

func _ready() -> void:
	old_clear_color = RenderingServer.get_default_clear_color()
	RenderingServer.set_default_clear_color(Color("171827"))
	for action: String in BINDS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		added_actions.append(action)
		for key: int in BINDS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
	_build_course()
	_build_player()
	_build_hud()
	for i in PIECE_POSITIONS.size():
		_add_piece(i)

func _exit_tree() -> void:
	for action in added_actions:
		InputMap.erase_action(action)
	RenderingServer.set_default_clear_color(old_clear_color)

func _build_course() -> void:
	_platform(Rect2(0, 600, 340, 120), Color("39485d"))
	_platform(Rect2(670, 600, 420, 120), Color("39485d"))
	_platform(Rect2(1040, 350, 50, 250), Color("776796"))
	_platform(Rect2(1090, 350, 360, 30), Color("554b70"))
	_platform(Rect2(1600, 120, 650, 35), Color("655d64"))
	_sign(Vector2(30, 390), "01 / CROSS THE GAP\nSpace: jump   Shift: dash\nOne dash per landing", 23)
	_sign(Vector2(700, 390), "02 / CHOOSE TO CLIMB\nHold right + W at the wall\nHold right over the top", 21)
	_sign(Vector2(1120, 170), "03 / FIND YOUR VOICE\nE: Scream Jump\nOne boost per landing", 21)
	_sign(Vector2(1800, 20), "04 / RECONSTRUCT\nCollect all 3 fragments", 22)
	_sign(Vector2(250, 680), "Falling returns you to the latest platform. Collected fragments stay with you.", 19)
	var diorama := Node2D.new()
	diorama.name = "MemoryDiorama"
	diorama.position = Vector2(2020, 120)
	diorama.visible = false
	add_child(diorama)
	for i in 3:
		var shard := Polygon2D.new()
		shard.polygon = PackedVector2Array([Vector2(-75 + i * 50, -80), Vector2(-30 + i * 50, -80), Vector2(-30 + i * 50, -10), Vector2(-75 + i * 50, -10)])
		shard.color = Color("d9bd90") if i != 1 else Color("90b1bc")
		diorama.add_child(shard)

func _platform(rect: Rect2, tint: Color) -> void:
	var body := StaticBody2D.new()
	body.position = rect.position
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	collision.position = rect.size / 2.0
	body.add_child(collision)
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([Vector2.ZERO, Vector2(rect.size.x, 0), rect.size, Vector2(0, rect.size.y)])
	visual.color = tint
	body.add_child(visual)
	add_child(body)

func _sign(at: Vector2, text: String, font_size: int) -> void:
	var label := Label.new()
	label.position = at
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("d2c8df"))
	add_child(label)

func _build_player() -> void:
	player = CharacterBody2D.new()
	player.name = "Player"
	player.set_script(PlayerScript)
	player.position = Vector2(100, 570)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(28, 48)
	collision.shape = shape
	player.add_child(collision)
	add_child(player)
	var camera := Camera2D.new()
	camera.position = Vector2(0, -210)
	camera.limit_left = 0
	camera.limit_right = 2250
	camera.limit_top = -100
	camera.limit_bottom = 720
	player.add_child(camera)

func _add_piece(index: int) -> void:
	var area := Area2D.new()
	area.name = "Fragment%d" % (index + 1)
	area.position = PIECE_POSITIONS[index]
	area.collision_layer = 0
	area.collision_mask = 1
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 24
	collision.shape = shape
	area.add_child(collision)
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([Vector2(0, -18), Vector2(18, 0), Vector2(0, 18), Vector2(-18, 0)])
	visual.color = Color("f2cd8e")
	area.add_child(visual)
	area.body_entered.connect(_collect.bind(area))
	add_child(area)

func _collect(body: Node2D, area: Area2D) -> void:
	if body != player or not area.visible:
		return
	area.hide()
	area.set_deferred("monitoring", false)
	collected += 1
	if collected == 3:
		$MemoryDiorama.show()

func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var background := ColorRect.new()
	background.color = Color(0.06, 0.07, 0.12, 0.95)
	background.size = Vector2(1280, 100)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(background)
	hud = Label.new()
	hud.position = Vector2(24, 12)
	hud.add_theme_font_size_override("font_size", 20)
	canvas.add_child(hud)
	var back := Button.new()
	back.text = "Menu (Esc)"
	back.position = Vector2(1110, 20)
	back.size = Vector2(145, 45)
	back.pressed.connect(_menu)
	canvas.add_child(back)
	memory_panel = PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("242536")
	panel_style.border_color = Color("b9a17e")
	panel_style.set_border_width_all(2)
	memory_panel.add_theme_stylebox_override("panel", panel_style)
	memory_panel.position = Vector2(300, 180)
	memory_panel.size = Vector2(680, 360)
	canvas.add_child(memory_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	memory_panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	margin.add_child(content)
	memory_text = Label.new()
	memory_text.custom_minimum_size = Vector2(630, 160)
	memory_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	memory_text.add_theme_font_size_override("font_size", 23)
	content.add_child(memory_text)
	help_button = Button.new()
	help_button.text = "Act: stop and help (+1 Karma)"
	help_button.custom_minimum_size.y = 48
	help_button.pressed.connect(_choose.bind(1))
	content.add_child(help_button)
	leave_button = Button.new()
	leave_button.text = "Do nothing: keep walking (-1 Karma)"
	leave_button.custom_minimum_size.y = 48
	leave_button.pressed.connect(_choose.bind(-1))
	content.add_child(leave_button)
	memory_panel.hide()

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("kvon_menu"):
		_menu()
	if Input.is_action_just_pressed("kvon_reset"):
		get_tree().reload_current_scene()
		return
	if player.is_on_floor():
		if player.position.x > 1630 and player.position.y < 130:
			player.checkpoint = Vector2(1650, 95)
		elif player.position.x > 1120 and player.position.y < 360:
			player.checkpoint = Vector2(1140, 325)
		elif player.position.x > 710 and player.position.y > 500:
			player.checkpoint = Vector2(720, 575)
	hud.text = "PURGATORY / MECHANICS TEST     Fragments %d/3     Karma %+d\nA/D or arrows: move   Space: jump   Shift: dash   W: wall run   E: scream   R: restart\n%s   |   Dash: %s   Scream: %s" % [collected, karma, player.movement_state, "ready" if player.dash_ready else "used", "ready" if player.scream_ready else "used"]
	if collected == 3 and player.position.x > 1920 and player.is_on_floor() and not choice_made and not memory_panel.visible:
		player.controls_locked = true
		memory_text.text = "MEMORY RECONSTRUCTED / prototype\n\nSomeone needed help. You kept walking.\nWith the memory restored, what do you choose?"
		memory_panel.show()
		help_button.grab_focus()

func _choose(change: int) -> void:
	if choice_made:
		return
	choice_made = true
	karma += change
	help_button.hide()
	leave_button.hide()
	memory_text.text = "MEMORY RESOLVED\n\n%s\nKarma: %+d\n\nTest complete. Press R to try the other choice.\nPress Esc to return to the menu." % ["You chose to act." if change > 0 else "You chose inaction.", karma]

func _menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
