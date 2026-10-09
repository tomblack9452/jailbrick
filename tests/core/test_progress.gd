extends GutTest
## Coins, restart prices and the progress save.

const PATH := "user://test_progress.json"


func after_each() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)


func test_level_one_is_free_and_deeper_costs_more() -> void:
	assert_eq(Economy.start_cost(1), 0)
	assert_gt(Economy.start_cost(3), Economy.start_cost(2))


func test_coins_come_from_points_and_levels() -> void:
	assert_eq(Economy.coins_for(Economy.POINTS_PER_COIN * 3, 2), 3 + 2 * Economy.COINS_PER_LEVEL)


func test_bank_adds_coins_and_keeps_best_level() -> void:
	var progress := Progress.new()
	progress.bank(40, 6)
	progress.bank(10, 3)
	assert_eq(progress.coins, 50)
	assert_eq(progress.best_level, 6)


func test_can_only_start_at_reached_levels_you_can_afford() -> void:
	var progress := Progress.new()
	progress.best_level = 4
	progress.coins = Economy.start_cost(3)
	assert_true(progress.can_start_at(1))
	assert_true(progress.can_start_at(3))
	assert_false(progress.can_start_at(4), "too expensive")
	assert_false(progress.can_start_at(5), "not reached yet")


func test_pay_for_start_spends_coins() -> void:
	var progress := Progress.new()
	progress.best_level = 3
	progress.coins = 1000
	assert_true(progress.pay_for_start(3))
	assert_eq(progress.coins, 1000 - Economy.start_cost(3))


func test_save_and_load_round_trip() -> void:
	var progress := Progress.new()
	progress.coins = 321
	progress.best_level = 7
	assert_true(progress.save(PATH))
	var loaded := Progress.load_from(PATH)
	assert_eq(loaded.coins, 321)
	assert_eq(loaded.best_level, 7)


func test_missing_or_broken_save_gives_fresh_progress() -> void:
	assert_eq(Progress.load_from("user://does_not_exist.json").coins, 0)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("not json")
	file.close()
	assert_eq(Progress.load_from(PATH).best_level, 1)
