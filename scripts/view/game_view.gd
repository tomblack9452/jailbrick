extends Node3D
## Phase 1 greybox view. Draws a TurnController in 3D, turns mouse/touch drags
## into aim + fire, and steps the volley at the sim's fixed tick rate.
##
## Board space (x right, y down, one unit per cell) maps to world space as
## (x - columns / 2, -y, 0), so the launcher line sits at world y = 0.

## Board units of space above the launcher line, for the HUD.
const TOP_MARGIN := 2.3
const SIDE_MARGIN := 0.3
const CAMERA_TILT_DEG := 5.0
const MAX_TICKS_PER_FRAME := 48
const AIM_DOT_SPACING := 0.3
const AIM_DOT_COUNT := 80
## Ignore aims closer than this below the launcher line (board units).
const MIN_AIM_DEPTH := 0.35
## Long volleys speed themselves up after this many seconds.
const AUTO_FAST_AFTER := 5.0
const DANGER_COLOR := Color(0.9, 0.15, 0.12)

var game: TurnController

var _brick_views := {} # brick id -> BrickView
var _pickup_views := {} # pickup id -> PickupView
var _balls: Array[MeshInstance3D] = []
var _aim_dots: Array[MeshInstance3D] = []
var _ghost_ball: MeshInstance3D
var _launcher: Node3D
var _ball_count: Label3D
var _danger_material: StandardMaterial3D
var _ball_mesh := SphereMesh.new()
var _ball_material := _flat_material(Color(0.95, 0.95, 0.9), true)

var _aiming := false
var _aim := PackedFloat64Array()
var _tick_debt := 0.0
var _fast_forward_time := 0.0
var _speed := 1
var _result_shown := false

@onready var _camera: Camera3D = $Camera3D
@onready var _board_root: Node3D = $Board
@onready var _hud: Hud = $HUD


func _ready() -> void:
	$Sun.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	_ball_mesh.radius = BallSim.RADIUS
	_ball_mesh.height = BallSim.RADIUS * 2.0
	_hud.retry_pressed.connect(start_game)
	_hud.recall_pressed.connect(func() -> void: game.recall())
	get_viewport().size_changed.connect(_frame_camera)
	start_game()


func start_game() -> void:
	for child in _board_root.get_children():
		child.queue_free()
	_brick_views.clear()
	_pickup_views.clear()
	_balls.clear()
	_aim_dots.clear()
	_aiming = false
	_result_shown = false
	_hud.hide_result()

	game = TestLevel.create()
	_build_room()
	_frame_camera()
	_sync(true)


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
	_hud.refresh(game, can_recall, _speed)

	var ended := game.phase == TurnController.Phase.WON or game.phase == TurnController.Phase.LOST
	if ended and not _result_shown:
		_result_shown = true
		_hide_aim()
		_hud.show_result(game)

	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 150.0) if game.rows_until_trapped() <= 2 else 0.0
	_danger_material.albedo_color = DANGER_COLOR.lerp(Color(1.0, 0.75, 0.6), pulse)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			start_game()
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
	var alive := {}
	for brick in board.bricks:
		alive[brick.id] = true
		var target := _to_world(brick.col + brick.width / 2.0, brick.row + 0.5)
		var view: BrickView = _brick_views.get(brick.id)
		if view == null:
			view = BrickView.new()
			_board_root.add_child(view)
			# New rows start one row lower and slide up with everything else.
			view.setup(brick, target if instant else target + Vector3.DOWN)
			_brick_views[brick.id] = view
		view.target = target
		view.set_hp(brick.hp)
	for id in _brick_views.keys():
		if not alive.has(id):
			_brick_views[id].break_apart()
			_brick_views.erase(id)

	alive.clear()
	for pickup in board.pickups:
		alive[pickup.id] = true
		var target := _to_world(pickup.col + 0.5, pickup.row + 0.5)
		var view: PickupView = _pickup_views.get(pickup.id)
		if view == null:
			view = PickupView.new()
			_board_root.add_child(view)
			view.setup(target if instant else target + Vector3.DOWN)
			_pickup_views[pickup.id] = view
		view.target = target
	for id in _pickup_views.keys():
		if not alive.has(id):
			_pickup_views[id].collect()
			_pickup_views.erase(id)

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
	_ball_count.visible = waiting > 0 and game.phase != TurnController.Phase.WON


