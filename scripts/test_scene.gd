extends Control


func _ready() -> void:
	$Center/Content/Back.pressed.connect(_return_to_menu)
	$Center/Content/Back.grab_focus()


func _return_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
