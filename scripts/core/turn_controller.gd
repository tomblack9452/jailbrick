class_name TurnController
extends RefCounted
## One run of the dig: aim -> fire -> return -> clear or rise -> check.
##
## The dig is split into levels of LevelGenerator.LEVEL_ROWS rows. A level is
## cleared when no bricks are left above its bottom line. The board then
## scrolls so the next level's top sits back at START_ROW. If the level isn't
## cleared, everything rises one row as usual. A brick reaching the danger
## row ends the run.
##
## Drive it with fire() then step() once per BallSim.TICK (the view does this
## each frame), or call play_turn() to run a whole volley at once (tests, bots).

enum Phase { AIM, VOLLEY, LOST }

## Aim must point at least this far down (as the y part of a unit vector, ~7 degrees).
const MIN_AIM_DY := 0.12
const LEVEL_ROWS := LevelGenerator.LEVEL_ROWS
## Where each level's top row sits when it starts.
const START_ROW := 9
## Rows cleared off the top of the pile by a continue.
const CONTINUE_CLEARS := 3

var board: Board
var generator: LevelGenerator
var phase := Phase.AIM
var turn := 1
var ball_count := 1
var launch_x := 0.0
var damage := 1
var rise_rate := 1
var volley: BallSim = null

var start_level := 1
var level := 1
var levels_cleared := 0
var points := 0
var continued := false
## Board row of the current level's bottom line. Moves as the board scrolls.
var level_line_row := 0
## True for the turn right after a level was cleared (for the view's banner).
var just_cleared := false

var _next_chunk_row := 0
var _next_chunk_level := 1


func _init(p_board: Board, p_generator: LevelGenerator = null, p_ball_count := 1) -> void:
	board = p_board
	generator = p_generator
	ball_count = p_ball_count
	launch_x = board.columns / 2.0
	level_line_row = board.rows


## A fresh run starting at `p_level` with that level's top at START_ROW.
## Uses levels/depth_curve.tres unless another curve is passed in.
static func create(seed: int, p_level := 1, curve: DepthCurve = null) -> TurnController:
	if curve == null:
		curve = DepthCurve.load_default()
	var game := TurnController.new(Board.new(), LevelGenerator.new(seed, curve), Economy.start_balls(p_level))
	game.start_level = p_level
	game.level = p_level
	game.level_line_row = START_ROW + LEVEL_ROWS
	game._next_chunk_row = START_ROW
	game._next_chunk_level = p_level
	game._fill_chunks()
	return game


## Turns a raw aim (towards the cursor) into a unit direction that points
## down at a legal angle. Returns [] if the aim points up or nowhere.
static func clamp_aim(dx: float, dy: float) -> PackedFloat64Array:
	var length := sqrt(dx * dx + dy * dy)
	if length == 0.0 or dy <= 0.0:
		return PackedFloat64Array()
	dx /= length
	dy /= length
	if dy < MIN_AIM_DY:
		dy = MIN_AIM_DY
		dx = (1.0 if dx >= 0.0 else -1.0) * sqrt(1.0 - MIN_AIM_DY * MIN_AIM_DY)
	return PackedFloat64Array([dx, dy])


## Starts a volley. Returns false if it's not the aim phase or the aim is invalid.
func fire(dx: float, dy: float) -> bool:
	if phase != Phase.AIM:
		return false
	var aim := clamp_aim(dx, dy)
	if aim.is_empty():
		return false
	volley = BallSim.new(board, launch_x, aim[0], aim[1], ball_count, damage)
	phase = Phase.VOLLEY
	return true


## Advances the volley by one fixed tick.
func step() -> void:
	if phase != Phase.VOLLEY:
		return
	volley.step()
	if volley.is_finished():
		_end_volley()


func recall() -> void:
	if phase != Phase.VOLLEY:
		return
	volley.recall()
	_end_volley()


## Fires and runs the whole volley. Returns the phase afterwards.
func play_turn(dx: float, dy: float) -> Phase:
	if not fire(dx, dy):
		return phase
	while phase == Phase.VOLLEY:
		step()
	return phase


