extends SceneTree
## Solver bot: plays seeded runs of the dig headless and reports how deep it gets.
##
##   godot --headless --path . -s tools/solver.gd [-- options]
##
## Options (all optional):
##   --runs=K          runs per start level (default 8)
##   --starts=1,3,6    start levels (default: the curve's target_depth keys)
##   --aims=N          aims tried each turn (default 6)
##   --lookahead=M     best aims looked one turn further ahead (default 2)
##   --next-aims=N     aims tried on that next turn (default 3)
##   --jobs=J          worker processes (default: cores - 1)
##   --max-turns=T     a run that lasts this long stops and counts as capped (default 120)
##   --seed=S          first seed (default 1)
##   --curve=PATH      depth curve to test (default res://levels/depth_curve.tres)
##   --out=PATH        report file (default res://tools/reports/solver-latest.md)
##
## The bot is greedy: it tries evenly spread aims (with a seeded jitter) on
## clones of the game, scores each result, then looks one more turn ahead from
## the best few. It never uses the continue and never spends coins.
##
## Each run is played in its own worker process (this script again, with --worker).
## Threads don't help: GDScript threads fight over the engine's object locks
## and run far slower than one thread.
##
## Exits 1 if any start level's median depth falls outside the curve's target band.

const DEFAULT_OUT := "res://tools/reports/solver-latest.md"

var runs := 8
var starts: Array[int] = []
var aims := 6
var lookahead := 2
var next_aims := 3
var jobs := maxi(1, OS.get_processor_count() - 1)
var max_turns := 120
var first_seed := 1
var curve_path := DepthCurve.DEFAULT_PATH
var out_path := DEFAULT_OUT
## Set in worker processes: which run to play (with --jobs as the stride), and where to put the results.
var worker := -1
var results_path := ""

var curve: DepthCurve


class Bot:
	## Biggest aim angle from straight down, matching TurnController.MIN_AIM_DY.
	var max_angle := acos(TurnController.MIN_AIM_DY)
	var aims: int
	var lookahead: int
	var next_aims: int
	var rng := RandomNumberGenerator.new()

	func _init(p_seed: int, p_aims: int, p_lookahead: int, p_next_aims: int) -> void:
		rng.seed = p_seed
		aims = p_aims
		lookahead = p_lookahead
		next_aims = p_next_aims

	## Picks this turn's aim as (dx, dy).
	func choose(game: TurnController) -> Vector2:
		var scored: Array = []
		for aim in _spread(aims):
			var after := game.clone()
			after.play_turn(aim.x, aim.y)
			scored.append({"aim": aim, "score": Bot.score(after), "after": after})
		scored.sort_custom(func(a, b): return a["score"] > b["score"])

		var best: Dictionary = scored[0]
		if lookahead <= 0:
			return best["aim"]
		var best_total := -INF
		for i in mini(lookahead, scored.size()):
			var entry: Dictionary = scored[i]
			var after: TurnController = entry["after"]
			if after.phase == TurnController.Phase.LOST:
				continue
			var future := -INF
			for aim in _spread(next_aims):
				var next := after.clone()
				next.play_turn(aim.x, aim.y)
				future = maxf(future, Bot.score(next))
			if future > best_total:
				best_total = future
				best = entry
		return best["aim"]

	## Evenly spread aims across the legal range, shifted by a random offset.
	func _spread(count: int) -> Array[Vector2]:
		var out: Array[Vector2] = []
		var spacing := 2.0 * max_angle / count
		var offset := rng.randf()
		for i in count:
			var angle := -max_angle + (i + offset) * spacing
			out.append(Vector2(sin(angle), cos(angle)))
		return out

	## How good a position is. Losing is worst; then levels cleared, room left
	## before getting trapped, progress through the level, balls, and the HP
	## still to dig through for each ball.
	static func score(game: TurnController) -> float:
		if game.phase == TurnController.Phase.LOST:
			return -1.0e9 + game.turn
		var headroom := game.rows_until_trapped()
		var hp_left := 0
		for brick in game.board.bricks:
			if brick.row < game.level_line_row:
				hp_left += brick.hp
		var s := game.levels_cleared * 1000.0
		s += game.rows_cleared() * 60.0
		s += mini(headroom, 10) * 80.0 + headroom * 5.0
		s += game.ball_count * 20.0
		s -= 15.0 * hp_left / maxf(game.ball_count, 1.0)
		return s


