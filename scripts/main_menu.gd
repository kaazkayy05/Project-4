extends Control


func _ready() -> void:
	$Center/Menu/Start.pressed.connect(_start)
	$Center/Menu/Start.grab_focus()


func _start() -> void:
	if OS.has_feature("web"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().change_scene_to_file("res://scenes/level_01.tscn")
