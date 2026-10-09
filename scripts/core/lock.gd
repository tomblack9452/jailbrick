class_name Lock
extends Brick
## The level's exit: a cell door, grate or gate. Break it to win.
## 1x1 or 2x1, large HP. Shields and chains arrive in Phase 3.


func _init(p_hp := 1, p_col := 0, p_row := 0, p_width := 1) -> void:
	super(Type.LOCK, p_hp, p_col, p_row, p_width)
