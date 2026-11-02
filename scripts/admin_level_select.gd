extends VBoxContainer

const PASSWORD := "1234"
const LEVEL_SCENES := [
	"res://scenes/level_01.tscn",
	"res://scenes/level_02.tscn",
	"res://scenes/level_03.tscn",
	"res://scenes/level_04.tscn",
	"res://scenes/level_05.tscn",
	"res://scenes/level_06.tscn",
]

var section: VBoxContainer
var password_label: Label
var password_field: LineEdit
var unlock_button: Button
var status_label: Label
var level_grid: GridContainer
var unlocked := false


func _ready() -> void:
	var toggle_button := Button.new()
	toggle_button.text = "Admin"
	add_child(toggle_button)
	toggle_button.pressed.connect(_toggle_section)

	section = VBoxContainer.new()
	section.hide()
	add_child(section)
	password_label = Label.new()
	password_label.text = "Admin password"
	section.add_child(password_label)
	password_field = LineEdit.new()
	password_field.secret = true
	section.add_child(password_field)
	password_field.text_submitted.connect(_on_password_submitted)
	unlock_button = Button.new()
	unlock_button.text = "Unlock"
	section.add_child(unlock_button)
	unlock_button.pressed.connect(_unlock)
	status_label = Label.new()
	section.add_child(status_label)

	level_grid = GridContainer.new()
	level_grid.columns = 2
	level_grid.hide()
	section.add_child(level_grid)
	for index in range(LEVEL_SCENES.size()):
		var level_button := Button.new()
		level_button.text = "Level %d" % (index + 1)
		level_grid.add_child(level_button)
		level_button.pressed.connect(_go_to_level.bind(LEVEL_SCENES[index]))


func _toggle_section() -> void:
	section.visible = not section.visible
	if section.visible and not unlocked:
		password_field.grab_focus()


func _on_password_submitted(_text: String) -> void:
	_unlock()


func _unlock() -> void:
	if password_field.text != PASSWORD:
		status_label.text = "Incorrect password"
		password_field.clear()
		password_field.grab_focus()
		return
	unlocked = true
	password_label.hide()
	password_field.hide()
	unlock_button.hide()
	status_label.text = "Choose a level"
	level_grid.show()


func _go_to_level(scene_path: String) -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().call_deferred("change_scene_to_file", scene_path)
