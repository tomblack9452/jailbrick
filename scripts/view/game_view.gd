extends Node3D
## Greybox view of a run. Draws a TurnController, turns mouse/touch drags into
## aim + fire, steps the volley at the sim's fixed tick rate, and handles the
## run flow: banking coins, continues and restarting at a level.
##
## Board space (x right, y down, one unit per cell) maps to world space as
## (x - columns / 2, -y, 0), so the launcher line sits at world y = 0.

## Space above the launcher line for the HUD, in UI pixels (1080-wide layout).
const TOP_MARGIN_PX := 330.0
## Board units left of the board for the level gauge, and right of it.
const LEFT_MARGIN := 1.4
const RIGHT_MARGIN := 0.3
const GAUGE_COLOR := Color(0.36, 0.79, 0.65)
const MAX_TICKS_PER_FRAME := 64
const AIM_DOT_SPACING := 0.45
const AIM_DOT_COUNT := 120
## Ignore aims closer than this below the launcher line (board units).
const MIN_AIM_DEPTH := 0.35
## Long volleys speed themselves up after this many seconds.
const AUTO_FAST_AFTER := 5.0
const DANGER_COLOR := Color(0.9, 0.15, 0.12)

var game: TurnController
var progress: Progress

var _brick_views := {} # brick id -> BrickView
var _pickup_views := {} # pickup id -> PickupView
var _level_markers := {} # level -> Node3D (its bottom line on the gauge)
var _balls: Array[MeshInstance3D] = []
var _aim_dots: Array[MeshInstance3D] = []
var _ghost_ball: MeshInstance3D
var _launcher: Node3D
var _ball_count: Label3D
var _danger_material: StandardMaterial3D
var _backdrop_material: StandardMaterial3D
var _ball_mesh := SphereMesh.new()
var _ball_material := _flat_material(Color(0.95, 0.95, 0.9))

var _aiming := false
var _aim := PackedFloat64Array()
var _tick_debt := 0.0
var _fast_forward_time := 0.0
var _speed := 1
var _result_shown := false
var _banked := 0
var _shown_level := 1
var _last_line_row := 0
var _effects_seen := 0

@onready var _camera: Camera3D = $Camera3D
@onready var _board_root: Node3D = $Board
@onready var _hud: Hud = $HUD
@onready var _environment: Environment = $WorldEnvironment.environment


func _ready() -> void:
	_ball_mesh.radius = BallSim.RADIUS
	_ball_mesh.height = BallSim.RADIUS * 2.0
	progress = Progress.load_from()
	_hud.recall_pressed.connect(func() -> void: game.recall())
	_hud.continue_pressed.connect(_continue_run)
	_hud.start_pressed.connect(_start_from)
	get_viewport().size_changed.connect(_frame_camera)
	start_run(1)


func start_run(level: int) -> void:
	for child in _board_root.get_children():
		child.queue_free()
	_brick_views.clear()
	_pickup_views.clear()
	_level_markers.clear()
	_balls.clear()
	_aim_dots.clear()
	_aiming = false
	_result_shown = false
	_banked = 0
	_effects_seen = 0
	_hud.hide_trapped()

	game = TurnController.create(randi(), level)
	_shown_level = game.level
	_last_line_row = game.level_line_row
	_build_room()
	_frame_camera()
	_sync(true)
	_tint_world(-1.0)
	_hud.show_banner(game.generator.curve.world_name(game.level) + "\n" + Hud.level_title(game))


## Pays for a start at `level` (level 1 is free) and begins the run.
func _start_from(level: int) -> void:
	if not progress.pay_for_start(level):
		return
	progress.save()
	start_run(level)


## Stub: Phase 8 puts a rewarded ad in front of this.
func _continue_run() -> void:
	if game.continue_run():
		_result_shown = false
		_hud.hide_trapped()


