extends Control


func _ready() -> void:
	$Center/Menu/Start.pressed.connect(_start)
	$Center/Menu/Start.grab_focus()


func _start() -> void:
	get_tree().change_scene_to_file("res://scenes/level_01.tscn")
