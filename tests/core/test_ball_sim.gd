extends GutTest
## Ball reflection and damage in the deterministic volley sim.

const EPSILON := 1e-9


func _sim(board: Board) -> BallSim:
	return BallSim.new(board, 3.5, 0.0, 1.0, 0)


func _step_until(sim: BallSim, done: Callable, max_ticks := 600) -> void:
	for i in max_ticks:
		if done.call():
			return
		sim.step()


func test_reflects_off_left_wall() -> void:
	var sim := _sim(Board.new())
	var ball := sim.add_ball(0.5, 5.0, -0.8, 0.6)
	_step_until(sim, func(): return ball.dx > 0.0)
	assert_almost_eq(ball.dx, 0.8, EPSILON)
	assert_almost_eq(ball.dy, 0.6, EPSILON)


func test_reflects_off_right_wall() -> void:
	var board := Board.new()
	var sim := _sim(board)
	var ball := sim.add_ball(board.columns - 0.5, 5.0, 0.6, 0.8)
	_step_until(sim, func(): return ball.dx < 0.0)
	assert_almost_eq(ball.dx, -0.6, EPSILON)
	assert_almost_eq(ball.dy, 0.8, EPSILON)


func test_reflects_off_floor() -> void:
	var board := Board.new()
	var sim := _sim(board)
	var ball := sim.add_ball(3.5, board.rows - 0.5, 0.0, 1.0)
	_step_until(sim, func(): return ball.dy < 0.0)
	assert_almost_eq(ball.dy, -1.0, EPSILON)


func test_reflects_off_brick_top_and_damages_it() -> void:
	var board := Board.new()
	var brick := board.add_brick(Brick.new(Brick.Type.STONE, 5, 3, 6))
	var sim := _sim(board)
	var ball := sim.add_ball(3.5, 5.0, 0.0, 1.0)
	_step_until(sim, func(): return ball.dy < 0.0)
	assert_almost_eq(ball.dy, -1.0, EPSILON, "bounced straight back up")
	assert_lt(ball.y, 6.0, "never got inside the brick")
	assert_eq(brick.hp, 4, "took 1 damage")


func test_reflects_off_brick_side() -> void:
	var board := Board.new()
	board.add_brick(Brick.new(Brick.Type.STONE, 5, 4, 5))
	var sim := _sim(board)
	var ball := sim.add_ball(3.0, 5.1, 0.8, 0.6)
	_step_until(sim, func(): return ball.dx < 0.0)
	assert_almost_eq(ball.dx, -0.8, EPSILON)
	assert_almost_eq(ball.dy, 0.6, EPSILON)


func test_seam_between_two_bricks_bounces_once() -> void:
	var board := Board.new()
	var left := board.add_brick(Brick.new(Brick.Type.STONE, 5, 2, 6))
	var right := board.add_brick(Brick.new(Brick.Type.STONE, 5, 3, 6))
	var sim := _sim(board)
	var ball := sim.add_ball(3.0, 5.0, 0.0, 1.0)
	_step_until(sim, func(): return ball.dy < 0.0)
	assert_almost_eq(ball.dx, 0.0, EPSILON, "flat surface, no sideways kick")
	assert_almost_eq(ball.dy, -1.0, EPSILON)
	assert_eq(left.hp + right.hp, 8, "both bricks hit once")


func test_wide_lock_is_hit_once_per_bounce() -> void:
	var board := Board.new()
	var lock := board.add_brick(Lock.new(10, 2, 6, 2))
	var sim := _sim(board)
	var ball := sim.add_ball(3.0, 5.0, 0.0, 1.0)
	_step_until(sim, func(): return ball.dy < 0.0)
	assert_eq(lock.hp, 9)


func test_speed_stays_constant_after_many_bounces() -> void:
	var board := TestLevel.create().board
	var sim := BallSim.new(board, 3.5, 0.31, 0.9, 1)
	for i in 400:
		sim.step()
	var ball := sim.balls[0]
	assert_almost_eq(sqrt(ball.dx * ball.dx + ball.dy * ball.dy), 1.0, 1e-9)


func test_shallow_bounce_is_steepened() -> void:
	var sim := _sim(Board.new())
	var ball := sim.add_ball(0.5, 5.0, -1.0, 0.01)
	_step_until(sim, func(): return ball.dx > 0.0)
	assert_almost_eq(absf(ball.dy), BallSim.MIN_DY, EPSILON)


func test_ball_returns_through_top_line() -> void:
	var sim := _sim(Board.new())
	var ball := sim.add_ball(2.25, 1.0, 0.0, -1.0)
	_step_until(sim, func(): return not ball.active)
	assert_false(ball.active)
	assert_eq(sim.returned, 1)
	assert_almost_eq(sim.first_return_x, 2.25, EPSILON)


func test_volley_launches_every_ball_then_finishes() -> void:
	var board := Board.new()
	var sim := BallSim.new(board, 3.5, 0.3, 1.0, 5)
	_step_until(sim, func(): return sim.is_finished(), BallSim.MAX_TICKS)
	assert_eq(sim.balls.size(), 5)
	assert_eq(sim.returned, 5)


func test_ball_collects_pickup() -> void:
	var board := Board.new()
	board.add_pickup(Pickup.new(Pickup.Type.EXTRA_BALL, 3, 4))
	var sim := BallSim.new(board, 3.5, 0.0, 1.0, 1)
	_step_until(sim, func(): return sim.is_finished(), BallSim.MAX_TICKS)
	assert_eq(sim.balls_gained, 1)
	assert_eq(board.pickups.size(), 0)


func test_recall_stops_volley() -> void:
	var sim := BallSim.new(TestLevel.create().board, 3.5, 0.2, 1.0, 10)
	for i in 30:
		sim.step()
	sim.recall()
	assert_true(sim.is_finished())


func test_aim_trace_stops_at_first_bounce_plus_tail() -> void:
	var board := Board.new()
	board.add_brick(Brick.new(Brick.Type.STONE, 5, 3, 6))
	var points := BallSim.trace_aim(board, 3.5, 0.0, 1.0, 1, 1.0)
	assert_eq(points.size(), 3, "start, bounce, tail end")
	assert_almost_eq(points[1].y, 6.0 - BallSim.RADIUS, 0.01, "bounce on top of the brick")
	assert_almost_eq(points[2].y, points[1].y - 1.0, BallSim.STEP_LENGTH * 1.5, "tail goes back up")
	assert_eq(board.bricks[0].hp, 5, "tracing doesn't damage")
