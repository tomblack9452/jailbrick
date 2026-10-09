class_name TestLevel
extends RefCounted
## Phase 1's hard-coded level: a 2-wide cell door buried in clumps of bricks,
## with channels and pockets for balls to work into.
## Phase 2 replaces this with LevelData resources in levels/.

const SEED := 1998
const START_BALLS := 5
## Tuned with a throwaway greedy bot: one that samples 7 aims per turn wins
## every seed around turn 11 (the lock hits the danger line on turn 20).
## Random aiming wins about 4 in 10.
const LOCK_HP := 120
const PILE_TOP_ROW := 14
## Brick HP is BRICK_HP + depth * BRICK_HP_PER_ROW, counting depth from the pile top.
const BRICK_HP := 1
const BRICK_HP_PER_ROW := 1

## The starting pile, top row first. '#' brick, 'L' lock, '+' +1 Ball, '.' empty.
const PILE := [
	"..##.......##..",
	".####..+..####.",
	".#..#.....#..#.",
	".####.###.####.",
	"......#........",
	"+.##.#LL.#.##.+",
	"..##.###.###.#.",
	"#...#...#...#..",
]


static func create(seed := SEED) -> TurnController:
	var board := Board.new()
	for depth in PILE.size():
		var row: int = PILE_TOP_ROW + depth
		var line: String = PILE[depth]
		for col in line.length():
			match line[col]:
				"#":
					board.add_brick(Brick.new(Brick.Type.STONE, BRICK_HP + depth * BRICK_HP_PER_ROW, col, row))
				"+":
					board.add_pickup(Pickup.new(Pickup.Type.EXTRA_BALL, col, row))
				"L":
					if board.brick_at(col, row) == null:
						board.add_brick(Lock.new(LOCK_HP, col, row, 2))

	var generator := RowGenerator.new(seed)
	generator.hp_start = 3
	generator.hp_per_turn = 0.5
	return TurnController.new(board, generator, START_BALLS)
