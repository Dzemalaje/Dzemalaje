class_name Obstacles
extends RefCounted
## Spawning and per-turn behavior of board obstacles.

enum Kind { ICE, STONE, CHOCOLATE, COUNTDOWN }

const KIND_NAMES := ["Ice", "Stone", "Chocolate", "Countdown Bomb"]
## Never cover more than this share of the board with obstacles.
const MAX_COVERAGE := 0.4
const CHOCOLATE_DAMAGE_THRESHOLD := 10


## Places up to `count` obstacles of `kind` on plain candy cells.
## Returns the positions used.
static func spawn(board: Board, rng: RandomNumberGenerator, kind: int, count: int,
		countdown_turns: int = 6, strength: int = 1) -> Array:
	var placed: Array = []
	var cap := int(board.width * board.height * MAX_COVERAGE)
	for i in count:
		if kind != Kind.COUNTDOWN and board.obstacle_count() >= cap:
			break
		var spots := _candidate_cells(board, kind)
		if spots.is_empty():
			break
		var p: Vector2i = spots[rng.randi_range(0, spots.size() - 1)]
		var c := board.at(p)
		match kind:
			Kind.ICE:
				c.ice = clampi(strength, 1, 2)
			Kind.STONE:
				c.set_blocker(Cell.Blocker.STONE, clampi(strength, 1, 2))
			Kind.CHOCOLATE:
				c.set_blocker(Cell.Blocker.CHOCOLATE, 1)
			Kind.COUNTDOWN:
				c.countdown = countdown_turns
		placed.append(p)
	return placed


static func _candidate_cells(board: Board, kind: int) -> Array:
	var out: Array = []
	for p in board.all_positions():
		var c := board.at(p)
		if not c.has_candy() or c.ice > 0 or c.countdown > 0:
			continue
		if c.special != Cell.Special.NONE:
			continue
		if kind == Kind.CHOCOLATE and not _near_edge_or_chocolate(board, p):
			continue
		out.append(p)
	if out.is_empty() and kind == Kind.CHOCOLATE:
		# No edge cells left: allow anywhere.
		for p in board.all_positions():
			var c := board.at(p)
			if c.has_candy() and c.ice == 0 and c.countdown == 0 and c.special == Cell.Special.NONE:
				out.append(p)
	return out


static func _near_edge_or_chocolate(board: Board, p: Vector2i) -> bool:
	if p.x == 0 or p.y == board.height - 1 or p.x == board.width - 1:
		return true
	for d in Board.DIRS:
		var q: Vector2i = p + d
		if board.in_bounds(q) and board.at(q).blocker == Cell.Blocker.CHOCOLATE:
			return true
	return false


## Chocolate grows into one neighbouring candy. Returns the new cell or (-1,-1).
static func spread_chocolate(board: Board, rng: RandomNumberGenerator) -> Vector2i:
	var targets: Array = []
	for p in board.all_positions():
		if board.at(p).blocker != Cell.Blocker.CHOCOLATE:
			continue
		for d in Board.DIRS:
			var q: Vector2i = p + d
			if board.in_bounds(q):
				var c := board.at(q)
				if c.has_candy() and c.ice == 0 and c.special == Cell.Special.NONE and c.countdown == 0:
					targets.append(q)
	if targets.is_empty():
		return Vector2i(-1, -1)
	if board.obstacle_count() >= int(board.width * board.height * MAX_COVERAGE):
		return Vector2i(-1, -1)
	var q: Vector2i = targets[rng.randi_range(0, targets.size() - 1)]
	board.at(q).set_blocker(Cell.Blocker.CHOCOLATE, 1)
	return q


## Ticks every countdown bomb. Returns positions that exploded this turn.
static func tick_countdowns(board: Board) -> Array:
	var exploded: Array = []
	for p in board.all_positions():
		var c := board.at(p)
		if c.has_candy() and c.countdown > 0:
			c.countdown -= 1
			if c.countdown == 0:
				exploded.append(p)
	return exploded
