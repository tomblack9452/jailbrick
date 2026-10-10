extends GutTest
## Pickups from B5: coin, splitter, laser bar and freeze, touched or auto-collected.

const MID := Board.COLUMNS / 2


func _controller(board: Board, balls := 1) -> TurnController:
	var game := TurnController.new(board, null, balls)
	game.level_line_row = 21
	return game


## A board with one pickup straight under the launcher.
func _board_with(type: Pickup.Type, data := 0, row := 4) -> Board:
	var board := Board.new()
	board.add_pickup(Pickup.new(type, MID, row, data))
	return board


func _ball_counted_volley(board: Board, balls: int) -> BallSim:
	var sim := BallSim.new(board, MID + 0.5, 0.0, 1.0, balls)
	while not sim.is_finished():
		sim.step()
	return sim


# --- Coin --------------------------------------------------------------------

func test_coin_adds_coins_to_the_run() -> void:
	var game := _controller(_board_with(Pickup.Type.COIN))
	game.play_turn(0.0, 1.0)
	assert_eq(game.pickup_coins, Pickup.COIN_VALUE)
	assert_eq(game.coins_earned(), Economy.coins_for(game.points, game.levels_cleared) + Pickup.COIN_VALUE)
	assert_eq(game.board.pickups.size(), 0)


# --- Splitter ----------------------------------------------------------------

func test_splitter_turns_one_ball_into_three() -> void:
	var sim := BallSim.new(_board_with(Pickup.Type.SPLITTER), MID + 0.5, 0.0, 1.0, 1)
	while sim.board.pickups.size() > 0:
		sim.step()
	sim.step()
	assert_eq(sim.balls.size(), 3)
	assert_eq(sim.active_count(), 3)
	var dxs: Array[float] = []
	for ball in sim.balls:
		dxs.append(ball.dx)
		assert_almost_eq(ball.dx * ball.dx + ball.dy * ball.dy, 1.0, 1e-12, "still a unit direction")
	dxs.sort()
	assert_almost_eq(dxs[0], -BallSim.SPLIT_SIN, 1e-12)
	assert_almost_eq(dxs[2], BallSim.SPLIT_SIN, 1e-12)


func test_split_balls_last_one_volley() -> void:
	var game := _controller(_board_with(Pickup.Type.SPLITTER), 2)
	game.play_turn(0.0, 1.0)
	assert_eq(game.ball_count, 2)


func test_splitter_only_splits_the_first_ball_through() -> void:
	var sim := _ball_counted_volley(_board_with(Pickup.Type.SPLITTER), 4)
	assert_eq(sim.balls.size(), 6)


# --- Laser bar ---------------------------------------------------------------

func test_horizontal_laser_hits_every_brick_in_its_row_once() -> void:
	var board := _board_with(Pickup.Type.LASER, Pickup.HORIZONTAL, 4)
	var left := board.add_brick(Brick.new(Brick.Type.STONE, 5, 0, 4))
	var wide := board.add_brick(Brick.new(Brick.Type.STONE, 5, 10, 4, 2))
	var other_row := board.add_brick(Brick.new(Brick.Type.STONE, 5, 0, 5))
	var game := _controller(board)
	game.play_turn(0.0, 1.0)
	assert_eq(left.hp, 4)
	assert_eq(wide.hp, 4, "a wide brick is hit once")
	assert_eq(other_row.hp, 5)
	assert_eq(game.points, 2)


func test_vertical_laser_hits_its_column() -> void:
	var board := _board_with(Pickup.Type.LASER, Pickup.VERTICAL, 4)
	var below := board.add_brick(Brick.new(Brick.Type.STONE, 5, MID, 18))
	var beside := board.add_brick(Brick.new(Brick.Type.STONE, 5, MID + 1, 18))
	board.fire_laser(MID, 4, true, 3)
	assert_eq(below.hp, 2)
	assert_eq(beside.hp, 5)
	assert_eq(board.effects.back()["kind"], "laser")


