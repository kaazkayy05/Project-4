extends Control


func _ready() -> void:
	$Center/Menu/Aiden.pressed.connect(_open_scene.bind("res://scenes/aiden_test.tscn"))
	$Center/Menu/John.pressed.connect(_open_scene.bind("res://scenes/john_test.tscn"))
	$Center/Menu/Kvon.pressed.connect(_open_scene.bind("res://scenes/kvon_test.tscn"))
	$Center/Menu/Kayla.pressed.connect(_open_scene.bind("res://scenes/kayla_test.tscn"))
	$Center/Menu/Aiden.grab_focus()


func _open_scene(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)
