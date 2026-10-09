class_name Economy
extends RefCounted
## Points, coins and restart prices. Coins are only ever earned by playing
## (points and levels) or from rewarded ads. They're never sold.

const POINTS_PER_COIN := 20
const COINS_PER_LEVEL := 10
const LEVEL_BONUS_POINTS := 50
const START_BALLS := 5
## Extra starting balls per level skipped, roughly the +1 Balls you'd have
## picked up on the way down (the solver bot averages 4-5 a level).
const BALLS_PER_LEVEL := 5


static func coins_for(points: int, levels_cleared: int) -> int:
	return points / POINTS_PER_COIN + levels_cleared * COINS_PER_LEVEL


static func level_bonus(level: int) -> int:
	return LEVEL_BONUS_POINTS * level


## Coins to start a run at `level`. Level 1 is always free.
static func start_cost(level: int) -> int:
	return 25 * (level - 1) * (level + 2)


static func start_balls(level: int) -> int:
	return START_BALLS + BALLS_PER_LEVEL * (level - 1)
