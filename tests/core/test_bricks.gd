extends GutTest
## Special bricks from B4: iron, crate, gas can, rat nest, sludge and the Warden guard.

const MID := Board.COLUMNS / 2


func _controller(board: Board, balls := 1) -> TurnController:
	var game := TurnController.new(board, null, balls)
	game.level_line_row = 21
	return game


# --- Iron --------------------------------------------------------------------

func test_iron_takes_every_other_hit_at_normal_damage() -> void:
	var iron := Brick.new(Brick.Type.IRON, 10)
	var taken: Array[int] = []
	for i in 4:
		taken.append(iron.take_hit(1))
	assert_eq(taken, [1, 0, 1, 0] as Array[int])
	assert_eq(iron.hp, 8)


func test_iron_takes_half_damage_rounded_up() -> void:
	var iron := Brick.new(Brick.Type.IRON, 10)
	assert_eq(iron.take_hit(3), 2, "half of 3, rounded up")
	assert_eq(iron.take_hit(3), 1, "6 received, 3 taken in total")
	assert_eq(iron.hp, 7)


func test_iron_clone_keeps_its_rounding() -> void:
	var iron := Brick.new(Brick.Type.IRON, 10)
	iron.take_hit(1)
	assert_eq(iron.clone().take_hit(1), 0)


# --- Crate -------------------------------------------------------------------

func test_crate_drops_its_pickup_when_broken() -> void:
	var board := Board.new()
	var crate := Brick.new(Brick.Type.CRATE, 2, 4, 6)
	crate.drop = Pickup.Type.EXTRA_BALL
	board.add_brick(crate)
	board.damage_brick(crate, 1)
	assert_null(board.pickup_at(4, 6), "not broken yet")
	board.damage_brick(crate, 1)
	var pickup := board.pickup_at(4, 6)
	assert_not_null(pickup)
	assert_eq(pickup.type, Pickup.Type.EXTRA_BALL)


func test_crate_with_no_drop_leaves_nothing() -> void:
	var board := Board.new()
	var crate := board.add_brick(Brick.new(Brick.Type.CRATE, 1, 4, 6))
	board.damage_brick(crate, 1)
	assert_eq(board.pickups.size(), 0)


func test_ball_collects_a_crate_drop_in_the_same_volley() -> void:
	var board := Board.new()
	var crate := Brick.new(Brick.Type.CRATE, 1, MID, 6)
	crate.drop = Pickup.Type.EXTRA_BALL
	board.add_brick(crate)
	var game := _controller(board, 3)
	game.play_turn(0.0, 1.0)
	assert_eq(game.ball_count, 4, "a later ball flew through the drop")


# --- Gas can -----------------------------------------------------------------

func test_gas_can_blasts_all_eight_neighbours() -> void:
	var board := Board.new()
	var gas := board.add_brick(Brick.new(Brick.Type.GAS, 1, 5, 6))
	var around: Array[Brick] = []
	for row in [5, 6, 7]:
		for col in [4, 5, 6]:
			if col != 5 or row != 6:
				around.append(board.add_brick(Brick.new(Brick.Type.STONE, 10, col, row)))
	var far := board.add_brick(Brick.new(Brick.Type.STONE, 10, 8, 6))
	board.damage_brick(gas, 1)
	for brick in around:
		assert_eq(brick.hp, 9, "blast is the can's max HP")
	assert_eq(far.hp, 10, "out of range")
	assert_eq(board.effects.size(), 1)
	assert_eq(board.effects[0]["kind"], "blast")


func test_gas_blast_scales_with_the_cans_hp_and_breaks_bricks() -> void:
	var board := Board.new()
	var gas := board.add_brick(Brick.new(Brick.Type.GAS, 20, 5, 6))
	var weak := board.add_brick(Brick.new(Brick.Type.STONE, 15, 6, 6))
	var dealt := board.damage_brick(gas, 20)
	assert_true(weak.is_destroyed())
	assert_null(board.brick_at(6, 6))
	assert_eq(dealt, 35, "the can's HP plus the neighbour's")


func test_gas_cans_chain() -> void:
	var board := Board.new()
	var first := board.add_brick(Brick.new(Brick.Type.GAS, 1, 2, 6))
	board.add_brick(Brick.new(Brick.Type.GAS, 1, 3, 6))
	var end := board.add_brick(Brick.new(Brick.Type.STONE, 5, 4, 6))
	board.damage_brick(first, 1)
	assert_eq(end.hp, 4, "the second can went off too")
	assert_eq(board.effects.size(), 2)


