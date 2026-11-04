extends Node

const SETTINGS_PATH := "user://settings.cfg"

var capture: AudioEffectCapture
var player: AudioStreamPlayer


func _ready() -> void:
	var bus_index := AudioServer.get_bus_index("MicrophoneCapture")
	if bus_index == -1:
		AudioServer.add_bus()
		bus_index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus_index, "MicrophoneCapture")

	for index in range(AudioServer.get_bus_effect_count(bus_index)):
		var effect = AudioServer.get_bus_effect(bus_index, index)
		if effect is AudioEffectCapture:
			capture = effect
			break
	if capture == null:
		capture = AudioEffectCapture.new()
		AudioServer.add_bus_effect(bus_index, capture)

	AudioServer.set_bus_volume_db(bus_index, 0.0)
	AudioServer.set_bus_mute(bus_index, true)

	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		var saved_device: String = config.get_value("audio", "microphone_device", "Default")
		if saved_device in AudioServer.get_input_device_list():
			AudioServer.input_device = saved_device

	if not OS.has_feature("web"):
		var result := AudioServer.set_input_device_active(true)
		if result != OK:
			push_warning("Could not start microphone input: %s" % result)
		return

	player = AudioStreamPlayer.new()
	player.name = "MicrophonePlayer"
	player.stream = AudioStreamMicrophone.new()
	player.bus = "MicrophoneCapture"
	player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(player)
	player.play()


func read_samples() -> PackedVector2Array:
	var frames := 0
	if OS.has_feature("web"):
		if capture == null:
			return PackedVector2Array()
		frames = capture.get_frames_available()
		if frames > 0:
			return capture.get_buffer(frames)
	else:
		frames = AudioServer.get_input_frames_available()
		if frames > 0:
			return AudioServer.get_input_frames(frames)
	return PackedVector2Array()


func restart_capture() -> void:
	if not OS.has_feature("web"):
		AudioServer.set_input_device_active(false)
		var result := AudioServer.set_input_device_active(true)
		if result != OK:
			push_warning("Could not restart microphone input: %s" % result)
		return
	if not is_instance_valid(player):
		return
	player.stop()
	capture.clear_buffer()
	player.play()


func change_device(device: String) -> void:
	if AudioServer.input_device == device:
		return
	if not OS.has_feature("web"):
		AudioServer.set_input_device_active(false)
		AudioServer.input_device = device
		var result := AudioServer.set_input_device_active(true)
		if result != OK:
			push_warning("Could not start microphone input for %s: %s" % [device, result])
		return
	player.stop()
	AudioServer.input_device = device
	capture.clear_buffer()
	player.play()
