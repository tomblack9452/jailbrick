extends GutTest

const LEVELS := 40

var curve: DepthCurve


func before_each() -> void:
	curve = DepthCurve.load_default()


func test_curve_resource_loads() -> void:
	assert_not_null(curve)
	assert_eq(curve.band_ramp.size(), curve.band_size)


func test_each_band_starts_with_a_breather_then_ramps() -> void:
	for level in range(1, LEVELS):
		var in_band := (level - 1) % curve.band_size
		if in_band == curve.band_size - 1:
			assert_lt(curve.pressure(level + 1), curve.pressure(level), "level %d should be a breather" % (level + 1))
		else:
			assert_gt(curve.pressure(level + 1), curve.pressure(level), "level %d should ramp" % (level + 1))


func test_breather_is_easier_than_the_peak_before_it() -> void:
	for peak in [5, 10, 15]:
		var breather: int = peak + 1
		assert_lt(curve.fill_chance_at(breather), curve.fill_chance_at(peak))
		assert_lt(curve.double_chance_at(breather), curve.double_chance_at(peak))
		assert_gt(curve.pickup_chance_at(breather), curve.pickup_chance_at(peak))
		assert_gte(curve.min_gaps_at(breather), curve.min_gaps_at(peak))


func test_pressure_builds_by_levels_3_and_4() -> void:
	assert_gte(curve.pressure(3), 0.5)
	assert_gte(curve.pressure(4), 0.75)
	assert_gt(curve.hp_at(4, 0), curve.hp_at(1, 0) + 10)


func test_later_bands_are_harder_at_the_same_point() -> void:
	for level in range(1, curve.band_size + 1):
		var next_band := level + curve.band_size
		assert_gt(curve.hp_at(next_band, 0), curve.hp_at(level, 0))
		assert_gte(curve.double_chance_at(next_band), curve.double_chance_at(level))
		assert_lte(curve.pickup_chance_at(next_band), curve.pickup_chance_at(level))


func test_hp_always_climbs_with_depth() -> void:
	for level in range(1, LEVELS):
		assert_lt(curve.hp_at(level, 0), curve.hp_at(level + 1, 0))
		assert_lte(curve.hp_at(level, 0), curve.hp_at(level, LevelGenerator.LEVEL_ROWS - 1))


func test_knobs_stay_in_range_deep_down() -> void:
	for level in range(1, 200):
		for chance in [curve.fill_chance_at(level), curve.keep_chance_at(level),
				curve.double_chance_at(level), curve.pickup_chance_at(level)]:
			assert_between(chance, 0.0, 1.0)
		assert_between(curve.min_gaps_at(level), 1, Board.COLUMNS - 1)
		assert_gte(curve.max_run_at(level), 1)
		assert_gte(curve.hp_at(level, 0), 1)


func test_generator_uses_the_curve_for_each_level() -> void:
	var generator := LevelGenerator.new(4, curve)
	for level in [1, 4, 6, 12]:
		var rows := generator.generate_level(level, Board.COLUMNS)
		assert_almost_eq(generator.fill_chance, curve.fill_chance_at(level), 1e-6)
		assert_almost_eq(generator.pickup_chance, curve.pickup_chance_at(level), 1e-6)
		assert_eq(generator.min_gaps, curve.min_gaps_at(level))
		for i in rows.size():
			var gaps: int = Board.COLUMNS - rows[i]["bricks"].size()
			assert_gte(gaps, curve.min_gaps_at(level))
			for entry in rows[i]["bricks"]:
				assert_true(entry[1] == curve.hp_at(level, i) or entry[1] == curve.hp_at(level, i) * 2)


func test_runs_use_the_default_curve() -> void:
	var game := TurnController.create(1, 3)
	assert_eq(game.generator.curve, curve)
	assert_eq(game.board.bricks[0].hp % curve.hp_at(3, 0), 0)


func test_generator_clone_keeps_the_curve() -> void:
	var generator := LevelGenerator.new(9, curve)
	var copy := generator.clone()
	assert_eq(generator.generate_level(2, Board.COLUMNS), copy.generate_level(2, Board.COLUMNS))


func test_targets_are_valid_bands() -> void:
	assert_true(curve.target_depth.has(1), "needs a target for runs from level 1")
	for start in curve.target_depth:
		var band := curve.target_for(start)
		assert_lte(band.x, band.y)
		assert_gte(band.x, start)
	assert_eq(curve.target_for(999), Vector2i.ZERO)
