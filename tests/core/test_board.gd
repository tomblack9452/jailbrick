extends GutTest
## Board grid, brick damage and the rise step.


func test_board_is_fifteen_columns() -> void:
	assert_eq(Board.new().columns, 15)


func test_brick_takes_damage() -> void:
	var brick := Brick.new(Brick.Type.STONE, 3)
	assert_eq(brick.take_hit(1), 1)
	assert_eq(brick.hp, 2)
	assert_false(brick.is_destroyed())


func test_damage_never_goes_below_zero() -> void:
	var brick := Brick.new(Brick.Type.STONE, 2)
	assert_eq(brick.take_hit(5), 2, "only the HP it had")
	assert_eq(brick.hp, 0)
	assert_true(brick.is_destroyed())


func test_destroyed_brick_leaves_the_board() -> void:
	var board := Board.new()
	var brick := board.add_brick(Brick.new(Brick.Type.STONE, 1, 2, 4))
	board.damage_brick(brick, 1)
	assert_null(board.brick_at(2, 4))
	assert_eq(board.bricks.size(), 0)


func test_wide_lock_fills_both_cells() -> void:
	var board := Board.new()
	var lock := board.add_brick(Lock.new(30, 2, 5, 2))
	assert_eq(board.brick_at(2, 5), lock)
	assert_eq(board.brick_at(3, 5), lock)
	assert_eq(board.lock, lock)
	assert_true(lock.is_lock())


func test_rise_moves_everything_up_one_row() -> void:
	var board := Board.new()
	var brick := board.add_brick(Brick.new(Brick.Type.STONE, 4, 1, 6))
	var pickup := board.add_pickup(Pickup.new(Pickup.Type.EXTRA_BALL, 2, 8))
	board.rise()
	assert_eq(brick.row, 5)
	assert_eq(pickup.row, 7)
	assert_eq(board.brick_at(1, 5), brick)
	assert_null(board.brick_at(1, 6))


func test_rise_collects_pickups_reaching_danger_row() -> void:
	var board := Board.new()
	board.add_pickup(Pickup.new(Pickup.Type.EXTRA_BALL, 2, 1))
	var collected := board.rise()
	assert_eq(collected.size(), 1)
	assert_eq(board.pickups.size(), 0)


func test_trapped_when_brick_reaches_danger_row() -> void:
	var board := Board.new()
	board.add_brick(Brick.new(Brick.Type.STONE, 4, 0, 1))
	assert_false(board.is_trapped())
	board.rise()
	assert_true(board.is_trapped())


func test_clone_is_independent() -> void:
	var board := Board.new()
	board.add_brick(Brick.new(Brick.Type.STONE, 4, 1, 6))
	board.add_brick(Lock.new(20, 3, 7, 2))
	var copy := board.clone()
	copy.damage_brick(copy.brick_at(1, 6), 1)
	copy.rise()
	assert_eq(board.brick_at(1, 6).hp, 4)
	assert_eq(copy.lock.row, 6)
	assert_eq(board.lock.row, 7)
	assert_true(copy.lock is Lock)


func test_generator_leaves_gaps_and_breaks_long_runs() -> void:
	var generator := RowGenerator.new(5)
	for turn in range(1, 40):
		var row := generator.generate(turn, Board.COLUMNS)
		var cols: Array[int] = []
		for entry in row["bricks"]:
			cols.append(entry[0])
		assert_lte(cols.size(), Board.COLUMNS - generator.min_gaps)
		var run := 0
		for col in Board.COLUMNS:
			run = run + 1 if cols.has(col) else 0
			assert_lte(run, generator.max_run)