# --- Scene building ---------------------------------------------------------

func _build_room() -> void:
	var columns := float(game.board.columns)
	var rows := float(game.board.rows)
	var wall := _flat_material(Color(0.32, 0.34, 0.33))

	_add_box(Vector3(columns, rows + 1.0, 0.1), Vector3(0.0, -rows / 2.0 + 0.5, -0.6), _flat_material(Color(0.12, 0.13, 0.13)))
	_add_box(Vector3(0.2, rows + 1.2, 1.0), Vector3(-columns / 2.0 - 0.1, -rows / 2.0 + 0.6, 0.0), wall)
	_add_box(Vector3(0.2, rows + 1.2, 1.0), Vector3(columns / 2.0 + 0.1, -rows / 2.0 + 0.6, 0.0), wall)
	_add_box(Vector3(columns + 0.4, 0.2, 1.0), Vector3(0.0, -rows - 0.1, 0.0), wall)

	# Row 0 is the danger row: tint it, and draw the line bricks must not cross.
	_add_box(Vector3(columns, 1.0, 0.02), Vector3(0.0, -0.5, -0.54), _flat_material(Color(0.25, 0.08, 0.07), true))
	_danger_material = _flat_material(DANGER_COLOR, true)
	_add_box(Vector3(columns, 0.05, 0.05), Vector3(0.0, -1.0, 0.5), _danger_material)
	_add_box(Vector3(columns, 0.04, 0.04), Vector3(0.0, 0.0, 0.5), _flat_material(Color(0.6, 0.6, 0.55), true))

	_launcher = Node3D.new()
	_board_root.add_child(_launcher)
	var hatch := MeshInstance3D.new()
	var hatch_mesh := BoxMesh.new()
	hatch_mesh.size = Vector3(0.6, 0.2, 0.6)
	hatch.mesh = hatch_mesh
	hatch.material_override = _flat_material(Color(0.2, 0.22, 0.24))
	hatch.position.y = 0.1
	_launcher.add_child(hatch)
	_make_sphere(_ball_mesh, _ball_material, _launcher)
	_ball_count = Label3D.new()
	_ball_count.position = Vector3(0.0, 0.42, 0.3)
	_ball_count.font_size = 72
	_ball_count.pixel_size = 0.0045
	_ball_count.outline_size = 18
	_ball_count.outline_modulate = Color.BLACK
	_launcher.add_child(_ball_count)

	var dot_mesh := SphereMesh.new()
	dot_mesh.radius = 0.045
	dot_mesh.height = 0.09
	var dot_material := _flat_material(Color(1.0, 1.0, 0.85), true)
	for i in AIM_DOT_COUNT:
		var dot := _make_sphere(dot_mesh, dot_material)
		dot.hide()
		_aim_dots.append(dot)
	var ghost_material := _flat_material(Color(1.0, 1.0, 0.85, 0.35), true)
	ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_ball = _make_sphere(_ball_mesh, ghost_material)
	_ghost_ball.hide()


func _frame_camera() -> void:
	if game == null:
		return
	var size := get_viewport().get_visible_rect().size
	var width := game.board.columns + SIDE_MARGIN * 2.0
	var visible_height := width * size.y / size.x
	var distance := (width / 2.0) / tan(deg_to_rad(_camera.fov / 2.0))
	var centre_y := TOP_MARGIN - visible_height / 2.0
	var tilt := deg_to_rad(CAMERA_TILT_DEG)
	_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_camera.position = Vector3(0.0, centre_y + distance * tan(tilt), distance)
	_camera.rotation = Vector3(-tilt, 0.0, 0.0)


func _to_world(x: float, y: float) -> Vector3:
	return Vector3(x - game.board.columns / 2.0, -y, 0.0)


func _add_box(size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = at
	_board_root.add_child(mesh)
	return mesh


func _make_sphere(mesh: Mesh, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var sphere := MeshInstance3D.new()
	sphere.mesh = mesh
	sphere.material_override = material
	(parent if parent else _board_root).add_child(sphere)
	return sphere


static func _flat_material(color: Color, unshaded := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material
