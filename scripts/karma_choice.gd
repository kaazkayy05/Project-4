extends Node

signal choice_made(amount: int)

const REACH := 2.8

var player: Player3D
var entries: Array[Dictionary] = []
var positive_texture: Texture2D
var negative_texture: Texture2D
var prompt: Label
var choice_screen: Control
var active_index := -1
var player_was_processing := false


func setup(target: Player3D, positive_path: String, negative_path: String,
		positive_region: Rect2, negative_region: Rect2) -> void:
	player = target
	positive_texture = _cropped_texture(positive_path, positive_region)
	negative_texture = _cropped_texture(negative_path, negative_region)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	prompt = Label.new()
	prompt.text = "[E]"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.position = Vector2(-50, -115)
	prompt.size = Vector2(100, 40)
	prompt.hide()
	layer.add_child(prompt)
	choice_screen = ColorRect.new()
	choice_screen.color = Color(0, 0, 0, 0.76)
	choice_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	choice_screen.hide()
	layer.add_child(choice_screen)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	choice_screen.add_child(center)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	center.add_child(row)
	_add_picture(row, positive_texture, 10)
	_add_picture(row, negative_texture, -10)


func add_interaction(at: Vector3) -> void:
	entries.append({"position": at, "used": false})


func _cropped_texture(path: String, region: Rect2) -> Texture2D:
	var atlas := AtlasTexture.new()
	atlas.atlas = load(path)
	atlas.region = region
	return atlas


func _add_picture(parent: HBoxContainer, picture: Texture2D, amount: int) -> void:
	var button := TextureButton.new()
	button.texture_normal = picture
	button.custom_minimum_size = Vector2(360, 360)
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.ignore_texture_size = true
	button.pressed.connect(_choose.bind(amount))
	parent.add_child(button)


func _process(_delta: float) -> void:
	if choice_screen.visible or get_tree().paused or not is_instance_valid(player):
		prompt.hide()
		return
	active_index = -1
	var nearest := REACH * REACH
	for index in range(entries.size()):
		if entries[index]["used"]:
			continue
		var difference: Vector3 = player.global_position - entries[index]["position"]
		difference.y = 0
		var distance := difference.length_squared()
		if distance < nearest:
			nearest = distance
			active_index = index
	prompt.visible = active_index >= 0


func _input(event: InputEvent) -> void:
	if not choice_screen.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_close_choice()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused or choice_screen.visible or active_index < 0:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		choice_screen.show()
		prompt.hide()
		player_was_processing = player.is_physics_processing()
		player.set_physics_process(false)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()


func _choose(amount: int) -> void:
	if active_index < 0:
		return
	entries[active_index]["used"] = true
	choice_made.emit(amount)
	_close_choice()


func _close_choice() -> void:
	choice_screen.hide()
	player.set_physics_process(player_was_processing)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	active_index = -1
