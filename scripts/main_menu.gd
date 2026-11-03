extends Control

const SETTINGS_PATH := "user://settings.cfg"

@onready var menu_container: VBoxContainer = $Center/Menu
@onready var start_button: Button = $Center/Menu/Start
@onready var settings_button: Button = get_node_or_null("Center/Menu/Settings")
@onready var settings_panel: PanelContainer = get_node_or_null("Center/SettingsPanel")
@onready var device_option: OptionButton = get_node_or_null("Center/SettingsPanel/Margin/VBox/DeviceOption")
@onready var sensitivity_slider: HSlider = get_node_or_null("Center/SettingsPanel/Margin/VBox/SensitivitySlider")
@onready var sensitivity_label: Label = get_node_or_null("Center/SettingsPanel/Margin/VBox/SensitivityLabel")
@onready var live_meter_label: Label = get_node_or_null("Center/SettingsPanel/Margin/VBox/LiveMeterLabel")
@onready var live_meter_bar: ProgressBar = get_node_or_null("Center/SettingsPanel/Margin/VBox/LiveMeterBar")
@onready var recalibrate_button: Button = get_node_or_null("Center/SettingsPanel/Margin/VBox/RecalibrateButton")
@onready var calibration_status: Label = get_node_or_null("Center/SettingsPanel/Margin/VBox/CalibrationStatus")
@onready var back_button: Button = get_node_or_null("Center/SettingsPanel/Margin/VBox/BackButton")

var mic_player: AudioStreamPlayer
var mic_capture: AudioEffectCapture
var current_test_volume: float = 0.0


func _ready() -> void:
	start_button.pressed.connect(_start)
	start_button.grab_focus()
	if settings_button:
		settings_button.pressed.connect(_open_settings)
	if back_button:
		back_button.pressed.connect(_close_settings)
	_setup_mic_capture()
	_setup_settings()
	_auto_calibrate_at_start()
	_request_browser_mic_permission()


func _unhandled_input(event: InputEvent) -> void:
	if OS.has_feature("web") and event is InputEventMouseButton and event.pressed:
		_request_browser_mic_permission()


func _request_browser_mic_permission() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("""
			(function() {
				if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
					navigator.mediaDevices.getUserMedia({ audio: true })
						.then(function(stream) {
							console.log('Browser microphone permission granted.');
						})
						.catch(function(err) {
							console.warn('Browser microphone permission prompt error/denied:', err);
						});
				}
			})();
		""")


func _process(delta: float) -> void:
	if settings_panel and settings_panel.visible:
		_update_live_meter(delta)


func _update_live_meter(delta: float) -> void:
	if mic_capture:
		var frames := mic_capture.get_frames_available()
		if frames > 0:
			var buf := mic_capture.get_buffer(frames)
			var max_amp: float = 0.0
			for s in buf:
				max_amp = maxf(max_amp, maxf(absf(s.x), absf(s.y)))
			current_test_volume = max_amp
		else:
			current_test_volume = maxf(0.0, current_test_volume - delta * 3.0)

	var dbfs: float = clampf(linear_to_db(current_test_volume), -60.0, 0.0) if current_test_volume > 0.0001 else -60.0
	if live_meter_bar:
		live_meter_bar.value = dbfs
	if live_meter_label:
		var sens_factor := clampf(sensitivity_slider.value / 50.0, 0.1, 3.0) if sensitivity_slider else 1.0
		var eff := current_test_volume * sens_factor
		var status := "Quiet"
		if eff >= 0.22:
			status = "SCREAM DETECTED!"
		elif eff >= 0.035:
			status = "Yapping / Speaking"
		live_meter_label.text = "Live Mic Test: %d dBFS (%s)" % [roundi(dbfs), status]


func _open_settings() -> void:
	_request_browser_mic_permission()
	if menu_container:
		menu_container.hide()
	if settings_panel:
		settings_panel.show()


func _close_settings() -> void:
	if settings_panel:
		settings_panel.hide()
	if menu_container:
		menu_container.show()


