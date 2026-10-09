extends GutTest
## The turn loop: win, lose, rise/spawn, and determinism.


func _controller(board: Board, balls := 1) -> TurnController:
	return TurnController.new(board, RowGenerator.new(7), balls)


func test_win_when_lock_reaches_zero() -> void:
	var board := Board.new()
	board.add_brick(Lock.new(1, 3, 5))
	var game := _controller(board)
	assert_eq(game.play_turn(0.0, 1.0), TurnController.Phase.WON)
	assert_eq(game.lock_hp(), 0)


func test_win_ends_volley_immediately() -> void:
	var board := Board.new()
	board.add_brick(Lock.new(1, 3, 5))
	var game := _controller(board, 20)
	game.play_turn(0.0, 1.0)
	assert_lt(game.turn, 2, "no rise after the lock breaks")


func test_lose_when_brick_reaches_danger_line() -> void:
	var board := Board.new()
	board.add_brick(Brick.new(Brick.Type.STONE, 999, 0, 1))
	board.add_brick(Lock.new(50, 3, 8))
	var game := _controller(board)
	assert_eq(game.rows_until_trapped(), 1)
	assert_eq(game.play_turn(0.0, 1.0), TurnController.Phase.LOST)


func test_rise_step_moves_bricks_and_spawns_bottom_row() -> void:
	var board := Board.new()
	var brick := board.add_brick(Brick.new(Brick.Type.STONE, 999, 0, 6))
	board.add_brick(Lock.new(50, 5, 9))
	var game := _controller(board)
	assert_eq(game.play_turn(0.6, 1.0), TurnController.Phase.AIM)
	assert_eq(brick.row, 5)
	assert_eq(game.turn, 2)
	var bottom := 0
	for b in board.bricks:
		if b.row == board.rows - 1:
			bottom += 1
	assert_between(bottom, 1, board.columns - 1, "new row with at least one gap")


func test_first_ball_back_sets_next_launch() -> void:
	var game := _controller(Board.new())
	game.play_turn(0.5, 1.0)
	assert_ne(game.launch_x, 3.5)
	assert_between(game.launch_x, BallSim.RADIUS, 7.0 - BallSim.RADIUS)


func test_pickup_adds_ball_next_turn() -> void:
	var board := Board.new()
	board.add_pickup(Pickup.new(Pickup.Type.EXTRA_BALL, 3, 4))
	var game := _controller(board, 3)
	game.play_turn(0.0, 1.0)
	assert_eq(game.ball_count, 4)


func test_cannot_fire_upwards() -> void:
	var game := _controller(Board.new())
	assert_false(game.fire(0.3, -1.0))
	assert_eq(game.phase, TurnController.Phase.AIM)


func test_shallow_aim_is_clamped() -> void:
	var aim := TurnController.clamp_aim(-1.0, 0.001)
	assert_almost_eq(aim[1], TurnController.MIN_AIM_DY, 1e-12)
	assert_lt(aim[0], 0.0)


func test_recall_ends_turn_and_keeps_balls() -> void:
	var game := TestLevel.create()
	var balls := game.ball_count
	game.fire(0.2, 1.0)
	for i in 10:
		game.step()
	game.recall()
	assert_eq(game.phase, TurnController.Phase.AIM)
	assert_gte(game.ball_count, balls)
	assert_eq(game.turn, 2)


func _play(game: TurnController, aims: Array) -> PackedStringArray:
	var states := PackedStringArray()
	for aim in aims:
		game.play_turn(aim[0], aim[1])
		states.append(game.snapshot())
	return states


const AIMS := [[0.3, 1.0], [-0.7, 0.5], [0.05, 1.0], [0.9, 0.3], [-0.2, 1.0]]


func test_determinism_same_seed_same_aim_same_result() -> void:
	var a := _play(TestLevel.create(), AIMS)
	var b := _play(TestLevel.create(), AIMS)
	assert_eq(a, b)


func test_different_seed_spawns_different_rows() -> void:
	var a := _play(TestLevel.create(1), AIMS)
	var b := _play(TestLevel.create(2), AIMS)
	assert_ne(a[-1], b[-1])


func test_clone_plays_out_identically() -> void:
	var game := TestLevel.create()
	game.play_turn(0.4, 1.0)
	var copy := game.clone()
	assert_eq(_play(game, AIMS), _play(copy, AIMS))


func test_test_level_has_buried_lock() -> void:
	var game := TestLevel.create()
	var lock := game.board.lock
	assert_not_null(lock)
	assert_gt(lock.row, game.board.topmost_brick_row(), "lock is below the top of the pile")
	assert_eq(game.phase, TurnController.Phase.AIM)
