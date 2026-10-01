extends RefCounted
## Minimal assertion helpers shared by all tests.

var failures: Array[String] = []
var current := ""


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append("%s: %s" % [current, msg])


func eq(actual, expected, msg: String) -> void:
	check(actual == expected, "%s (got %s, expected %s)" % [msg, str(actual), str(expected)])


## 8x8 board with a fixed pattern that has no matches: color = (x + 2y) % 6.
func pattern_board(seed_value: int = 1) -> Board:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var b := Board.new(rng)
	for p in b.all_positions():
		b.at(p).color = (p.x + 2 * p.y) % 6
	return b


## Row 0 becomes [4,4,2,4,4,5,0,1]: swapping (2,0) and (3,0) matches cells 0..2.
func swap_ready_board(seed_value: int = 1) -> Board:
	var b := pattern_board(seed_value)
	var row := [4, 4, 2, 4, 4, 5, 0, 1]
	for x in 8:
		b.at(Vector2i(x, 0)).color = row[x]
	return b


func resolver_for(b: Board, mods: Modifiers = null) -> BoardResolver:
	return BoardResolver.new(b, mods if mods != null else Modifiers.new(), b.rng)


func board_is_full(b: Board) -> bool:
	for c in b.cells:
		if c.blocker == Cell.Blocker.NONE and c.color == Cell.EMPTY:
			return false
	return true


func cleared_positions(step: Dictionary) -> Array:
	var out: Array = []
	for e in step.cleared:
		out.append(e.pos)
	return out
