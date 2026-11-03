extends Control

const META_KEY := &"karma_total"
const LIMIT := 100
const MARKS := [-50, 0, 50]
const TRACK := Rect2(0, 26, 240, 12)
const LOW_COLOR := Color(0.5, 0.06, 0.06)
const HIGH_COLOR := Color(0.96, 0.9, 0.7)

var level: Node
var level_start := 0
var shown := 0.0
var value_label: Label
var track_texture: GradientTexture2D
var base_dash_speed := 0.0
var base_dash_cooldown := 0.0
var applied_karma := INF


func setup(target: Node) -> void:
	level = target
	level_start = clampi(int(get_tree().get_meta(META_KEY, 0)), -LIMIT, LIMIT)
	level.karma_collected = level_start
	shown = level_start
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -TRACK.size.x - 24
	offset_right = -24
	offset_top = 16
	offset_bottom = 16 + TRACK.end.y + 4
	var gradient := Gradient.new()
	gradient.set_color(0, LOW_COLOR)
	gradient.set_color(1, HIGH_COLOR)
	track_texture = GradientTexture2D.new()
	track_texture.gradient = gradient
	value_label = Label.new()
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.size = Vector2(TRACK.size.x, 22)
	add_child(value_label)
	_refresh_label()
	base_dash_speed = level.player.dash_speed
	base_dash_cooldown = level.player.dash_cooldown_max


func _process(delta: float) -> void:
	if not is_instance_valid(level):
		return
	var karma: int = level.karma_collected
	if karma != clampi(karma, -LIMIT, LIMIT):
		level.karma_collected = clampi(karma, -LIMIT, LIMIT)
		if level.karma_label.text.begins_with("Karma: "):
			level.karma_label.text = "Karma: %d" % level.karma_collected
	var target := float(level.karma_collected)
	if applied_karma != target:
		applied_karma = target
		level.player.dash_cooldown_max = 2.0 if target >= 50 else base_dash_cooldown
		level.player.dash_speed = base_dash_speed * (1.5 if target <= -50 else 1.0)
		if level.has_method("_update_karma_paths"):
			level._update_karma_paths(int(target))
	if shown != target:
		shown = move_toward(shown, target, delta * 80.0)
		_refresh_label()
		queue_redraw()


func _refresh_label() -> void:
	value_label.text = "KARMA %+d" % level.karma_collected


func _x_for(value: float) -> float:
	return remap(clampf(value, -LIMIT, LIMIT), -LIMIT, LIMIT, TRACK.position.x, TRACK.end.x)


func _draw() -> void:
	draw_rect(TRACK.grow(3), Color(0, 0, 0, 0.65))
	draw_texture_rect(track_texture, TRACK, false)
	for mark in MARKS:
		var mark_x := _x_for(mark)
		draw_line(Vector2(mark_x, TRACK.position.y - 4), Vector2(mark_x, TRACK.end.y + 4),
			Color(1, 1, 1, 0.9), 2.0 if mark == 0 else 1.0)
	var marker_x := _x_for(shown)
	var middle := TRACK.get_center().y
	var diamond := PackedVector2Array([Vector2(marker_x, middle - 11),
		Vector2(marker_x + 7, middle), Vector2(marker_x, middle + 11),
		Vector2(marker_x - 7, middle)])
	draw_colored_polygon(diamond, Color.WHITE)
	diamond.append(diamond[0])
	draw_polyline(diamond, Color.BLACK, 1.5)


func _exit_tree() -> void:
	if is_instance_valid(level) and level.completed:
		get_tree().set_meta(META_KEY, level.karma_collected)