func test_laser_misses_bricks_below_the_floor() -> void:
	var board := Board.new()
	var hidden := board.add_brick(Brick.new(Brick.Type.STONE, 5, 3, board.rows + 1))
	board.fire_laser(3, 4, true, 1)
	assert_eq(hidden.hp, 5)


# --- Freeze ------------------------------------------------------------------

func test_freeze_skips_the_next_rise() -> void:
	var board := _board_with(Pickup.Type.FREEZE)
	var brick := board.add_brick(Brick.new(Brick.Type.STONE, 99, 0, 15))
	var game := _controller(board)
	game.play_turn(0.0, 1.0)
	assert_eq(brick.row, 15, "frozen")
	assert_eq(game.freezes, 0)
	game.play_turn(0.0, 1.0)
	assert_eq(brick.row, 14, "rising again")


func test_freezes_stack_and_count_in_trapped_in() -> void:
	var board := Board.new()
	board.add_brick(Brick.new(Brick.Type.STONE, 99, 0, 5))
	var game := _controller(board)
	assert_eq(game.rows_until_trapped(), 5)
	game.freezes = 2
	assert_eq(game.rows_until_trapped(), 7)


# --- Rising into the danger row ------------------------------------------------

func _auto_collect(type: Pickup.Type, data := 0) -> TurnController:
	var board := Board.new()
	board.add_pickup(Pickup.new(type, 2, 1, data))
	board.add_brick(Brick.new(Brick.Type.STONE, 99, 0, 15))
	var game := _controller(board)
	game.play_turn(0.6, 1.0) # misses column 2, then rises
	assert_eq(board.pickups.size(), 0, "collected by the rise")
	return game


func test_rising_coin_still_pays() -> void:
	assert_eq(_auto_collect(Pickup.Type.COIN).pickup_coins, Pickup.COIN_VALUE)


func test_rising_freeze_still_freezes() -> void:
	assert_eq(_auto_collect(Pickup.Type.FREEZE).freezes, 1)


func test_rising_splitter_splits_the_next_volleys_first_ball() -> void:
	var game := _auto_collect(Pickup.Type.SPLITTER)
	assert_eq(game.pending_splits, 1)
	game.fire(0.0, 1.0)
	game.step()
	assert_eq(game.volley.balls.size(), 3)
	assert_eq(game.pending_splits, 0)


func test_rising_laser_fires_where_it_is() -> void:
	var board := Board.new()
	board.add_pickup(Pickup.new(Pickup.Type.LASER, 2, 1, Pickup.VERTICAL))
	var target := board.add_brick(Brick.new(Brick.Type.STONE, 99, 2, 15))
	var game := _controller(board)
	game.play_turn(0.6, 1.0)
	assert_eq(target.hp, 98)
	assert_eq(game.points, 1, "the beam's damage counts as points")


# --- Determinism -------------------------------------------------------------

func test_pickups_replay_and_clone_exactly() -> void:
	var build := func() -> TurnController:
		var board := Board.new()
		board.add_pickup(Pickup.new(Pickup.Type.SPLITTER, 6, 5))
		board.add_pickup(Pickup.new(Pickup.Type.LASER, 9, 8, Pickup.HORIZONTAL))
		board.add_pickup(Pickup.new(Pickup.Type.FREEZE, 3, 6))
		board.add_pickup(Pickup.new(Pickup.Type.COIN, 11, 7))
		for col in [1, 4, 8, 12]:
			board.add_brick(Brick.new(Brick.Type.STONE, 20, col, 10))
		return _controller(board, 5)
	var a: TurnController = build.call()
	var b: TurnController = build.call()
	a.play_turn(0.1, 1.0)
	b.play_turn(0.1, 1.0)
	var c := a.clone()
	for game in [a, b, c]:
		game.play_turn(-0.4, 0.8)
		game.play_turn(0.7, 0.6)
	assert_eq(a.snapshot(), b.snapshot())
	assert_eq(a.snapshot(), c.snapshot())
