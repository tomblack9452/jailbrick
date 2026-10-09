class_name TurnController
extends RefCounted
## The turn loop from B2: aim -> fire -> return -> rise -> check.
##
## Drive it with fire() then step() once per BallSim.TICK (the view does this
## each frame), or call play_turn() to run a whole volley at once (tests, solver).

enum Phase { AIM, VOLLEY, WON, LOST }

## Aim must point at least this far down (as the y part of a unit vector, ~7 degrees).
const MIN_AIM_DY := 0.12

var board: Board
var generator: RowGenerator
var phase := Phase.AIM
var turn := 1
var ball_count := 1
var launch_x := 0.0
var damage := 1
var rise_rate := 1
var volley: BallSim = null


func _init(p_board: Board, p_generator: RowGenerator, p_ball_count := 1) -> void:
	board = p_board
	generator = p_generator
	ball_count = p_ball_count
	launch_x = board.columns / 2.0


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
	if volley.lock_broken:
		phase = Phase.WON
	elif volley.is_finished():
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


## How many more rises until a brick reaches the danger row.
func rows_until_trapped() -> int:
	return ceili(float(board.topmost_brick_row() - Board.DANGER_ROW) / rise_rate)


func lock_hp() -> int:
	return board.lock.hp if board.lock != null else 0


func clone() -> TurnController:
	assert(phase != Phase.VOLLEY, "can't clone mid-volley")
	var copy := TurnController.new(board.clone(), generator.clone(), ball_count)
	copy.phase = phase
	copy.turn = turn
	copy.launch_x = launch_x
	copy.damage = damage
	copy.rise_rate = rise_rate
	return copy


## A text fingerprint of the whole game state, for determinism checks.
func snapshot() -> String:
	var parts: PackedStringArray = [
		"turn=%d" % turn, "phase=%d" % phase, "balls=%d" % ball_count,
		"launch_x=%s" % var_to_str(launch_x),
	]
	for brick in board.bricks:
		parts.append("b%d:%d,%d,%d" % [brick.id, brick.col, brick.row, brick.hp])
	for pickup in board.pickups:
		parts.append("p%d:%d,%d" % [pickup.id, pickup.col, pickup.row])
	return "|".join(parts)


func _end_volley() -> void:
	ball_count += volley.balls_gained
	launch_x = volley.first_return_x
	volley = null
	for i in rise_rate:
		ball_count += board.rise().size()
		_spawn_row()
	turn += 1
	phase = Phase.LOST if board.is_trapped() else Phase.AIM


func _spawn_row() -> void:
	var row := board.rows - 1
	var spawn := generator.generate(turn + 1, board.columns)
	for entry in spawn["bricks"]:
		board.add_brick(Brick.new(Brick.Type.STONE, entry[1], entry[0], row))
	if spawn["pickup"] >= 0:
		board.add_pickup(Pickup.new(Pickup.Type.EXTRA_BALL, spawn["pickup"], row))