func _setup_mic_capture() -> void:
	var bus_idx := AudioServer.get_bus_index("MicrophoneCapture")
	if bus_idx == -1:
		AudioServer.add_bus()
		bus_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus_idx, "MicrophoneCapture")
		AudioServer.set_bus_volume_db(bus_idx, 0.0)
		AudioServer.set_bus_mute(bus_idx, true)
		mic_capture = AudioEffectCapture.new()
		AudioServer.add_bus_effect(bus_idx, mic_capture)
	else:
		for i in range(AudioServer.get_bus_effect_count(bus_idx)):
			var eff = AudioServer.get_bus_effect(bus_idx, i)
			if eff is AudioEffectCapture:
				mic_capture = eff
				break
		if not mic_capture:
			mic_capture = AudioEffectCapture.new()
			AudioServer.add_bus_effect(bus_idx, mic_capture)
		AudioServer.set_bus_volume_db(bus_idx, 0.0)
		AudioServer.set_bus_mute(bus_idx, true)

	mic_player = AudioStreamPlayer.new()
	mic_player.stream = AudioStreamMicrophone.new()
	mic_player.bus = "MicrophoneCapture"
	mic_player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(mic_player)
	mic_player.play()


func _setup_settings() -> void:
	var config := ConfigFile.new()
	var current_val: float = 50.0
	var saved_dev: String = "Default"
	if config.load(SETTINGS_PATH) == OK:
		current_val = float(config.get_value("audio", "microphone_sensitivity", 50.0))
		if current_val < 25.0:
			current_val = 50.0
		saved_dev = config.get_value("audio", "microphone_device", "Default")

	if device_option:
		device_option.clear()
		var devices := AudioServer.get_input_device_list()
		var selected_idx := 0
		for i in range(devices.size()):
			var dev = devices[i]
			device_option.add_item(dev)
			if dev == saved_dev:
				selected_idx = i
		device_option.selected = selected_idx
		if saved_dev in devices:
			AudioServer.input_device = saved_dev
		device_option.item_selected.connect(_on_device_selected)

	if sensitivity_slider:
		sensitivity_slider.value = current_val
		_update_sensitivity_label(current_val)
		sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	if recalibrate_button:
		recalibrate_button.pressed.connect(_recalibrate)


func _on_device_selected(index: int) -> void:
	if device_option:
		var dev_name = device_option.get_item_text(index)
		if mic_player:
			mic_player.stop()
		AudioServer.input_device = dev_name
		if mic_player and not is_queued_for_deletion():
			mic_player.play()
		var config := ConfigFile.new()
		config.load(SETTINGS_PATH)
		config.set_value("audio", "microphone_device", dev_name)
		config.save(SETTINGS_PATH)
		if calibration_status:
			if "Microphone Array" in dev_name:
				calibration_status.text = "⚠️ Realtek Array needs 2-Ch in Windows (mmsys.cpl)"
			else:
				calibration_status.text = "✓ Device set to %s" % dev_name


func _auto_calibrate_at_start() -> void:
	# Sample ambient room noise for 0.4 seconds to tune sensitivity automatically
	var t := create_tween()
	t.tween_interval(0.4)
	t.tween_callback(func() -> void:
		var peak_noise := _sample_peak_noise()
		_apply_calibrated_sensitivity(peak_noise, true)
	)


func _sample_peak_noise() -> float:
	var peak: float = 0.0
	if mic_capture and mic_capture.can_get_buffer(mic_capture.get_frames_available()):
		var frames := mic_capture.get_frames_available()
		if frames > 0:
			var buffer := mic_capture.get_buffer(frames)
			for sample in buffer:
				peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
	return peak


func _apply_calibrated_sensitivity(peak_noise: float, is_auto: bool) -> void:
	var calibrated: float = 50.0
	if peak_noise > 0.001:
		calibrated = clampf((0.02 / maxf(peak_noise, 0.01)) * 50.0, 35.0, 85.0)
	if sensitivity_slider:
		sensitivity_slider.value = calibrated
	_save_sensitivity(calibrated)
	if calibration_status:
		calibration_status.text = "✓ %s calibrated (%d%%)" % ["Auto" if is_auto else "Manually", roundi(calibrated)]
		var fade := create_tween()
		fade.tween_interval(3.0)
		fade.tween_callback(func() -> void: if calibration_status: calibration_status.text = "")


func _recalibrate() -> void:
	var peak_noise := _sample_peak_noise()
	_apply_calibrated_sensitivity(peak_noise, false)


func _on_sensitivity_changed(value: float) -> void:
	_update_sensitivity_label(value)
	_save_sensitivity(value)


func _save_sensitivity(value: float) -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("audio", "microphone_sensitivity", value)
	config.save(SETTINGS_PATH)


func _update_sensitivity_label(value: float) -> void:
	if sensitivity_label:
		sensitivity_label.text = "Microphone Sensitivity: %d%%" % roundi(value)


func _start() -> void:
	_request_browser_mic_permission()
	if mic_player:
		mic_player.stop()
	if OS.has_feature("web"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().change_scene_to_file("res://scenes/level_01.tscn")