func test_gas_blast_halves_on_iron() -> void:
	var board := Board.new()
	var gas := board.add_brick(Brick.new(Brick.Type.GAS, 10, 5, 6))
	var iron := board.add_brick(Brick.new(Brick.Type.IRON, 30, 6, 6))
	board.damage_brick(gas, 10)
	assert_eq(iron.hp, 25)


func test_ball_points_include_the_blast() -> void:
	var board := Board.new()
	board.add_brick(Brick.new(Brick.Type.GAS, 1, MID, 6))
	board.add_brick(Brick.new(Brick.Type.STONE, 50, MID + 1, 6))
	var game := _controller(board)
	game.play_turn(0.0, 1.0)
	assert_eq(game.points, 2)


# --- Rat nest ----------------------------------------------------------------

func test_nest_spawns_a_one_hp_rat_every_two_turns() -> void:
	var board := Board.new()
	board.add_brick(Brick.new(Brick.Type.NEST, 999, 0, 15))
	var game := _controller(board)
	game.play_turn(0.6, 1.0)
	assert_eq(board.bricks.size(), 1, "nothing after one turn")
	game.play_turn(0.6, 1.0)
	assert_eq(board.bricks.size(), 2, "a rat after two")
	var rat := board.bricks[1]
	assert_eq(rat.type, Brick.Type.STONE)
	assert_eq(rat.hp, 1)
	var nest := board.bricks[0]
	assert_lte(absi(rat.row - nest.row), 1)
	assert_lte(absi(rat.col - nest.col), 1)


func test_nest_never_spawns_into_the_danger_row() -> void:
	var board := Board.new()
	var nest := Brick.new(Brick.Type.NEST, 999, 3, 1)
	nest.timer = 1
	board.add_brick(nest)
	var game := _controller(board)
	game._brick_turns()
	for brick in board.bricks:
		assert_gt(brick.row, Board.DANGER_ROW)


func test_boxed_in_nest_spawns_nothing() -> void:
	var board := Board.new()
	var nest := board.add_brick(Brick.new(Brick.Type.NEST, 999, 0, 10))
	for cell in [Vector2i(1, 9), Vector2i(0, 9), Vector2i(1, 10), Vector2i(0, 11), Vector2i(1, 11)]:
		board.add_brick(Brick.new(Brick.Type.STONE, 5, cell.x, cell.y))
	nest.timer = 1
	_controller(board)._brick_turns()
	assert_eq(board.bricks.size(), 6)


func test_nest_below_the_floor_waits() -> void:
	var board := Board.new()
	var nest := board.add_brick(Brick.new(Brick.Type.NEST, 999, 3, board.rows + 2))
	var game := _controller(board)
	game._brick_turns()
	game._brick_turns()
	assert_eq(nest.timer, 0)
	assert_eq(board.bricks.size(), 1)


# --- Sludge ------------------------------------------------------------------

func test_sludge_is_not_solid() -> void:
	var board := Board.new()
	var puddle := board.add_brick(Brick.new(Brick.Type.SLUDGE, 1, 4, 6))
	assert_false(puddle.is_solid())
	assert_null(board.brick_at(4, 6))
	assert_eq(board.sludge_at(4, 6), puddle)
	assert_false(board.is_free(4, 6))
	assert_eq(puddle.take_hit(5), 0)


func test_sludge_never_counts_for_clearing_or_trapping() -> void:
	var board := Board.new()
	board.add_brick(Brick.new(Brick.Type.SLUDGE, 1, 4, 1))
	assert_eq(board.bricks_above(20), 0)
	assert_false(board.is_trapped())
	board.rise()
	assert_false(board.is_trapped())
	assert_eq(board.sludge.size(), 0, "drained at the danger row")


func test_ball_passes_through_sludge_at_half_speed() -> void:
	var board := Board.new()
	board.add_brick(Brick.new(Brick.Type.SLUDGE, 1, 3, 4))
	var slowed := BallSim.new(board, 3.5, 0.0, 1.0, 0)
	var clear := BallSim.new(Board.new(), 3.5, 0.0, 1.0, 0)
	var a := slowed.add_ball(3.5, 4.2, 0.0, 1.0)
	var b := clear.add_ball(3.5, 4.2, 0.0, 1.0)
	for i in 3: # not long enough to leave the puddle
		slowed.step()
		clear.step()
	assert_almost_eq(b.y - 4.2, (a.y - 4.2) * 2.0, 1e-9)
	assert_eq(a.dy, 1.0, "didn't bounce")


