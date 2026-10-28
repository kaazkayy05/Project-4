extends Control

@export var picture: Texture2D

const SEAM_COLOR := Color(0.06, 0.08, 0.12, 1.0)


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	if picture == null or size.x <= 0.0 or size.y <= 0.0:
		return

	var image_size := picture.get_size()
	var fit := minf(size.x / image_size.x, size.y / image_size.y)
	var fitted_size := image_size * fit
	var rect := Rect2((size - fitted_size) * 0.5, fitted_size)
	var center := rect.get_center()

	var tl := rect.position
	var tr := Vector2(rect.end.x, rect.position.y)
	var bl := Vector2(rect.position.x, rect.end.y)
	var br := rect.end
	var tm := Vector2(center.x, rect.position.y)
	var bm := Vector2(center.x, rect.end.y)
	var lm := Vector2(rect.position.x, center.y)
	var rm := Vector2(rect.end.x, center.y)

	var radius := minf(rect.size.x, rect.size.y) * 0.075
	var vertical_top := _tab_edge(tm, center, radius, -1.0)
	var vertical_bottom := _tab_edge(center, bm, radius, 1.0)
	var horizontal_left := _tab_edge(lm, center, radius, 1.0)
	var horizontal_right := _tab_edge(center, rm, radius, -1.0)

	# Neighbors use the same curved edge in opposite directions.
	# Each polygon is an actual jigsaw-shaped image section.
	var boundaries := [
		[
			PackedVector2Array([tl, tm]),
			vertical_top,
			_reversed(horizontal_left)
		],
		[
			PackedVector2Array([tm, tr, rm]),
			_reversed(horizontal_right),
			_reversed(vertical_top)
		],
		[
			horizontal_left,
			vertical_bottom,
			PackedVector2Array([bl, lm])
		],
		[
			horizontal_right,
			PackedVector2Array([br, bm]),
			_reversed(vertical_bottom)
		]
	]

	for boundary in boundaries:
		var polygon := _join_edges(boundary)
		var uvs := PackedVector2Array()
		for point in polygon:
			uvs.append((point - rect.position) / rect.size)
		draw_polygon(
			polygon, PackedColorArray([Color.WHITE]), uvs, picture
		)

	draw_polyline(
		_join_edges([vertical_top, vertical_bottom]),
		SEAM_COLOR, 2.5, true
	)
	draw_polyline(
		_join_edges([horizontal_left, horizontal_right]),
		SEAM_COLOR, 2.5, true
	)
	draw_rect(rect, SEAM_COLOR, false, 2.5)


func _tab_edge(
	start: Vector2, end: Vector2, radius: float, direction: float
) -> PackedVector2Array:
	var tangent := (end - start).normalized()
	var normal := Vector2(-tangent.y, tangent.x) * direction
	var circle_center := (start + end) * 0.5 + normal * radius * 0.5
	var points := PackedVector2Array([start])

	# A 240-degree circular arc forms a rounded tab with a narrow neck.
	for index in range(33):
		var angle := deg_to_rad(-120.0 + 240.0 * index / 32.0)
		points.append(
			circle_center
			+ tangent * sin(angle) * radius
			+ normal * cos(angle) * radius
		)

	points.append(end)
	return points


func _reversed(points: PackedVector2Array) -> PackedVector2Array:
	var result := points.duplicate()
	result.reverse()
	return result


func _join_edges(edges: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for edge in edges:
		for point in edge:
			if result.is_empty() or not result[-1].is_equal_approx(point):
				result.append(point)

	if result.size() > 1 and result[0].is_equal_approx(result[-1]):
		result.resize(result.size() - 1)
	return result