func _init() -> void:
	if not _parse_args():
		quit(2)
		return
	curve = load(curve_path) as DepthCurve
	if curve == null:
		printerr("Couldn't load a DepthCurve from %s" % curve_path)
		quit(2)
		return
	if starts.is_empty():
		for key in curve.target_depth.keys():
			starts.append(int(key))
		if starts.is_empty():
			starts = [1]
		starts.sort()

	if worker >= 0:
		var file := FileAccess.open(results_path, FileAccess.WRITE)
		file.store_string(JSON.stringify(_worker(_specs(), worker, jobs)))
		file.close()
		quit(0)
		return

	print("Solver: %d runs x starts %s, %d aims (+%d x %d lookahead), %d jobs" % [
		runs, starts, aims, lookahead, next_aims, jobs])
	var started := Time.get_ticks_msec()
	var results := _play_all()
	var seconds := (Time.get_ticks_msec() - started) / 1000.0

	var report := _report(results, seconds)
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	if file == null:
		printerr("Couldn't write %s" % out_path)
		quit(2)
		return
	file.store_string(report["text"])
	file.close()
	print("Report written to %s (%.0f s)" % [ProjectSettings.globalize_path(out_path), seconds])
	for line: String in report["verdicts"]:
		print(line)
	quit(1 if report["failed"] else 0)


func _parse_args() -> bool:
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		var value := parts[1] if parts.size() > 1 else ""
		match parts[0]:
			"runs": runs = maxi(1, value.to_int())
			"aims": aims = maxi(1, value.to_int())
			"lookahead": lookahead = maxi(0, value.to_int())
			"next-aims": next_aims = maxi(1, value.to_int())
			"jobs": jobs = maxi(1, value.to_int())
			"max-turns": max_turns = maxi(1, value.to_int())
			"seed": first_seed = value.to_int()
			"curve": curve_path = value
			"out": out_path = value
			"worker": worker = value.to_int()
			"results": results_path = value
			"starts":
				for level in value.split(",", false):
					starts.append(maxi(1, level.to_int()))
			_:
				printerr("Unknown option: %s" % arg)
				return false
	return true


func _specs() -> Array:
	var specs: Array = []
	for start in starts:
		for i in runs:
			specs.append({"start": start, "seed": first_seed + i})
	return specs


## Plays every (start level, seed) pair, one worker process per run with up
## to `jobs` running at once, so one long run doesn't hold up a whole batch.
func _play_all() -> Array:
	var specs := _specs()
	if jobs <= 1:
		return _worker(specs, 0, 1)
	var results: Array = []
	var running := {} # pid -> results path
	var next := 0
	while next < specs.size() or not running.is_empty():
		while next < specs.size() and running.size() < jobs:
			var path := ProjectSettings.globalize_path("user://solver-run-%d.json" % next)
			DirAccess.remove_absolute(path)
			var args := ["--headless", "--path", ProjectSettings.globalize_path("res://"),
				"-s", "res://tools/solver.gd", "--"]
			args.append_array(OS.get_cmdline_user_args())
			args.append_array(["--jobs=%d" % specs.size(), "--worker=%d" % next, "--results=%s" % path])
			running[OS.create_process(OS.get_executable_path(), args)] = path
			next += 1
		OS.delay_msec(250)
		for pid in running.keys():
			if OS.is_process_running(pid):
				continue
			results.append_array(_collect(running[pid]))
			running.erase(pid)
	return results


## Reads one worker's results file and deletes it.
func _collect(path: String) -> Array:
	var json = JSON.parse_string(FileAccess.get_file_as_string(path))
	DirAccess.remove_absolute(path)
	if not json is Array:
		printerr("A worker left no results in %s" % path)
		return []
	var out: Array = []
	for data in json:
		var result := _from_json(data)
		print("  start %d seed %d: depth %d, %d turns (%.0f s)" % [
			result["start"], result["seed"], result["depth"], result["turns"], result["seconds"]])
		out.append(result)
	return out


## JSON turns every number into a float and every key into a string. Undo that.
func _from_json(data: Dictionary) -> Dictionary:
	var result := {}
	for key in ["seed", "start", "depth", "cleared", "turns", "coins", "balls"]:
		result[key] = int(data[key])
	result["capped"] = bool(data["capped"])
	result["seconds"] = float(data["seconds"])
	var level_turns := {}
	for level in data["level_turns"]:
		level_turns[int(level)] = int(data["level_turns"][level])
	result["level_turns"] = level_turns
	return result


