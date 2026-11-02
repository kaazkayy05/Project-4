extends Node

signal choice_made(amount: int)

const REACH := 2.0
const CHOICE_HEIGHT := 2.6
const PICTURE_SIZE := 1.3
const GLOW_COLOR := Color(0.94, 0.82, 0.35)

var player: Player3D
var entries: Array[Dictionary] = []
var positive_texture: Texture2D
var negative_texture: Texture2D
var prompt: Label
var active_index := -1
var open_index := -1


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


func add_interaction(at: Vector3) -> void:
	var glow := OmniLight3D.new()
	glow.position = at + Vector3(0, 1.0, 0)
	glow.light_color = GLOW_COLOR
	glow.light_energy = 2.5
	glow.omni_range = 2.5
	glow.hide()
	add_child(glow)
	var choice := Node3D.new()
	choice.position = at + Vector3(0, CHOICE_HEIGHT, 0)
	choice.hide()
	add_child(choice)
	_add_option(choice, positive_texture, "1", -0.75)
	_add_option(choice, negative_texture, "2", 0.75)
	entries.append({"position": at, "used": false, "glow": glow, "choice": choice})


func reset_interactions() -> void:
	_close_choice()
	for entry in entries:
		entry["used"] = false
		entry["glow"].hide()
	active_index = -1
	prompt.hide()


func _cropped_texture(path: String, region: Rect2) -> Texture2D:
	var atlas := AtlasTexture.new()
	atlas.atlas = load(path)
	atlas.region = region
	return atlas


func _add_option(parent: Node3D, picture: Texture2D, key_text: String, side: float) -> void:
	var sprite := Sprite3D.new()
	sprite.texture = picture
	sprite.pixel_size = PICTURE_SIZE / maxf(picture.get_width(), picture.get_height())
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.no_depth_test = true
	sprite.offset = Vector2(side / sprite.pixel_size, 0)
	parent.add_child(sprite)
	var label := Label3D.new()
	label.text = key_text
	label.font_size = 72
	label.outline_size = 16
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position.y = -PICTURE_SIZE * 0.5 - 0.2
	label.offset = Vector2(side / label.pixel_size, 0)
	parent.add_child(label)


func _distance_squared(index: int) -> float:
	var difference: Vector3 = player.global_position - entries[index]["position"]
	difference.y = 0
	return difference.length_squared()


func _process(_delta: float) -> void:
	if get_tree().paused or not is_instance_valid(player):
		prompt.hide()
		return
	if open_index >= 0 and _distance_squared(open_index) > REACH * REACH:
		_close_choice()
	active_index = -1
	var nearest := REACH * REACH
	for index in range(entries.size()):
		var in_reach: bool = not entries[index]["used"] and _distance_squared(index) <= REACH * REACH
		entries[index]["glow"].visible = in_reach
		if in_reach and _distance_squared(index) < nearest:
			nearest = _distance_squared(index)
			active_index = index
	prompt.visible = active_index >= 0 and open_index < 0


func _input(event: InputEvent) -> void:
	if open_index < 0:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_close_choice()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused or not event is InputEventKey or not event.pressed or event.echo:
		return
	if open_index < 0:
		if event.keycode != KEY_E or active_index < 0:
			return
		open_index = active_index
		entries[open_index]["choice"].show()
		prompt.hide()
	elif event.keycode == KEY_1:
		_choose(10)
	elif event.keycode == KEY_2:
		_choose(-10)
	else:
		return
	get_viewport().set_input_as_handled()


func _choose(amount: int) -> void:
	entries[open_index]["used"] = true
	entries[open_index]["glow"].hide()
	choice_made.emit(amount)
	_close_choice()


func _close_choice() -> void:
	if open_index >= 0:
		entries[open_index]["choice"].hide()
	open_index = -1
