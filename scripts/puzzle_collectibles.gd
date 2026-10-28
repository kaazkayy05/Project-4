extends Node3D

@export var source_scene: PackedScene

var collected_count: int = 0
var collected: Dictionary = {}
var finish_processed: bool = false

@onready var player: CharacterBody3D = get_parent().get_node("Player3D")
@onready var counter: Label = get_parent().get_node(
	"HUD/PuzzleCounter"
)


@onready var completion_banner: PanelContainer = get_parent().get_node(
	"HUD/VictoryBanner"
)
@onready var picture_panel: VBoxContainer = completion_banner.get_node(
	"VBox/PuzzleCompletion"
)


func _ready() -> void:
	picture_panel.hide()
	get_parent().get_node("CourseGeometry/GoalArea").body_entered.connect(
		_on_game_finished, CONNECT_DEFERRED
	)
	completion_banner.get_node("VBox/RestartButton").pressed.connect(
		_on_new_run, CONNECT_DEFERRED
	)
	get_viewport().size_changed.connect(_fit_completion)
	counter.text = "Puzzle pieces: 0/4"

	# Use the imported asset only to obtain mesh resources.
	# Its nodes are never added to the gameplay tree.
	var source := source_scene.instantiate()
	var candidates: Array[MeshInstance3D] = []
	for node in source.find_children("*", "MeshInstance3D", true, false):
		if node.mesh != null:
			candidates.append(node)

	if candidates.size() < 4:
		push_error("Puzzle asset must contain at least four mesh pieces.")
		source.free()
		return

	candidates.shuffle()

	var pickups := get_children()
	for index in range(4):
		var pickup := pickups[index] as Area3D
		var visual := pickup.get_node("Visual") as MeshInstance3D
		var selected := candidates[index]

		visual.mesh = selected.mesh

		# Stand the source's horizontal piece upright against the wall.
		var upright := Basis(Vector3.FORWARD, PI / 2.0) * selected.basis
		var bounds := Transform3D(upright, Vector3.ZERO) * selected.mesh.get_aabb()
		var longest := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
		var factor := 0.85 / longest
		visual.transform = Transform3D(
			upright.scaled(Vector3.ONE * factor),
			-bounds.get_center() * factor
		)

		pickup.set_meta("source_piece", selected.name)
		pickup.body_entered.connect(_on_body_entered.bind(pickup))

	source.free()


func _on_body_entered(body: Node3D, pickup: Area3D) -> void:
	if not is_instance_valid(pickup) or body != player:
		return

	var pickup_id := pickup.get_instance_id()
	if collected.has(pickup_id):
		return

	# Record immediately so repeated signals cannot count twice.
	collected[pickup_id] = true
	collected_count += 1
	counter.text = "Puzzle pieces: %d/4" % collected_count

	pickup.hide()
	pickup.set_deferred("monitoring", false)
	pickup.get_node("CollisionShape3D").set_deferred("disabled", true)
	pickup.queue_free()


func _on_game_finished(body: Node3D) -> void:
	if body != player or finish_processed:
		return

	finish_processed = true
	picture_panel.visible = (
		bool(get_parent().get("is_course_completed"))
		and collected_count == 4
	)
	if picture_panel.visible:
		_fit_completion()


func _fit_completion() -> void:
	if not picture_panel.visible:
		return

	var screen := get_viewport().get_visible_rect().size
	picture_panel.get_node("Picture").custom_minimum_size = Vector2(
		minf(560.0, maxf(120.0, screen.x - 48.0)),
		minf(300.0, maxf(100.0, screen.y - 300.0))
	)
	_center_completion.call_deferred()


func _center_completion() -> void:
	if not picture_panel.visible:
		return

	completion_banner.reset_size()
	completion_banner.position = (
		get_viewport().get_visible_rect().size - completion_banner.size
	) * 0.5


func _on_new_run() -> void:
	picture_panel.hide()
	get_tree().reload_current_scene()
