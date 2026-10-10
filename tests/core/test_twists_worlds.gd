extends GutTest
## Band twists (B3), world bands and introduction levels (B9), all from the depth curve.

const SEEDS := 12

var curve: DepthCurve


func before_each() -> void:
	curve = DepthCurve.load_default()


## Every brick and pickup in `level` across a few seeds.
func _contents(level: int) -> Dictionary:
	var bricks: Array[Brick] = []
	var pickups: Array[Pickup] = []
	for seed in SEEDS:
		var generator := LevelGenerator.new(seed, curve)
		for row in generator.generate_level(level, Board.COLUMNS):
			bricks.append_array(row["bricks"])
			pickups.append_array(row["pickups"])
	return {"bricks": bricks, "pickups": pickups}


func _count(bricks: Array[Brick], type: Brick.Type) -> int:
	return bricks.filter(func(b: Brick) -> bool: return b.type == type).size()


# --- Twists ------------------------------------------------------------------

func test_twist_schedule() -> void:
	var expected := {1: "", 3: "", 7: "", 8: "flood", 9: "", 10: "warden", 13: "nest",
		18: "cache", 20: "warden", 23: "flood", 28: "nest", 33: "cache", 40: "warden"}
	for level in expected:
		assert_eq(curve.twist_at(level), expected[level], "level %d" % level)


func test_twist_falls_back_to_flood_before_its_brick_arrives() -> void:
	var late := curve.duplicate() as DepthCurve
	late.introductions = curve.introductions.duplicate()
	late.introductions["nest"] = 50
	assert_eq(late.twist_at(13), "flood")


func test_flood_rises_two_rows_and_has_less_hp() -> void:
	assert_eq(curve.rise_at(8), 2)
	assert_eq(curve.rise_at(7), 1)
	var game := TurnController.create(3, 8)
	assert_eq(game.rise_rate, 2)
	var base := curve.hp_at(8, 0)
	for brick in game.board.bricks:
		if brick.type == Brick.Type.STONE and brick.row == TurnController.START_ROW:
			assert_true(brick.hp == int(base * curve.flood_hp) or brick.hp == int(base * 2 * curve.flood_hp) \
				or brick.hp == int(base * curve.flood_hp) * 2)


func test_rise_rate_follows_the_level_after_a_clear() -> void:
	var game := TurnController.create(5, 7)
	assert_eq(game.rise_rate, 1)
	for brick: Brick in game.board.bricks.duplicate():
		if brick.row < game.level_line_row:
			game.board.remove_brick(brick)
	game.play_turn(0.0, 1.0)
	assert_eq(game.level, 8)
	assert_eq(game.rise_rate, 2)


func test_nest_level_is_full_of_nests() -> void:
	var nest_level := _count(_contents(13)["bricks"], Brick.Type.NEST)
	var normal := _count(_contents(12)["bricks"], Brick.Type.NEST)
	assert_gt(nest_level, normal * 3)


func test_cache_level_is_full_of_crates_with_more_hp() -> void:
	var cache: Array[Brick] = _contents(18)["bricks"]
	var normal: Array[Brick] = _contents(17)["bricks"]
	assert_gt(_count(cache, Brick.Type.CRATE), _count(normal, Brick.Type.CRATE) * 2)
	var stone_hp := int(curve.hp_at(18, 0) * curve.cache_hp)
	assert_true(cache.any(func(b: Brick) -> bool: return b.type == Brick.Type.STONE and b.hp == stone_hp))


func test_warden_level_has_one_wide_guard() -> void:
	for seed in SEEDS:
		var guards: Array[Brick] = []
		var generator := LevelGenerator.new(seed, curve)
		var rows := generator.generate_level(10, Board.COLUMNS)
		for row in rows:
			for brick: Brick in row["bricks"]:
				if brick.type == Brick.Type.GUARD:
					guards.append(brick)
		assert_eq(guards.size(), 1)
		var guard := guards[0]
		assert_eq(guard.width, 2)
		assert_eq(guard.hp, int(curve.hp_at(10, 0) * curve.warden_hp))
		assert_eq(guard.minion_hp, int(curve.hp_at(10, 0) * curve.warden_minion_hp))
		assert_true(rows[curve.warden_row]["bricks"].has(guard))


func test_warden_guard_fits_on_the_board_in_a_real_run() -> void:
	var game := TurnController.create(2, 10)
	var guards := game.board.bricks.filter(func(b: Brick) -> bool: return b.type == Brick.Type.GUARD)
	assert_eq(guards.size(), 1, "only this level's guard is generated so far")
	var guard: Brick = guards[0]
	assert_eq(game.board.brick_at(guard.col, guard.row), guard)
	assert_eq(game.board.brick_at(guard.col + 1, guard.row), guard)


# --- Introductions -----------------------------------------------------------

