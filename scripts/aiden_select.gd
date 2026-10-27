extends Control


func _ready() -> void:
	$Center/Content/ThreeDLooksTwoD.pressed.connect(_open.bind("res://scenes/aiden_3d.tscn"))
	$Center/Content/FirstPersonThreeD.pressed.connect(_open.bind("res://scenes/aiden_first_person.tscn"))
	$Center/Content/Back.pressed.connect(_open.bind("res://scenes/main_menu.tscn"))
	$Center/Content/ThreeDLooksTwoD.grab_focus()


func _open(path: String) -> void:
	get_tree().change_scene_to_file(path)