func _process(delta: float) -> void:
	if game.phase == TurnController.Phase.VOLLEY:
		_speed = _volley_speed(delta)
		_tick_debt += delta * _speed
		var ticks := 0
		while _tick_debt >= BallSim.TICK and game.phase == TurnController.Phase.VOLLEY:
			game.step()
			_tick_debt -= BallSim.TICK
			ticks += 1
			if ticks >= MAX_TICKS_PER_FRAME:
				_tick_debt = 0.0
				break
	else:
		_speed = 1
		_tick_debt = 0.0
		_fast_forward_time = 0.0

	_sync(false)
	var can_recall := game.volley != null and game.volley.can_recall()
	var best := maxi(progress.best_level, game.level)
	_hud.refresh(game, progress.coins + game.coins_earned() - _banked, best, can_recall, _speed)

	if game.level > _shown_level:
		var new_world := game.generator.curve.world_index(game.level) != game.generator.curve.world_index(_shown_level)
		_shown_level = game.level
		var title := Hud.level_title(game)
		if new_world:
			title = game.generator.curve.world_name(game.level) + "\n" + title
		_hud.show_banner(title)
	_tint_world(delta)

	if game.phase == TurnController.Phase.LOST and not _result_shown:
		_result_shown = true
		_hide_aim()
		progress.bank(game.coins_earned() - _banked, game.level)
		_banked = game.coins_earned()
		progress.save()
		_hud.show_trapped(game, progress.coins, progress.best_level)

	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 150.0) if game.rows_until_trapped() <= 2 else 0.0
	_danger_material.albedo_color = DANGER_COLOR.lerp(Color(1.0, 0.75, 0.6), pulse)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			start_run(1)
		elif event.keycode == KEY_Q and game.volley != null and game.volley.can_recall():
			game.recall()

	if game.phase != TurnController.Phase.AIM:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_aiming = true
				_update_aim(event.position)
			elif _aiming:
				_aiming = false
				_hide_aim()
				if not _aim.is_empty():
					game.fire(_aim[0], _aim[1])
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_aiming = false
			_hide_aim()
	elif event is InputEventMouseMotion and _aiming:
		_update_aim(event.position)


func _volley_speed(delta: float) -> int:
	if _hud.fast_forward_held or Input.is_key_pressed(KEY_SPACE):
		_fast_forward_time += delta
		return 4 if _fast_forward_time > 0.8 else 2
	_fast_forward_time = 0.0
	if game.volley.tick > AUTO_FAST_AFTER * BallSim.TICK_RATE:
		return 2
	return 1


# --- Aiming -----------------------------------------------------------------

func _update_aim(screen_position: Vector2) -> void:
	var origin := _camera.project_ray_origin(screen_position)
	var normal := _camera.project_ray_normal(screen_position)
	_aim = PackedFloat64Array()
	if not is_zero_approx(normal.z):
		var hit := origin + normal * (-origin.z / normal.z)
		var board_x := hit.x + game.board.columns / 2.0
		var board_y := -hit.y
		if board_y >= MIN_AIM_DEPTH:
			_aim = TurnController.clamp_aim(board_x - game.launch_x, board_y)
	_draw_aim()


func _draw_aim() -> void:
	if _aim.is_empty():
		_hide_aim()
		return
	var path := BallSim.trace_aim(game.board, game.launch_x, _aim[0], _aim[1])
	var dot := 0
	var carry := 0.0
	for i in path.size() - 1:
		var a := path[i]
		var b := path[i + 1]
		var length := a.distance_to(b)
		var along := carry
		while along < length and dot < _aim_dots.size():
			var p := a.lerp(b, along / length)
			_aim_dots[dot].position = _to_world(p.x, p.y)
			_aim_dots[dot].show()
			dot += 1
			along += AIM_DOT_SPACING
		carry = along - length
	for i in range(dot, _aim_dots.size()):
		_aim_dots[i].hide()
	_ghost_ball.visible = path.size() > 2
	if _ghost_ball.visible:
		_ghost_ball.position = _to_world(path[1].x, path[1].y)


func _hide_aim() -> void:
	for dot in _aim_dots:
		dot.hide()
	if _ghost_ball:
		_ghost_ball.hide()


# --- Syncing views to the core ------------------------------------------------

func _sync(instant: bool) -> void:
	var board := game.board
	# Rows the board scrolled since last frame (-1 for a rise, more on a level
	# clear). Things coming into view start where they were and slide with the rest.
	var scrolled := 0 if instant else game.level_line_row - _last_line_row
	_last_line_row = game.level_line_row
	var from := Vector3(0.0, scrolled, 0.0)

	var alive := {}
	var below := {}
	for brick in board.bricks + board.sludge:
		if brick.row >= board.rows:
			below[brick.id] = true
			continue
		alive[brick.id] = true
		var target := _to_world(brick.col + brick.width / 2.0, brick.row + 0.5)
		var view: BrickView = _brick_views.get(brick.id)
		if view == null:
			view = BrickView.new()
			_board_root.add_child(view)
			view.setup(brick, target + from)
			_brick_views[brick.id] = view
		view.target = target
		view.set_hp(brick.hp)
	for id in _brick_views.keys():
		if not alive.has(id):
			var view: BrickView = _brick_views[id]
			if below.has(id):
				view.queue_free()
			else:
				view.break_apart()
			_brick_views.erase(id)

	alive.clear()
	for pickup in board.pickups:
		if pickup.row >= board.rows:
			continue
		alive[pickup.id] = true
		var target := _to_world(pickup.col + 0.5, pickup.row + 0.5)
		var view: PickupView = _pickup_views.get(pickup.id)
		if view == null:
			view = PickupView.new()
			_board_root.add_child(view)
			view.setup(pickup, target + from)
			_pickup_views[pickup.id] = view
		view.target = target
	for id in _pickup_views.keys():
		if not alive.has(id):
			_pickup_views[id].collect()
			_pickup_views.erase(id)

	_sync_level_markers(from)
	_sync_effects()

	var used := 0
	if game.volley != null and game.phase == TurnController.Phase.VOLLEY:
		for ball in game.volley.balls:
			if not ball.active:
				continue
			if used == _balls.size():
				_balls.append(_make_sphere(_ball_mesh, _ball_material))
			_balls[used].position = _to_world(ball.x, ball.y)
			_balls[used].show()
			used += 1
	for i in range(used, _balls.size()):
		_balls[i].hide()

	var launcher_target := _to_world(game.launch_x, 0.0)
	_launcher.position = launcher_target if instant else _launcher.position.lerp(launcher_target, 0.25)
	var waiting := game.volley.to_launch if game.volley != null else game.ball_count
	_ball_count.text = "x%d" % waiting
	_ball_count.visible = waiting > 0


