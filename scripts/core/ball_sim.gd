class_name BallSim
extends RefCounted
## Deterministic fixed-timestep simulation of one volley.
##
## No physics engine and no nodes: positions are plain 64-bit floats and the
## only maths used is + - * / and sqrt, which IEEE 754 makes exact. The same
## board and aim always give the same result, so the solver bot can replay it.
##
## Balls are launched from (launch_x, 0) on the top line, bounce off the side
## walls, the floor and bricks, and return when they cross back over the top line.

const TICK_RATE := 120
const TICK := 1.0 / TICK_RATE
const SUBSTEPS := 2
const SPEED := 12.0 ## board units per second
const STEP_LENGTH := SPEED / TICK_RATE / SUBSTEPS
const RADIUS := 0.12
const PICKUP_RADIUS := 0.3
const LAUNCH_INTERVAL_TICKS := 6
## Smallest |dy| after a bounce. Stops balls skimming sideways forever.
const MIN_DY := 0.12
const RECALL_AFTER_TICKS := TICK_RATE * 3
## Hard stop for headless runs: the volley recalls itself after this long.
const MAX_TICKS := TICK_RATE * 60


class Ball:
	var x := 0.0
	var y := 0.0
	var dx := 0.0 ## unit direction
	var dy := 0.0
	var active := true


var board: Board
var damage := 1
var launch_x := 0.0
var aim_dx := 0.0
var aim_dy := 1.0
var balls: Array[Ball] = []
var to_launch := 0
var tick := 0
var returned := 0
var first_return_x := 0.0
var balls_gained := 0
var hits := 0
var lock_broken := false


func _init(p_board: Board, p_launch_x: float, p_dx: float, p_dy: float, p_count: int, p_damage := 1) -> void:
	board = p_board
	launch_x = p_launch_x
	first_return_x = p_launch_x
	var length := sqrt(p_dx * p_dx + p_dy * p_dy)
	aim_dx = p_dx / length
	aim_dy = p_dy / length
	to_launch = p_count
	damage = p_damage


## Adds a ball directly. Used by tests to set up a single bounce.
func add_ball(x: float, y: float, dx: float, dy: float) -> Ball:
	var ball := Ball.new()
	var length := sqrt(dx * dx + dy * dy)
	ball.x = x
	ball.y = y
	ball.dx = dx / length
	ball.dy = dy / length
	balls.append(ball)
	return ball


func active_count() -> int:
	var count := 0
	for ball in balls:
		if ball.active:
			count += 1
	return count


func is_finished() -> bool:
	return lock_broken or (to_launch == 0 and active_count() == 0)


func can_recall() -> bool:
	return tick >= RECALL_AFTER_TICKS and not is_finished()


## Ends the volley now. Balls still in flight or waiting to launch are kept for
## next turn; they just don't do any more damage.
func recall() -> void:
	to_launch = 0
	for ball in balls:
		ball.active = false


func step() -> void:
	if is_finished():
		return
	if to_launch > 0 and tick % LAUNCH_INTERVAL_TICKS == 0:
		add_ball(launch_x, 0.0, aim_dx, aim_dy)
		to_launch -= 1
	for ball in balls:
		if not ball.active:
			continue
		for i in SUBSTEPS:
			_move(ball, false)
			if not ball.active or lock_broken:
				break
		if lock_broken:
			break
	tick += 1
	if tick >= MAX_TICKS:
		recall()


