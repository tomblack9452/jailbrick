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


func test_wide_brick_fills_both_cells() -> void:
	var board := Board.new()
	var wide := board.add_brick(Brick.new(Brick.Type.STONE, 30, 2, 5, 2))
	assert_eq(board.brick_at(2, 5), wide)
	assert_eq(board.brick_at(3, 5), wide)


func test_brick_below_floor_is_hidden_until_it_rises() -> void:
	var board := Board.new()
	var brick := board.add_brick(Brick.new(Brick.Type.STONE, 3, 4, board.rows + 1))
	assert_null(board.brick_at(4, board.rows - 1))
	board.shift(-2)
	assert_eq(board.brick_at(4, board.rows - 1), brick)


func test_shift_down_moves_everything_down() -> void:
	var board := Board.new()
	var brick := board.add_brick(Brick.new(Brick.Type.STONE, 3, 4, 5))
	board.shift(3)
	assert_eq(brick.row, 8)
	assert_eq(board.brick_at(4, 8), brick)


func test_bricks_above_counts_only_higher_rows() -> void:
	var board := Board.new()
	board.add_brick(Brick.new(Brick.Type.STONE, 1, 0, 4))
	board.add_brick(Brick.new(Brick.Type.STONE, 1, 1, 5))
	board.add_brick(Brick.new(Brick.Type.STONE, 1, 2, 6))
	assert_eq(board.bricks_above(6), 2)


func test_clear_top_rows_removes_from_pile_top() -> void:
	var board := Board.new()
	for row in [5, 6, 7, 8]:
		board.add_brick(Brick.new(Brick.Type.STONE, 9, 0, row))
	board.clear_top_rows(3)
	assert_eq(board.bricks.size(), 1)
	assert_eq(board.topmost_brick_row(), 8)


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
	var wide := board.add_brick(Brick.new(Brick.Type.STONE, 20, 3, 7, 2))
	var copy := board.clone()
	copy.damage_brick(copy.brick_at(1, 6), 1)
	copy.rise()
	assert_eq(board.brick_at(1, 6).hp, 4)
	assert_eq(copy.brick_at(3, 6).width, 2)
	assert_eq(wide.row, 7)


func test_generator_leaves_gaps_and_breaks_long_runs() -> void:
	var generator := LevelGenerator.new(5)
	for i in 40:
		var row := generator.generate_row(5, Board.COLUMNS)
		var cols: Array[int] = []
		for entry in row["bricks"]:
			cols.append(entry[0])
		assert_lte(cols.size(), Board.COLUMNS - generator.min_gaps)
		var run := 0
		for col in Board.COLUMNS:
			run = run + 1 if cols.has(col) else 0
			assert_lte(run, generator.max_run)


func test_level_is_ten_rows_and_hp_grows_with_depth() -> void:
	var generator := LevelGenerator.new(3)
	assert_eq(generator.generate_level(1, Board.COLUMNS).size(), LevelGenerator.LEVEL_ROWS)
	assert_lt(generator.hp_at(1, 0), generator.hp_at(1, 9))
	assert_lt(generator.hp_at(1, 9), generator.hp_at(3, 9))