## Plays any new board effects: a flash over each gas blast and down each laser beam.
func _sync_effects() -> void:
	var effects := game.board.effects
	if effects.size() < _effects_seen:
		_effects_seen = 0 # a new volley cleared the list
	for i in range(_effects_seen, effects.size()):
		var effect: Dictionary = effects[i]
		match effect["kind"]:
			"blast":
				_flash(Vector3(3.0, 3.0, 0.05), _to_world(effect["col"] + 0.5, effect["row"] + 0.5), Color(1.0, 0.6, 0.15, 0.8))
			"laser":
				var columns := float(game.board.columns)
				if effect["vertical"]:
					_flash(Vector3(0.3, game.board.rows, 0.05), _to_world(effect["col"] + 0.5, game.board.rows / 2.0), Color(1.0, 0.25, 0.25, 0.85))
				else:
					_flash(Vector3(columns, 0.3, 0.05), _to_world(columns / 2.0, effect["row"] + 0.5), Color(1.0, 0.25, 0.25, 0.85))
	_effects_seen = effects.size()


func _flash(size: Vector3, at: Vector3, color: Color) -> void:
	var material := _flat_material(color)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var box := _add_box(size, at + Vector3(0.0, 0.0, 0.6), material)
	var tween := create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, 0.35)
	tween.tween_callback(box.queue_free)


## One marker per level line in view: a long tick and number on the gauge,
## and a dashed line across the board.
func _sync_level_markers(from: Vector3) -> void:
	var alive := {}
	for k in 4:
		var level := game.level + k
		var row := game.level_line_row + k * TurnController.LEVEL_ROWS
		if row > game.board.rows:
			break
		alive[level] = true
		var target := Vector3(0.0, -row, 0.0)
		var marker: Node3D = _level_markers.get(level)
		if marker == null:
			marker = _make_level_marker(level)
			marker.position = target + from
			_level_markers[level] = marker
		marker.set_meta("target", target)
	var blend := 1.0 - exp(-BrickView.SLIDE_RATE * get_process_delta_time())
	for level in _level_markers.keys():
		var marker: Node3D = _level_markers[level]
		if not alive.has(level):
			marker.queue_free()
			_level_markers.erase(level)
			continue
		marker.position = marker.position.lerp(marker.get_meta("target"), blend)


func _make_level_marker(level: int) -> Node3D:
	var marker := Node3D.new()
	_board_root.add_child(marker)
	var columns := float(game.board.columns)
	_add_box(Vector3(LEFT_MARGIN - 0.1, 0.08, 0.05), Vector3(-columns / 2.0 - LEFT_MARGIN / 2.0, 0.0, 0.4), _flat_material(GAUGE_COLOR), marker)
	var dash_material := _flat_material(GAUGE_COLOR.darkened(0.45))
	var x := 0.15
	while x < columns:
		_add_box(Vector3(0.3, 0.05, 0.02), Vector3(-columns / 2.0 + x, 0.0, -0.5), dash_material, marker)
		x += 0.55
	var label := Label3D.new()
	label.text = str(level)
	label.font_size = 64
	label.pixel_size = 0.011
	label.outline_size = 14
	label.outline_modulate = Color.BLACK
	label.modulate = GAUGE_COLOR
	label.position = Vector3(-columns / 2.0 - LEFT_MARGIN * 0.6, 0.45, 0.5)
	marker.add_child(label)
	return marker


# --- Scene building ---------------------------------------------------------

## Eases the backdrop and sky towards the current world's greybox tint.
## A negative delta snaps straight to it.
func _tint_world(delta: float) -> void:
	var tint := game.generator.curve.world_tint(game.level)
	var blend := 1.0 if delta < 0.0 else 1.0 - exp(-3.0 * delta)
	_backdrop_material.albedo_color = _backdrop_material.albedo_color.lerp(tint, blend)
	var sky := tint.darkened(0.6)
	_environment.background_color = _environment.background_color.lerp(sky, blend)