## Moves one ball one substep. Returns true if it bounced off something.
## A ghost ball (aim preview) bounces but never damages or collects anything.
func _move(ball: Ball, ghost: bool) -> bool:
	ball.x += ball.dx * STEP_LENGTH
	ball.y += ball.dy * STEP_LENGTH

	if ball.y < 0.0 and ball.dy < 0.0:
		ball.active = false
		if not ghost:
			if returned == 0:
				first_return_x = clampf(ball.x, RADIUS, board.columns - RADIUS)
			returned += 1
		return false

	var nx := 0.0
	var ny := 0.0
	var right_wall := float(board.columns) - RADIUS
	var floor_y := float(board.rows) - RADIUS
	if ball.x < RADIUS:
		ball.x = RADIUS
		nx += 1.0
	elif ball.x > right_wall:
		ball.x = right_wall
		nx -= 1.0
	if ball.y > floor_y:
		ball.y = floor_y
		ny -= 1.0

	# Find every brick the ball overlaps before moving it, so a ball landing on
	# the seam between two bricks hits both and bounces once off the flat top.
	var touched: Array[Brick] = []
	var push_x := 0.0
	var push_y := 0.0
	for row in range(floori(ball.y - RADIUS), floori(ball.y + RADIUS) + 1):
		for col in range(floori(ball.x - RADIUS), floori(ball.x + RADIUS) + 1):
			var brick := board.brick_at(col, row)
			if brick == null or touched.has(brick):
				continue
			var contact := _contact(ball, brick)
			if contact.is_empty():
				continue
			nx += contact[0]
			ny += contact[1]
			if absf(contact[2]) > absf(push_x):
				push_x = contact[2]
			if absf(contact[3]) > absf(push_y):
				push_y = contact[3]
			touched.append(brick)
	ball.x += push_x
	ball.y += push_y

	var bounced := false
	if nx != 0.0 or ny != 0.0:
		var n_length := sqrt(nx * nx + ny * ny)
		nx /= n_length
		ny /= n_length
		var dot := ball.dx * nx + ball.dy * ny
		if dot < 0.0:
			ball.dx -= 2.0 * dot * nx
			ball.dy -= 2.0 * dot * ny
			_keep_vertical(ball)
			bounced = true
			if not ghost:
				for brick in touched:
					hits += 1
					board.damage_brick(brick, damage)
					if brick.is_lock() and brick.is_destroyed():
						lock_broken = true

	if not ghost:
		_collect_pickups(ball)
	return bounced


## If the ball overlaps the brick, returns [nx, ny, push_x, push_y]: the
## surface normal and the move that would separate them. Empty if they don't touch.
func _contact(ball: Ball, brick: Brick) -> PackedFloat64Array:
	var left := float(brick.col)
	var right := float(brick.col + brick.width)
	var top := float(brick.row)
	var bottom := float(brick.row + 1)
	var dx := ball.x - clampf(ball.x, left, right)
	var dy := ball.y - clampf(ball.y, top, bottom)
	var dist_sq := dx * dx + dy * dy
	if dist_sq >= RADIUS * RADIUS:
		return PackedFloat64Array()

	var nx := 0.0
	var ny := 0.0
	var depth := 0.0
	if dist_sq > 0.0:
		var dist := sqrt(dist_sq)
		nx = dx / dist
		ny = dy / dist
		depth = RADIUS - dist
	else:
		# Centre is inside the brick: leave by the nearest side.
		var to_top := ball.y - top
		var to_bottom := bottom - ball.y
		var to_left := ball.x - left
		var to_right := right - ball.x
		var nearest := minf(minf(to_top, to_bottom), minf(to_left, to_right))
		if nearest == to_top:
			ny = -1.0
		elif nearest == to_bottom:
			ny = 1.0
		elif nearest == to_left:
			nx = -1.0
		else:
			nx = 1.0
		depth = nearest + RADIUS
	return PackedFloat64Array([nx, ny, nx * depth, ny * depth])


func _keep_vertical(ball: Ball) -> void:
	if absf(ball.dy) >= MIN_DY:
		return
	ball.dy = MIN_DY if ball.dy > 0.0 else -MIN_DY
	var side := 1.0 if ball.dx >= 0.0 else -1.0
	ball.dx = side * sqrt(1.0 - MIN_DY * MIN_DY)


func _collect_pickups(ball: Ball) -> void:
	var reach := RADIUS + PICKUP_RADIUS
	for pickup: Pickup in board.pickups.duplicate():
		var dx := ball.x - (pickup.col + 0.5)
		var dy := ball.y - (pickup.row + 0.5)
		if dx * dx + dy * dy < reach * reach:
			board.remove_pickup(pickup)
			if pickup.type == Pickup.Type.EXTRA_BALL:
				balls_gained += 1


## Traces the aim guide: where a ball fired this way goes, up to `bounces`
## bounces plus a short tail. Returns board-space points, starting at the launcher.
static func trace_aim(p_board: Board, p_launch_x: float, dx: float, dy: float, bounces := 1, tail := 1.2) -> PackedVector2Array:
	var sim := BallSim.new(p_board, p_launch_x, dx, dy, 0)
	var ball := sim.add_ball(p_launch_x, 0.0, dx, dy)
	var points := PackedVector2Array([Vector2(p_launch_x, 0.0)])
	var bounced := 0
	var tail_left := tail
	for i in 4000:
		var hit := sim._move(ball, true)
		if not ball.active:
			break
		if bounced < bounces:
			if hit:
				bounced += 1
				points.append(Vector2(ball.x, ball.y))
		else:
			tail_left -= STEP_LENGTH
			if hit or tail_left <= 0.0:
				break
	points.append(Vector2(ball.x, ball.y))
	return points
