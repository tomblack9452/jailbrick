class_name Progress
extends RefCounted
## What carries over between runs: coins and the deepest level reached.
## Saved as versioned JSON in user://. Phase 4 grows this into the full save system.

const VERSION := 1
const DEFAULT_PATH := "user://progress.json"

var coins := 0
var best_level := 1


## Banks a finished (or paused-for-continue) run. `new_coins` is only the
## coins not banked before, so a continued run doesn't pay twice.
func bank(new_coins: int, level_reached: int) -> void:
	coins += new_coins
	best_level = maxi(best_level, level_reached)


func can_start_at(level: int) -> bool:
	return level >= 1 and level <= best_level and coins >= Economy.start_cost(level)


## Pays for a run at `level`. Returns false (and changes nothing) if you can't.
func pay_for_start(level: int) -> bool:
	if not can_start_at(level):
		return false
	coins -= Economy.start_cost(level)
	return true


func to_dict() -> Dictionary:
	return {"version": VERSION, "coins": coins, "best_level": best_level}


static func from_dict(data: Dictionary) -> Progress:
	var progress := Progress.new()
	progress.coins = maxi(0, int(data.get("coins", 0)))
	progress.best_level = maxi(1, int(data.get("best_level", 1)))
	return progress


func save(path := DEFAULT_PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(to_dict()))
	return true


## Loads from disk, or returns fresh progress if there's no usable save.
static func load_from(path := DEFAULT_PATH) -> Progress:
	if not FileAccess.file_exists(path):
		return Progress.new()
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) == OK and json.data is Dictionary:
		return from_dict(json.data)
	return Progress.new()
