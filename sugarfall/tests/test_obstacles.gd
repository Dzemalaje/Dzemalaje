extends "res://tests/test_case.gd"


func test_fill_initial_has_no_matches() -> void:
	for s in 20:
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		var b := Board.new(rng)
		b.fill_initial()
		check(board_is_full(b), "seed %d full" % s)
		check(not b.has_any_match(), "seed %d no matches" % s)


func test_spawn_respects_cap() -> void:
	var b := pattern_board()
	var placed := Obstacles.spawn(b, b.rng, Obstacles.Kind.STONE, 64)
	check(placed.size() <= int(64 * Obstacles.MAX_COVERAGE), "cap honoured (%d)" % placed.size())
	eq(b.count_blocker(Cell.Blocker.STONE), placed.size(), "stones placed")


func test_countdown_ticks_and_explodes() -> void:
	var b := pattern_board()
	Obstacles.spawn(b, b.rng, Obstacles.Kind.COUNTDOWN, 1, 2)
	eq(Obstacles.tick_countdowns(b).size(), 0, "first tick")
	eq(Obstacles.tick_countdowns(b).size(), 1, "second tick explodes")


func test_chocolate_spreads() -> void:
	var b := pattern_board()
	b.at(Vector2i(0, 7)).set_blocker(Cell.Blocker.CHOCOLATE, 1)
	var q := Obstacles.spread_chocolate(b, b.rng)
	check(q.x >= 0, "spread somewhere")
	eq(b.count_blocker(Cell.Blocker.CHOCOLATE), 2, "two chocolate cells")


func test_ensure_playable_with_heavy_obstacles() -> void:
	for s in 10:
		var rng := RandomNumberGenerator.new()
		rng.seed = 100 + s
		var b := Board.new(rng)
		b.fill_initial()
		Obstacles.spawn(b, rng, Obstacles.Kind.STONE, 14)
		Obstacles.spawn(b, rng, Obstacles.Kind.ICE, 12)
		b.ensure_playable()
		check(b.has_valid_move(), "seed %d has a move" % s)
		check(not b.has_any_match(), "seed %d stable" % s)