## Once per run, after losing: clears the top rows of the pile and carries on.
## The view gates this behind a rewarded ad (stubbed until Phase 8).
func continue_run() -> bool:
	if phase != Phase.LOST or continued:
		return false
	continued = true
	board.clear_top_rows(CONTINUE_CLEARS)
	phase = Phase.AIM
	return true


## How many more rises until a brick reaches the danger row.
func rows_until_trapped() -> int:
	return ceili(float(board.topmost_brick_row() - Board.DANGER_ROW) / rise_rate)


## How many of the current level's rows are clear, counting from its top.
func rows_cleared() -> int:
	var level_top := level_line_row - LEVEL_ROWS
	var cleared := LEVEL_ROWS
	for brick in board.bricks:
		if brick.row < level_line_row:
			cleared = mini(cleared, brick.row - level_top)
	return clampi(cleared, 0, LEVEL_ROWS)


func coins_earned() -> int:
	return Economy.coins_for(points, levels_cleared)


func clone() -> TurnController:
	assert(phase != Phase.VOLLEY, "can't clone mid-volley")
	var copy := TurnController.new(board.clone(), generator.clone() if generator else null, ball_count)
	copy.phase = phase
	copy.turn = turn
	copy.launch_x = launch_x
	copy.damage = damage
	copy.rise_rate = rise_rate
	copy.start_level = start_level
	copy.level = level
	copy.levels_cleared = levels_cleared
	copy.points = points
	copy.continued = continued
	copy.level_line_row = level_line_row
	copy.just_cleared = just_cleared
	copy._next_chunk_row = _next_chunk_row
	copy._next_chunk_level = _next_chunk_level
	return copy


## A text fingerprint of the whole game state, for determinism checks.
func snapshot() -> String:
	var parts: PackedStringArray = [
		"turn=%d" % turn, "phase=%d" % phase, "balls=%d" % ball_count,
		"level=%d" % level, "line=%d" % level_line_row, "points=%d" % points,
		"launch_x=%s" % var_to_str(launch_x),
	]
	for brick in board.bricks:
		parts.append("b%d:%d,%d,%d" % [brick.id, brick.col, brick.row, brick.hp])
	for pickup in board.pickups:
		parts.append("p%d:%d,%d" % [pickup.id, pickup.col, pickup.row])
	return "|".join(parts)


func _end_volley() -> void:
	ball_count += volley.balls_gained
	points += volley.damage_dealt
	launch_x = volley.first_return_x
	volley = null
	just_cleared = board.bricks_above(level_line_row) == 0
	if just_cleared:
		levels_cleared += 1
		points += Economy.level_bonus(level)
		level += 1
		# Scroll the next level's top back to the start row.
		_shift(START_ROW - level_line_row)
		level_line_row = START_ROW + LEVEL_ROWS
	else:
		for i in rise_rate:
			_shift(-1)
	turn += 1
	phase = Phase.LOST if board.is_trapped() else Phase.AIM


func _shift(delta: int) -> void:
	ball_count += board.shift(delta).size()
	level_line_row += delta
	_next_chunk_row += delta
	_fill_chunks()


## Keeps one level generated below the floor so rises always have bricks to reveal.
func _fill_chunks() -> void:
	if generator == null:
		return
	while _next_chunk_row < board.rows + LEVEL_ROWS:
		var chunk := generator.generate_level(_next_chunk_level, board.columns)
		for i in chunk.size():
			var row := _next_chunk_row + i
			for entry in chunk[i]["bricks"]:
				board.add_brick(Brick.new(Brick.Type.STONE, entry[1], entry[0], row))
			if chunk[i]["pickup"] >= 0:
				board.add_pickup(Pickup.new(Pickup.Type.EXTRA_BALL, chunk[i]["pickup"], row))
		_next_chunk_row += LEVEL_ROWS
		_next_chunk_level += 1
