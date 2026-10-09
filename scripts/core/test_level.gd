class_name TestLevel
extends RefCounted
## Phase 1's hard-coded level: a 2-wide cell door buried mid-pile.
## Phase 2 replaces this with LevelData resources in levels/.

const SEED := 1998
const START_BALLS := 6
## Tuned with a throwaway greedy bot: one that samples 7 aims per turn wins
## ~80% of seeds on turn 8-9, with the lock hitting the danger line on turn 10.
## Random aiming almost never wins.
const LOCK_HP := 100
const PILE_TOP_ROW := 5

## Rows of the starting pile, top to bottom. 0 = empty, -1 = lock, -2 = +1 Ball.
const PILE := [
	[ 2,  0,  3,  0, -2,  2,  0],
	[ 0,  4,  0,  5,  4,  0,  3],
	[ 5, -2,  6,  0,  0,  6,  0],
	[ 0,  7,  6,  7,  0,  7,  5],
	[ 8,  6, -1, -1,  8,  0,  8],
	[ 0,  9,  9,  9,  9,  9,  0],
]


static func create(seed := SEED) -> TurnController:
	var board := Board.new()
	for i in PILE.size():
		var row: int = PILE_TOP_ROW + i
		var cells: Array = PILE[i]
		for col in cells.size():
			var value: int = cells[col]
			if value > 0:
				board.add_brick(Brick.new(Brick.Type.STONE, value, col, row))
			elif value == -2:
				board.add_pickup(Pickup.new(Pickup.Type.EXTRA_BALL, col, row))
			elif value == -1 and board.brick_at(col, row) == null:
				board.add_brick(Lock.new(LOCK_HP, col, row, 2))

	var generator := RowGenerator.new(seed)
	generator.fill_chance = 0.5
	generator.hp_start = 4
	generator.hp_per_turn = 1.0
	generator.double_chance = 0.15
	generator.pickup_chance = 0.8
	return TurnController.new(board, generator, START_BALLS)
