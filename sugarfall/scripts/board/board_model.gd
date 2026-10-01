class_name Board
extends RefCounted
## Grid of cells plus the queries the resolver, bosses and views need.
## Pure data: no nodes, so it can be tested headless.

const DIRS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

var width: int
var height: int
var num_colors: int
var rng: RandomNumberGenerator
var cells: Array[Cell] = []


func _init(p_rng: RandomNumberGenerator, p_width: int = 8, p_height: int = 8, p_colors: int = 6) -> void:
	rng = p_rng
	width = p_width
	height = p_height
	num_colors = p_colors
	cells.resize(width * height)
	for i in cells.size():
		cells[i] = Cell.new()


func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < width and p.y < height


func at(p: Vector2i) -> Cell:
	return cells[p.y * width + p.x]


func all_positions() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in height:
		for x in width:
			out.append(Vector2i(x, y))
	return out


func random_color() -> int:
	return rng.randi_range(0, num_colors - 1)


## Fills every empty, non-blocked cell with colors that create no matches.
func fill_initial() -> void:
	for p in all_positions():
		var c := at(p)
		if c.blocker != Cell.Blocker.NONE or c.color != Cell.EMPTY:
			continue
		var options: Array[int] = []
		for col in num_colors:
			if not _would_start_match(p, col):
				options.append(col)
		c.color = options[rng.randi_range(0, options.size() - 1)] if not options.is_empty() else random_color()


func _would_start_match(p: Vector2i, col: int) -> bool:
	for d in [Vector2i.LEFT, Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN]:
		var a: Vector2i = p + d
		var b: Vector2i = p + d * 2
		if in_bounds(a) and in_bounds(b) and at(a).can_match() and at(b).can_match() \
				and at(a).color == col and at(b).color == col:
			return true
	return false


func run_length(p: Vector2i, horizontal: bool) -> int:
	var c := at(p)
	if not c.can_match():
		return 0
	var step := Vector2i.RIGHT if horizontal else Vector2i.DOWN
	var n := 1
	var q := p - step
	while in_bounds(q) and at(q).can_match() and at(q).color == c.color:
		n += 1
		q -= step
	q = p + step
	while in_bounds(q) and at(q).can_match() and at(q).color == c.color:
		n += 1
		q += step
	return n


func has_match_at(p: Vector2i) -> bool:
	return run_length(p, true) >= 3 or run_length(p, false) >= 3


func has_any_match() -> bool:
	for p in all_positions():
		if has_match_at(p):
			return true
	return false


static func are_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return absi(a.x - b.x) + absi(a.y - b.y) == 1


## True when the player is allowed to try swapping these cells at all
## (whether or not the swap produces a match).
func can_attempt(a: Vector2i, b: Vector2i) -> bool:
	return in_bounds(a) and in_bounds(b) and are_adjacent(a, b) and at(a).can_swap() and at(b).can_swap()


## Swaps candy contents only; ice and blockers stay put.
func swap(a: Vector2i, b: Vector2i) -> void:
	var ca := at(a)
	var cb := at(b)
	var t_color := ca.color
	var t_special := ca.special
	var t_countdown := ca.countdown
	ca.color = cb.color
	ca.special = cb.special
	ca.countdown = cb.countdown
	cb.color = t_color
	cb.special = t_special
	cb.countdown = t_countdown


func is_valid_swap(a: Vector2i, b: Vector2i) -> bool:
	if not can_attempt(a, b):
		return false
	var ca := at(a)
	var cb := at(b)
	if ca.special == Cell.Special.COLOR_BOMB or cb.special == Cell.Special.COLOR_BOMB:
		return true
	if ca.special != Cell.Special.NONE and cb.special != Cell.Special.NONE:
		return true
	swap(a, b)
	var ok := has_match_at(a) or has_match_at(b)
	swap(a, b)
	return ok


func find_valid_moves(limit: int = -1) -> Array:
	var moves: Array = []
	for p in all_positions():
		for d in [Vector2i.RIGHT, Vector2i.DOWN]:
			var q: Vector2i = p + d
			if is_valid_swap(p, q):
				moves.append([p, q])
				if limit > 0 and moves.size() >= limit:
					return moves
	return moves


func has_valid_move() -> bool:
	return not find_valid_moves(1).is_empty()


func count_color(col: int) -> int:
	var n := 0
	for c in cells:
		if c.can_match() and c.color == col:
			n += 1
	return n


## Colors sorted from most to least common on the board.
func colors_by_count() -> Array[int]:
	var cols: Array[int] = []
	for col in num_colors:
		cols.append(col)
	var counts := {}
	for col in cols:
		counts[col] = count_color(col)
	cols.sort_custom(func(x: int, y: int) -> bool: return counts[x] > counts[y])
	return cols


func count_blocker(kind: int) -> int:
	var n := 0
	for c in cells:
		if c.blocker == kind:
			n += 1
	return n


func obstacle_count() -> int:
	var n := 0
	for c in cells:
		if c.blocker == Cell.Blocker.STONE or c.blocker == Cell.Blocker.CHOCOLATE or c.ice > 0:
			n += 1
	return n


func snapshot() -> Array:
	var out: Array = []
	for c in cells:
		out.append(c.to_dict())
	return out


## Shuffles the swappable candies until the board has no standing match and at
## least one valid move. Returns false if it could not find such a layout.
func shuffle_candies(tries: int = 60) -> bool:
	var spots: Array[Vector2i] = []
	for p in all_positions():
		if at(p).can_swap():
			spots.append(p)
	if spots.size() < 3:
		return false
	var contents: Array = []
	for p in spots:
		var c := at(p)
		contents.append([c.color, c.special, c.countdown])
	for attempt in tries:
		# Fisher-Yates with the run RNG so results stay deterministic per seed.
		for i in range(contents.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var t = contents[i]
			contents[i] = contents[j]
			contents[j] = t
		for i in spots.size():
			var c := at(spots[i])
			c.color = contents[i][0]
			c.special = contents[i][1]
			c.countdown = contents[i][2]
		if not has_any_match() and has_valid_move():
			return true
		# After a few failed layouts, recolor plain candies to break deadlocks
		# caused by too few colors among the swappable cells.
		if attempt > tries / 2:
			for i in contents.size():
				if contents[i][1] == Cell.Special.NONE:
					contents[i][0] = random_color()
	return false


## Guarantees the board is playable: reshuffles, and if that fails, strips
## obstacles until a layout works. Returns true if anything changed.
func ensure_playable() -> bool:
	if has_valid_move() and not has_any_match():
		return false
	for _round in 8:
		if shuffle_candies():
			return true
		_strip_obstacles(3)
	return true


func _strip_obstacles(count: int) -> void:
	var spots: Array[Vector2i] = []
	for p in all_positions():
		var c := at(p)
		if c.blocker == Cell.Blocker.STONE or c.blocker == Cell.Blocker.CHOCOLATE or c.ice > 0:
			spots.append(p)
	for i in mini(count, spots.size()):
		var k := rng.randi_range(0, spots.size() - 1)
		var c := at(spots[k])
		spots.remove_at(k)
		if c.blocker != Cell.Blocker.NONE:
			c.remove_blocker()
			c.color = random_color()
		else:
			c.ice = 0
