extends Node2D
## Revised 2D mechanics prototype. 100 pixels = 1 meter.
const PlayerScript = preload("res://scripts/kvon_player.gd")
const PIECE_POSITIONS: Array[Vector2] = [Vector2(740, 550), Vector2(1240, 300), Vector2(1720, 70)]
const BINDS: Dictionary = {
	"kvon_left": [KEY_A, KEY_LEFT], "kvon_right": [KEY_D, KEY_RIGHT],
	"kvon_up": [KEY_W, KEY_UP], "kvon_down": [KEY_S, KEY_DOWN],
	"kvon_jump": [KEY_SPACE], "kvon_dash": [KEY_SHIFT], "kvon_scream": [KEY_E],
	"kvon_one": [KEY_1, KEY_KP_1], "kvon_two": [KEY_2, KEY_KP_2],
	"kvon_reset": [KEY_R], "kvon_menu": [KEY_ESCAPE]
}
const KARMA_META: StringName = &"kvon_session_karma"
var player: CharacterBody2D
var collected: int = 0
var karma: int = 0
var entry_karma: int = 0
var hits: int = 0
var won: bool = false
var restarting: bool = false
var hud: Label
var karma_bar: ProgressBar
var objects: Array[Dictionary] = []
var hazards: Array[Area2D] = []
var open_object: int = -1
var nearby_object: int = -1
var in_object_range: bool = false
var elapsed: float = 0.0
var added_actions: Array[StringName] = []
var old_clear_color: Color

func _ready() -> void:
	old_clear_color = RenderingServer.get_default_clear_color()
	RenderingServer.set_default_clear_color(Color("171827"))
	karma = clampi(int(get_tree().get_meta(KARMA_META, 0)), -100, 100)
	entry_karma = karma
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
	_add_object(Vector2(850, 576), "Help", "Ignore")
	_add_object(Vector2(1990, 96), "Act", "Leave")
	_add_hazard(Vector2(960, 560))
	_add_hazard(Vector2(1840, 80))

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
	_sign(Vector2(30, 390), "DASH\nHold direction + Shift\n8 directions / 3s cooldown", 22)
	_sign(Vector2(700, 390), "WALL RUN\nJump, then dash up-right\nHold right over the top", 21)
	_sign(Vector2(1120, 170), "SCREAM JUMP\nE away from objects\nOne boost per landing", 21)
	_sign(Vector2(1760, 60), "MEMORY", 22)
	_sign(Vector2(300, 680), "Fall or 3 hazard hits: restart", 19)
	var diorama := Node2D.new()
	diorama.name = "MemoryDiorama"
	diorama.position = Vector2(2110, 120)
	diorama.visible = false
	add_child(diorama)
	for i in 3:
		var shard := Polygon2D.new()
		shard.polygon = PackedVector2Array([Vector2(-75 + i * 50, -80), Vector2(-30 + i * 50, -80), Vector2(-30 + i * 50, -10), Vector2(-75 + i * 50, -10)])
		shard.color = Color("d9bd90") if i != 1 else Color("90b1bc")
		diorama.add_child(shard)
	_sign(Vector2(2160, 50), "EXIT", 24)
	var exit := Area2D.new()
	exit.name = "Exit"
	exit.position = Vector2(2200, 80)
	exit.collision_layer = 0
	var exit_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(36, 80)
	exit_shape.shape = rectangle
	exit.add_child(exit_shape)
	var outline := Polygon2D.new()
	outline.polygon = PackedVector2Array([Vector2(-18,-40), Vector2(18,-40), Vector2(18,40), Vector2(-18,40)])
	outline.color = Color(0.5, 0.85, 0.75, 0.4)
	exit.add_child(outline)
	exit.body_entered.connect(_exit_touch)
	add_child(exit)

func _exit_touch(body: Node2D) -> void:
	if body == player and not restarting:
		won = true
		player.controls_locked = true
		_close_choice()

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

func _sign(at: Vector2, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.position = at
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("d2c8df"))
	add_child(label)
	return label

func _build_player() -> void:
	player = CharacterBody2D.new()
	player.name = "Player"
	player.set_script(PlayerScript)
	player.position = Vector2(100, 570)
	player.karma = karma
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(28, 48)
	collision.shape = shape
	player.add_child(collision)
	player.fell.connect(_restart)
	add_child(player)
	var camera := Camera2D.new()
	camera.position = Vector2(0, -210)
	camera.limit_left = 0
	camera.limit_right = 2250
	camera.limit_top = -220
	camera.limit_bottom = 720
	player.add_child(camera)

func _add_piece(index: int) -> void:
	var area := Area2D.new()
	area.name = "Fragment%d" % (index + 1)
	area.position = PIECE_POSITIONS[index]
	area.collision_layer = 0
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

func _add_object(at: Vector2, positive: String, negative: String) -> void:
	var marker := Polygon2D.new()
	marker.position = at
	marker.polygon = PackedVector2Array([Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)])
	add_child(marker)
	var panel := PanelContainer.new()
	panel.position = at + Vector2(-100, -140)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("242536")
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = "1: %s (+10)\n2: %s (-10)" % [positive, negative]
	label.add_theme_font_size_override("font_size", 20)
	panel.add_child(label)
	panel.hide()
	add_child(panel)
	objects.append({"marker": marker, "panel": panel, "used": false})