func test_nothing_special_before_its_introduction() -> void:
	var names := {"crate": Brick.Type.CRATE, "sludge": Brick.Type.SLUDGE, "nest": Brick.Type.NEST,
		"iron": Brick.Type.IRON, "gas": Brick.Type.GAS}
	for name in names:
		var intro: int = curve.introductions[name]
		assert_eq(_count(_contents(intro - 1)["bricks"], names[name]), 0, "%s before level %d" % [name, intro])
		var at := 0
		for level in range(intro, intro + 3):
			at += _count(_contents(level)["bricks"], names[name])
		assert_gt(at, 0, "%s from level %d" % [name, intro])


func test_pickups_arrive_on_their_levels() -> void:
	for name in ["coin", "freeze", "splitter", "laser"]:
		var type: Pickup.Type = DepthCurve.PICKUP_NAMES[name]
		var intro: int = curve.introductions[name]
		if intro > 1:
			assert_false(curve.pickup_pool(intro - 1, true).any(func(e) -> bool: return e[0] == type))
		assert_true(curve.pickup_pool(intro, true).any(func(e) -> bool: return e[0] == type))


func test_rows_never_hand_out_extra_balls_as_specials() -> void:
	assert_false(curve.pickup_pool(30, false).any(func(e) -> bool: return e[0] == Pickup.Type.EXTRA_BALL))
	assert_true(curve.pickup_pool(30, true).any(func(e) -> bool: return e[0] == Pickup.Type.EXTRA_BALL))


func test_crates_carry_introduced_drops() -> void:
	for level in [2, 6, 12]:
		for brick: Brick in _contents(level)["bricks"]:
			if brick.type == Brick.Type.CRATE:
				assert_true(curve.pickup_pool(level, true).any(func(e) -> bool: return e[0] == brick.drop))
				assert_lt(brick.hp, maxi(2, curve.hp_at(level, LevelGenerator.LEVEL_ROWS - 1) * 2))


func test_sludge_lands_in_the_sludge_list() -> void:
	var game := TurnController.create(4, 5)
	assert_gt(game.board.sludge.size(), 0)
	for puddle in game.board.sludge:
		assert_false(game.board.bricks.has(puddle))


# --- Worlds ------------------------------------------------------------------

func test_worlds_are_ten_level_bands() -> void:
	var expected := {1: "The Drains", 10: "The Drains", 11: "Black Pines", 20: "Black Pines",
		21: "Scrap Row", 31: "The Hum", 41: "Lockdown", 99: "Lockdown"}
	for level in expected:
		assert_eq(curve.world_name(level), expected[level], "level %d" % level)


func test_every_world_ends_on_a_warden() -> void:
	for world in 5:
		assert_eq(curve.twist_at((world + 1) * curve.world_size), "warden")


func test_each_world_has_its_own_tint() -> void:
	var tints := {}
	for world in 4:
		tints[curve.world_tint(world * 10 + 1)] = true
	assert_eq(tints.size(), 4)


func test_finale_cycles_through_earlier_tints() -> void:
	var seen := {}
	for level in range(41, 45):
		seen[curve.world_tint(level)] = true
	assert_eq(seen.size(), 4)


func test_signature_bricks_spawn_more_in_their_world() -> void:
	var weight := func(level: int, type: Brick.Type) -> float:
		for entry in curve.brick_pool(level):
			if entry[0] == type:
				return entry[1]
		return 0.0
	assert_eq(weight.call(5, Brick.Type.SLUDGE), curve.brick_weights["sludge"] * curve.signature_weight)
	assert_eq(weight.call(15, Brick.Type.SLUDGE), curve.brick_weights["sludge"])
	assert_eq(weight.call(15, Brick.Type.CRATE), curve.brick_weights["crate"] * curve.signature_weight)
	assert_eq(weight.call(25, Brick.Type.IRON), curve.brick_weights["iron"] * curve.signature_weight)


# --- Determinism -------------------------------------------------------------

const AIMS := [[0.3, 1.0], [-0.7, 0.5], [0.05, 1.0], [0.9, 0.3], [-0.2, 1.0], [0.5, 0.8]]


func _play(game: TurnController) -> PackedStringArray:
	var states := PackedStringArray()
	for aim in AIMS:
		game.play_turn(aim[0], aim[1])
		states.append(game.snapshot())
	return states


func test_twist_levels_replay_exactly() -> void:
	for level in [8, 10, 13, 18, 27]:
		assert_eq(_play(TurnController.create(77, level)), _play(TurnController.create(77, level)), "level %d" % level)


func test_twist_levels_clone_exactly() -> void:
	for level in [10, 13]:
		var game := TurnController.create(78, level)
		game.play_turn(0.2, 1.0)
		var copy := game.clone()
		assert_eq(_play(game), _play(copy), "level %d" % level)