func _build_room() -> void:
	var columns := float(game.board.columns)
	var rows := float(game.board.rows)
	var wall := _flat_material(Color(0.32, 0.34, 0.33))

	_backdrop_material = _flat_material(Color(0.12, 0.13, 0.13))
	_add_box(Vector3(columns, rows + 1.0, 0.1), Vector3(0.0, -rows / 2.0 + 0.5, -0.6), _backdrop_material)
	_add_box(Vector3(0.2, rows + 1.2, 1.0), Vector3(-columns / 2.0 - 0.1, -rows / 2.0 + 0.6, 0.0), wall)
	_add_box(Vector3(0.2, rows + 1.2, 1.0), Vector3(columns / 2.0 + 0.1, -rows / 2.0 + 0.6, 0.0), wall)
	_add_box(Vector3(columns + 0.4, 0.2, 1.0), Vector3(0.0, -rows - 0.1, 0.0), wall)

	# The level gauge: a rail down the left with a small tick per row.
	var gauge := _flat_material(Color(0.3, 0.33, 0.32))
	var gauge_x := -columns / 2.0 - LEFT_MARGIN * 0.35
	_add_box(Vector3(0.08, rows, 0.05), Vector3(gauge_x, -rows / 2.0, 0.3), gauge)
	for row in range(1, int(rows)):
		_add_box(Vector3(0.25, 0.04, 0.05), Vector3(gauge_x - 0.12, -row, 0.3), gauge)

	# Row 0 is the danger row: tint it, and draw the line bricks must not cross.
	_add_box(Vector3(columns, 1.0, 0.02), Vector3(0.0, -0.5, -0.54), _flat_material(Color(0.25, 0.08, 0.07)))
	_danger_material = _flat_material(DANGER_COLOR)
	_add_box(Vector3(columns, 0.08, 0.05), Vector3(0.0, -1.0, 0.5), _danger_material)
	_add_box(Vector3(columns, 0.06, 0.04), Vector3(0.0, 0.0, 0.5), _flat_material(Color(0.6, 0.6, 0.55)))

	_launcher = Node3D.new()
	_board_root.add_child(_launcher)
	var hatch := MeshInstance3D.new()
	var hatch_mesh := BoxMesh.new()
	hatch_mesh.size = Vector3(0.9, 0.25, 0.1)
	hatch.mesh = hatch_mesh
	hatch.material_override = _flat_material(Color(0.2, 0.22, 0.24))
	hatch.position.y = 0.125
	_launcher.add_child(hatch)
	_make_sphere(_ball_mesh, _ball_material, _launcher)
	_ball_count = Label3D.new()
	_ball_count.position = Vector3(0.0, 0.75, 0.3)
	_ball_count.font_size = 64
	_ball_count.pixel_size = 0.012
	_ball_count.outline_size = 18
	_ball_count.outline_modulate = Color.BLACK
	_launcher.add_child(_ball_count)

	var dot_mesh := SphereMesh.new()
	dot_mesh.radius = 0.07
	dot_mesh.height = 0.14
	var dot_material := _flat_material(Color(1.0, 1.0, 0.85))
	for i in AIM_DOT_COUNT:
		var dot := _make_sphere(dot_mesh, dot_material)
		dot.hide()
		_aim_dots.append(dot)
	var ghost_material := _flat_material(Color(1.0, 1.0, 0.85, 0.35))
	ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_ball = _make_sphere(_ball_mesh, ghost_material)
	_ghost_ball.hide()


func _frame_camera() -> void:
	if game == null:
		return
	# Flat, straight-on orthographic view sized to fit the board's width.
	var size := get_viewport().get_visible_rect().size
	var width := game.board.columns + LEFT_MARGIN + RIGHT_MARGIN
	var units_per_px := width / size.x
	var visible_height := size.y * units_per_px
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_camera.size = width
	_camera.position = Vector3((RIGHT_MARGIN - LEFT_MARGIN) / 2.0, TOP_MARGIN_PX * units_per_px - visible_height / 2.0, 20.0)


func _to_world(x: float, y: float) -> Vector3:
	return Vector3(x - game.board.columns / 2.0, -y, 0.0)


func _add_box(size: Vector3, at: Vector3, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = at
	(parent if parent else _board_root).add_child(mesh)
	return mesh


func _make_sphere(mesh: Mesh, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var sphere := MeshInstance3D.new()
	sphere.mesh = mesh
	sphere.material_override = material
	(parent if parent else _board_root).add_child(sphere)
	return sphere


static func _flat_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material