func _add_hazard(at: Vector2) -> void:
	var area := Area2D.new()
	area.position = at
	area.set_meta("origin", at)
	area.collision_layer = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(26, 26)
	collision.shape = shape
	area.add_child(collision)
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([Vector2(-13, -13), Vector2(13, -13), Vector2(13, 13), Vector2(-13, 13)])
	visual.color = Color("e97983")
	area.add_child(visual)
	area.body_entered.connect(_hazard_touch)
	add_child(area)
	hazards.append(area)

func _hazard_touch(body: Node2D) -> void:
	if body != player or won or restarting:
		return
	hits += 1
	if hits >= 3:
		_restart()

func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var background := ColorRect.new()
	background.color = Color("10121e")
	background.size = Vector2(1280, 130)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(background)
	hud = Label.new()
	hud.position = Vector2(24, 8)
	hud.add_theme_font_size_override("font_size", 19)
	canvas.add_child(hud)
	karma_bar = ProgressBar.new()
	karma_bar.position = Vector2(24, 90)
	karma_bar.size = Vector2(450, 12)
	karma_bar.min_value = -100
	karma_bar.max_value = 100
	karma_bar.show_percentage = false
	canvas.add_child(karma_bar)
	for i in 5:
		var mark := Label.new()
		mark.position = Vector2(4 + i * 112.5, 104)
		mark.size.x = 40
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.text = ["-100", "-50", "0", "+50", "+100"][i]
		mark.add_theme_font_size_override("font_size", 14)
		canvas.add_child(mark)
	for fraction in [0.25, 0.5, 0.75]:
		var tick := ColorRect.new()
		tick.position = Vector2(24 + 450 * fraction, 88)
		tick.size = Vector2(2, 16)
		tick.color = Color("f1cf91")
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(tick)
	var back := Button.new()
	back.text = "Menu (Esc)"
	back.position = Vector2(1110, 20)
	back.size = Vector2(145, 45)
	back.pressed.connect(_menu)
	canvas.add_child(back)

func _physics_process(delta: float) -> void:
	if restarting:
		return
	if Input.is_action_just_pressed("kvon_menu"):
		_menu()
		return
	if Input.is_action_just_pressed("kvon_reset"):
		_restart()
		return
	elapsed += delta
	for i in hazards.size():
		var origin: Vector2 = hazards[i].get_meta("origin")
		hazards[i].position = origin + Vector2(sin(elapsed * 2.0 + i) * 35, 0)
	nearby_object = -1
	in_object_range = false
	var nearest: float = 2.0 * player.pixels_per_meter
	for i in objects.size():
		var distance: float = player.position.distance_to(objects[i].marker.position)
		if distance <= 2.0 * player.pixels_per_meter:
			in_object_range = true
		if not objects[i].used and distance <= nearest:
			nearest = distance
			nearby_object = i
		objects[i].marker.color = Color("6b6571") if objects[i].used else (Color("ffe6a2") if distance <= 2.0 * player.pixels_per_meter else Color("a8916a"))
	if open_object >= 0 and (objects[open_object].used or player.position.distance_to(objects[open_object].marker.position) > 2.0 * player.pixels_per_meter):
		_close_choice()
	player.interaction_available = in_object_range
	if Input.is_action_just_pressed("kvon_scream") and nearby_object >= 0 and not won:
		_close_choice()
		open_object = nearby_object
		objects[open_object].panel.show()
	if open_object >= 0:
		if Input.is_action_just_pressed("kvon_one"):
			_choose(10)
		elif Input.is_action_just_pressed("kvon_two"):
			_choose(-10)

func _process(_delta: float) -> void:
	karma_bar.value = karma
	var context := "E: choose" if nearby_object >= 0 else ("Object resolved" if in_object_range else "E: scream")
	var status := "Exit reached! R: replay / Esc: menu" if won else "%s / Dash %.1fs / %s" % [player.movement_state, player.dash_cooldown_left, context]
	hud.text = "Fragments %d/3   Hits %d/3   Karma %+d\nWASD/arrows + Shift: dash   Space: jump   E: context   1/2: choice   R: restart\n%s" % [collected, hits, karma, status]

func _choose(change: int) -> void:
	if open_object < 0 or objects[open_object].used:
		return
	objects[open_object].used = true
	_set_karma(karma + change)
	_close_choice()

func _set_karma(value: int) -> void:
	karma = clampi(value, -100, 100)
	player.karma = karma
	get_tree().set_meta(KARMA_META, karma)

func _close_choice() -> void:
	if open_object >= 0:
		objects[open_object].panel.hide()
	open_object = -1

func _restart() -> void:
	if restarting:
		return
	restarting = true
	player.controls_locked = true
	get_tree().set_meta(KARMA_META, entry_karma)
	get_tree().call_deferred("reload_current_scene")

func _menu() -> void:
	get_tree().set_meta(KARMA_META, karma)
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