func _worker(specs: Array, first: int, stride: int) -> Array:
	var out: Array = []
	for i in range(first, specs.size(), stride):
		out.append(play_run(specs[i]["seed"], specs[i]["start"]))
	return out


## Plays one run until it's lost or hits max_turns.
func play_run(seed: int, start: int) -> Dictionary:
	var started := Time.get_ticks_msec()
	var game := TurnController.create(seed, start, curve)
	var bot := Bot.new(seed * 7919 + start, aims, lookahead, next_aims)
	var level_turns := {}
	var level_started := game.turn
	while game.phase != TurnController.Phase.LOST and game.turn <= max_turns:
		var aim := bot.choose(game)
		var level := game.level
		game.play_turn(aim.x, aim.y)
		if game.level != level:
			level_turns[level] = game.turn - level_started
			level_started = game.turn
	var result := {
		"seed": seed, "start": start, "depth": game.level,
		"cleared": game.levels_cleared, "turns": game.turn - 1,
		"coins": game.coins_earned(), "balls": game.ball_count,
		"capped": game.phase != TurnController.Phase.LOST,
		"level_turns": level_turns,
		"seconds": (Time.get_ticks_msec() - started) / 1000.0,
	}
	print("  start %d seed %d: depth %d, %d turns, %d coins%s (%.0f s)" % [
		start, seed, result["depth"], result["turns"], result["coins"],
		", capped" if result["capped"] else "", (Time.get_ticks_msec() - started) / 1000.0])
	return result


