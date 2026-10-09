extends GutTest
## The turn loop: level clears, rises, losing, continues, and determinism.

## Column straight under the launcher at the start of a run.
const MID := Board.COLUMNS / 2
const AIMS := [[0.3, 1.0], [-0.7, 0.5], [0.05, 1.0], [0.9, 0.3], [-0.2, 1.0]]


func _controller(board: Board, balls := 1) -> TurnController:
	return TurnController.new(board, null, balls)


## A hand-built level: one brick above the line at `line_row`, one below it.
func _one_brick_level(hp: int) -> TurnController:
	var board := Board.new()
	board.add_brick(Brick.new(Brick.Type.STONE, hp, MID, 6))
	board.add_brick(Brick.new(Brick.Type.STONE, 99, 0, 15))
	var game := _controller(board)
	game.level_line_row = 10
	return game


func test_new_run_puts_level_top_at_start_row() -> void:
	var game := TurnController.create(1)
	assert_eq(game.board.topmost_brick_row(), TurnController.START_ROW)
	assert_eq(game.level_line_row, TurnController.START_ROW + TurnController.LEVEL_ROWS)
	assert_gt(game.board.bricks_above(game.level_line_row), 0)
	assert_eq(game.rows_cleared(), 0)


func test_next_level_waits_below_the_floor() -> void:
	var game := TurnController.create(1)
	var below := 0
	for brick in game.board.bricks:
		if brick.row >= game.board.rows:
			below += 1
	assert_gt(below, 0)


func test_clearing_every_brick_above_the_line_clears_the_level() -> void:
	var game := _one_brick_level(1)
	game.play_turn(0.0, 1.0)
	assert_eq(game.level, 2)
	assert_eq(game.levels_cleared, 1)
	assert_true(game.just_cleared)


func test_level_clear_scrolls_next_level_to_start_row() -> void:
	var game := _one_brick_level(1)
	var next := game.board.bricks[1]
	game.play_turn(0.0, 1.0)
	assert_eq(next.row, 15 + TurnController.START_ROW - 10, "scrolled by start row - old line")
	assert_eq(game.level_line_row, TurnController.START_ROW + TurnController.LEVEL_ROWS)


func test_level_clear_replaces_the_rise() -> void:
	var board := Board.new()
	board.add_brick(Brick.new(Brick.Type.STONE, 1, MID, 6))
	var game := _controller(board)
	game.level_line_row = TurnController.START_ROW + TurnController.LEVEL_ROWS
	var below := board.add_brick(Brick.new(Brick.Type.STONE, 99, 0, game.level_line_row))
	game.play_turn(0.0, 1.0)
	assert_eq(below.row, game.level_line_row - TurnController.LEVEL_ROWS, "line didn't move, so no rise")


func test_rise_when_level_not_cleared() -> void:
	var game := _one_brick_level(50)
	var brick := game.board.bricks[0]
	game.play_turn(0.6, 1.0)
	assert_eq(game.level, 1)
	assert_eq(brick.row, 5)
	assert_eq(game.level_line_row, 9, "the line rises with the bricks")
	assert_eq(game.turn, 2)


func test_level_clear_awards_bonus_points() -> void:
	var game := _one_brick_level(1)
	game.play_turn(0.0, 1.0)
	assert_eq(game.points, 1 + Economy.level_bonus(1))


func test_points_count_damage() -> void:
	var game := _one_brick_level(50)
	game.ball_count = 3
	game.play_turn(0.0, 1.0)
	assert_eq(game.points, 50 - game.board.bricks[0].hp)


func test_rows_cleared_counts_from_level_top() -> void:
	var board := Board.new()
	board.add_brick(Brick.new(Brick.Type.STONE, 5, 2, 14))
	var game := _controller(board)
	game.level_line_row = 20
	assert_eq(game.rows_cleared(), 4)


func test_lose_when_brick_reaches_danger_line() -> void:
	var board := Board.new()
	board.add_brick(Brick.new(Brick.Type.STONE, 999, 0, 1))
	var game := _controller(board)
	game.level_line_row = 12
	assert_eq(game.rows_until_trapped(), 1)
	assert_eq(game.play_turn(0.0, 1.0), TurnController.Phase.LOST)


func test_continue_once_clears_top_rows() -> void:
	var board := Board.new()
	for row in [1, 2, 3, 6]:
		board.add_brick(Brick.new(Brick.Type.STONE, 999, 0, row))
	var game := _controller(board)
	game.level_line_row = 12
	game.play_turn(0.0, 1.0)
	assert_eq(game.phase, TurnController.Phase.LOST)
	assert_true(game.continue_run())
	assert_eq(game.phase, TurnController.Phase.AIM)
	assert_eq(board.topmost_brick_row(), 5)
	game.board.add_brick(Brick.new(Brick.Type.STONE, 999, 1, 1))
	game.play_turn(0.0, 1.0)
	assert_false(game.continue_run(), "only one continue per run")


func test_first_ball_back_sets_next_launch() -> void:
	var game := _controller(Board.new())
	game.play_turn(0.5, 1.0)
	assert_ne(game.launch_x, game.board.columns / 2.0)
	assert_between(game.launch_x, BallSim.RADIUS, game.board.columns - BallSim.RADIUS)


func test_pickup_adds_ball_next_turn() -> void:
	var board := Board.new()
	board.add_pickup(Pickup.new(Pickup.Type.EXTRA_BALL, MID, 4))
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
	var game := TurnController.create(1)
	var balls := game.ball_count
	game.fire(0.2, 1.0)
	for i in 10:
		game.step()
	game.recall()
	assert_eq(game.phase, TurnController.Phase.AIM)
	assert_gte(game.ball_count, balls)
	assert_eq(game.turn, 2)


func test_starting_deeper_uses_that_levels_bricks_and_balls() -> void:
	var shallow := TurnController.create(1, 1)
	var deep := TurnController.create(1, 5)
	assert_eq(deep.level, 5)
	assert_eq(deep.ball_count, Economy.start_balls(5))
	assert_gt(deep.board.bricks[0].hp, shallow.board.bricks[0].hp)


func _play(game: TurnController, aims: Array) -> PackedStringArray:
	var states := PackedStringArray()
	for aim in aims:
		game.play_turn(aim[0], aim[1])
		states.append(game.snapshot())
	return states


func test_determinism_same_seed_same_aim_same_result() -> void:
	var a := _play(TurnController.create(1998), AIMS)
	var b := _play(TurnController.create(1998), AIMS)
	assert_eq(a, b)


func test_different_seed_builds_different_levels() -> void:
	assert_ne(TurnController.create(1).snapshot(), TurnController.create(2).snapshot())


func test_clone_plays_out_identically() -> void:
	var game := TurnController.create(1998)
	game.play_turn(0.4, 1.0)
	var copy := game.clone()
	assert_eq(_play(game, AIMS), _play(copy, AIMS))