func test_sludge_moves_with_the_board_and_clones() -> void:
	var board := Board.new()
	var puddle := board.add_brick(Brick.new(Brick.Type.SLUDGE, 1, 4, 6))
	var copy := board.clone()
	board.rise()
	assert_eq(puddle.row, 5)
	assert_eq(board.sludge_at(4, 5), puddle)
	assert_not_null(copy.sludge_at(4, 6))


# --- Warden guard ------------------------------------------------------------

func _guard(col: int, row := 8) -> Brick:
	var guard := Brick.new(Brick.Type.GUARD, 200, col, row, 2)
	guard.minion_hp = 7
	return guard


func test_guard_walks_one_column_per_turn() -> void:
	var board := Board.new()
	var guard := board.add_brick(_guard(5))
	var game := _controller(board)
	game._brick_turns()
	assert_eq(guard.col, 6)
	assert_eq(board.brick_at(7, 8), guard)
	assert_null(board.brick_at(5, 8))


func test_guard_turns_at_the_wall() -> void:
	var board := Board.new()
	var guard := board.add_brick(_guard(Board.COLUMNS - 2))
	_controller(board)._brick_turns()
	assert_eq(guard.col, Board.COLUMNS - 3)
	assert_eq(guard.heading, -1)


func test_guard_turns_at_a_brick_and_stays_when_boxed() -> void:
	var board := Board.new()
	var guard := board.add_brick(_guard(5))
	board.add_brick(Brick.new(Brick.Type.STONE, 5, 7, 8))
	var game := _controller(board)
	game._brick_turns()
	assert_eq(guard.col, 4)
	board.add_brick(Brick.new(Brick.Type.STONE, 5, 3, 8))
	board.add_brick(Brick.new(Brick.Type.STONE, 5, 6, 8))
	game._brick_turns()
	assert_eq(guard.col, 4, "boxed in")


func test_guard_spawns_a_minion_every_three_turns() -> void:
	var board := Board.new()
	board.add_brick(_guard(5))
	var game := _controller(board)
	for i in 2:
		game._brick_turns()
	assert_eq(board.bricks.size(), 1)
	game._brick_turns()
	assert_eq(board.bricks.size(), 2)
	assert_eq(board.bricks[1].hp, 7)


func test_move_brick_refuses_taken_cells() -> void:
	var board := Board.new()
	var a := board.add_brick(Brick.new(Brick.Type.STONE, 5, 2, 6))
	board.add_brick(Brick.new(Brick.Type.STONE, 5, 3, 6))
	assert_false(board.move_brick(a, 3))
	assert_eq(a.col, 2)
	assert_false(board.move_brick(a, -1))


# --- Determinism -------------------------------------------------------------

func _busy_board() -> Board:
	var board := Board.new()
	board.add_brick(Brick.new(Brick.Type.NEST, 30, 3, 12))
	board.add_brick(_guard(8, 10))
	board.add_brick(Brick.new(Brick.Type.GAS, 3, 6, 9))
	board.add_brick(Brick.new(Brick.Type.IRON, 9, 7, 9))
	board.add_brick(Brick.new(Brick.Type.SLUDGE, 1, 4, 7))
	return board


func test_special_bricks_replay_exactly() -> void:
	var runs: Array[String] = []
	for i in 2:
		var game := _controller(_busy_board(), 4)
		game.rng.seed = 42
		for aim in [[0.2, 1.0], [-0.5, 0.7], [0.6, 0.5], [0.0, 1.0]]:
			game.play_turn(aim[0], aim[1])
		runs.append(game.snapshot())
	assert_eq(runs[0], runs[1])


func test_clone_replays_special_bricks() -> void:
	var game := _controller(_busy_board(), 4)
	game.rng.seed = 7
	game.play_turn(0.3, 1.0)
	var copy := game.clone()
	for g in [game, copy]:
		for aim in [[0.2, 1.0], [-0.5, 0.7], [0.6, 0.5]]:
			g.play_turn(aim[0], aim[1])
	assert_eq(game.snapshot(), copy.snapshot())