func _report(results: Array, seconds: float) -> Dictionary:
	var lines := PackedStringArray()
	var verdicts := PackedStringArray()
	var failed := false

	lines.append("# Solver report")
	lines.append("")
	lines.append("Generated %s by `tools/solver.gd` in %.0f s." % [Time.get_datetime_string_from_system(false, true), seconds])
	lines.append("")
	lines.append("- Curve: `%s`" % curve_path)
	lines.append("- %d runs per start level, seeds %d-%d" % [runs, first_seed, first_seed + runs - 1])
	lines.append("- Bot: greedy, %d aims a turn, best %d looked ahead with %d aims each" % [aims, lookahead, next_aims])
	lines.append("- Runs stop at %d turns (counted as capped). No continues, no coins spent." % max_turns)
	lines.append("- Depth = the level the run was on when it got trapped.")
	lines.append("")

	lines.append("## Depth reached")
	lines.append("")
	lines.append("| Start | Median | p10 | p90 | Target | Result | Median turns | Median coins | Capped |")
	lines.append("|---|---|---|---|---|---|---|---|---|")
	for start in starts:
		var group := _runs_from(results, start)
		var depths := _values(group, "depth")
		var median := _percentile(depths, 0.5)
		var target := curve.target_for(start)
		var verdict := "no target"
		if target != Vector2i.ZERO:
			var ok := median >= target.x and median <= target.y
			verdict = "pass" if ok else "FAIL"
			failed = failed or not ok
		verdicts.append("Start %d: median depth %s, target %s -> %s" % [
			start, _num(median), _band(target), verdict])
		lines.append("| %d | %s | %s | %s | %s | %s | %s | %s | %d/%d |" % [
			start, _num(median), _num(_percentile(depths, 0.1)), _num(_percentile(depths, 0.9)),
			_band(target), verdict, _num(_percentile(_values(group, "turns"), 0.5)),
			_num(_percentile(_values(group, "coins"), 0.5)), _count_capped(group), group.size()])
	lines.append("")

	lines.append("## Turns per level")
	lines.append("")
	lines.append("Turns to clear each level, across every run that cleared it.")
	lines.append("")
	lines.append("| Level | Runs | Median | p10 | p90 |")
	lines.append("|---|---|---|---|---|")
	var by_level := {}
	for result in results:
		for level in result["level_turns"]:
			if not by_level.has(level):
				by_level[level] = []
			by_level[level].append(float(result["level_turns"][level]))
	var levels := by_level.keys()
	levels.sort()
	for level in levels:
		var turns: Array = by_level[level]
		lines.append("| %d | %d | %s | %s | %s |" % [level, turns.size(), _num(_percentile(turns, 0.5)),
			_num(_percentile(turns, 0.1)), _num(_percentile(turns, 0.9))])
	lines.append("")

	lines.append("## Coins per run")
	lines.append("")
	lines.append("Net = coins earned minus the start price.")
	lines.append("")
	lines.append("| Start | Start price | Median coins | Mean coins | Mean net |")
	lines.append("|---|---|---|---|---|")
	for start in starts:
		var coins := _values(_runs_from(results, start), "coins")
		var mean := _mean(coins)
		lines.append("| %d | %d | %s | %s | %s |" % [start, Economy.start_cost(start),
			_num(_percentile(coins, 0.5)), _num(mean), _num(mean - Economy.start_cost(start))])
	lines.append("")

	lines.append("## Affording a restart")
	lines.append("")
	var fresh := _runs_from(results, 1)
	if fresh.is_empty():
		lines.append("No runs from level 1, so there's no no-spend income to measure.")
	else:
		var income := _mean(_values(fresh, "coins"))
		lines.append("No-spend runs = level-1 runs (mean %s coins each) needed to save up the price. Reached = share of level-1 runs that got that deep." % _num(income))
		lines.append("")
		lines.append("| Level | Price | No-spend runs | Reached |")
		lines.append("|---|---|---|---|")
		var deepest := 0
		for result in fresh:
			deepest = maxi(deepest, result["depth"])
		for level in range(2, maxi(deepest, 6) + 1):
			var price := Economy.start_cost(level)
			var needed := "-" if income <= 0.0 else str(ceili(price / income))
			var reached := 0
			for result in fresh:
				if result["depth"] >= level:
					reached += 1
			lines.append("| %d | %d | %s | %d%% |" % [level, price, needed, roundi(100.0 * reached / fresh.size())])
	lines.append("")

	lines.append("## Curve")
	lines.append("")
	lines.append("| Level | World | Twist | Pressure | First-row HP | Fill | Keep | Min gaps | Max run | Double HP | +1 Ball | Special brick | Special pickup |")
	lines.append("|---|---|---|---|---|---|---|---|---|---|---|---|---|")
	for level in range(1, 21):
		lines.append("| %d | %s | %s | %.2f | %d | %.2f | %.2f | %d | %d | %.2f | %.2f | %.2f | %.2f |" % [level,
			curve.world_name(level), curve.twist_at(level).capitalize() if curve.twist_at(level) != "" else "-",
			curve.pressure(level), curve.hp_at(level, 0) * curve.twist_hp_at(level), curve.fill_chance_at(level),
			curve.keep_chance_at(level), curve.min_gaps_at(level), curve.max_run_at(level),
			curve.double_chance_at(level), curve.pickup_chance_at(level), curve.special_chance_at(level),
			curve.special_pickup_chance_at(level)])
	lines.append("")

	lines.append("## Runs")
	lines.append("")
	lines.append("| Start | Seed | Depth | Turns | Coins | Balls | Capped | Seconds |")
	lines.append("|---|---|---|---|---|---|---|---|")
	for start in starts:
		for result in _runs_from(results, start):
			lines.append("| %d | %d | %d | %d | %d | %d | %s | %.0f |" % [start, result["seed"], result["depth"],
				result["turns"], result["coins"], result["balls"], "yes" if result["capped"] else "", result["seconds"]])
	lines.append("")

	return {"text": "\n".join(lines), "verdicts": verdicts, "failed": failed}


func _runs_from(results: Array, start: int) -> Array:
	var out: Array = []
	for result in results:
		if result["start"] == start:
			out.append(result)
	out.sort_custom(func(a, b): return a["seed"] < b["seed"])
	return out


func _values(group: Array, key: String) -> Array:
	var out: Array = []
	for result in group:
		out.append(float(result[key]))
	return out


func _count_capped(group: Array) -> int:
	var count := 0
	for result in group:
		if result["capped"]:
			count += 1
	return count


## Linear-interpolated percentile, `p` from 0 to 1. NAN for an empty list.
static func _percentile(values: Array, p: float) -> float:
	if values.is_empty():
		return NAN
	var sorted := values.duplicate()
	sorted.sort()
	var pos := p * (sorted.size() - 1)
	var low := floori(pos)
	var high := mini(low + 1, sorted.size() - 1)
	return lerpf(sorted[low], sorted[high], pos - low)


static func _mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += value
	return total / values.size()


static func _num(value: float) -> String:
	if is_nan(value):
		return "-"
	return str(roundi(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value


static func _band(target: Vector2i) -> String:
	return "-" if target == Vector2i.ZERO else "%d-%d" % [target.x, target.y]
