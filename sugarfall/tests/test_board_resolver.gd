extends "res://tests/test_case.gd"


func test_invalid_swap_changes_nothing() -> void:
	var b := pattern_board()
	var before := b.snapshot()
	var res := resolver_for(b).resolve_swap(Vector2i(0, 0), Vector2i(1, 0))
	eq(res.valid, false, "invalid swap")
	eq(b.snapshot(), before, "board unchanged")


func test_basic_swap_clears_and_refills() -> void:
	var b := swap_ready_board()
	check(b.is_valid_swap(Vector2i(2, 0), Vector2i(3, 0)), "swap is valid")
	var res := resolver_for(b).resolve_swap(Vector2i(2, 0), Vector2i(3, 0))
	eq(res.valid, true, "valid swap")
	check(res.steps.size() >= 1, "at least one step")
	var first := cleared_positions(res.steps[0])
	for x in 3:
		check(first.has(Vector2i(x, 0)), "cleared (%d,0)" % x)
	check(board_is_full(b), "board refilled")
	eq(MatchFinder.find_groups(b).size(), 0, "no standing matches after cascade")
	check(res.summary.score > 0, "scored")


func test_striped_clears_row() -> void:
	var b := swap_ready_board()
	b.at(Vector2i(1, 0)).special = Cell.Special.STRIPED_H
	var res := resolver_for(b).resolve_swap(Vector2i(2, 0), Vector2i(3, 0))
	var first := cleared_positions(res.steps[0])
	for x in 8:
		check(first.has(Vector2i(x, 0)), "row cell (%d,0) cleared" % x)


func test_bomb_clears_square() -> void:
	var b := swap_ready_board()
	b.at(Vector2i(1, 0)).special = Cell.Special.BOMB
	var res := resolver_for(b).resolve_swap(Vector2i(2, 0), Vector2i(3, 0))
	var first := cleared_positions(res.steps[0])
	for p in [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]:
		check(first.has(p), "bomb reached %s" % p)
	check(not first.has(Vector2i(1, 2)), "radius 1 stops at row 1")


func test_bigger_blast_radius() -> void:
	var b := swap_ready_board()
	b.at(Vector2i(1, 0)).special = Cell.Special.BOMB
	var mods := Modifiers.new()
	mods.ranks["bigger_blast"] = 1
	var res := resolver_for(b, mods).resolve_swap(Vector2i(2, 0), Vector2i(3, 0))
	check(cleared_positions(res.steps[0]).has(Vector2i(3, 2)), "radius 2 reaches (3,2)")


func test_color_bomb_swap_clears_color() -> void:
	var b := pattern_board()
	b.at(Vector2i(3, 0)).color = Cell.NO_COLOR
	b.at(Vector2i(3, 0)).special = Cell.Special.COLOR_BOMB
	var target := b.at(Vector2i(3, 1)).color
	var expected := b.count_color(target)
	var res := resolver_for(b).resolve_swap(Vector2i(3, 0), Vector2i(3, 1))
	eq(res.valid, true, "color bomb swap is always valid")
	var removed := 0
	for e in res.steps[0].cleared:
		if e.color == target:
			removed += 1
	eq(removed, expected, "every candy of the target color cleared")
	check(board_is_full(b), "board refilled")


func test_ice_absorbs_match() -> void:
	var b := swap_ready_board()
	b.at(Vector2i(0, 0)).ice = 1
	check(b.is_valid_swap(Vector2i(2, 0), Vector2i(3, 0)), "iced candy still matches")
	var res := resolver_for(b).resolve_swap(Vector2i(2, 0), Vector2i(3, 0))
	eq(b.at(Vector2i(0, 0)).ice, 0, "ice layer removed")
	var entry: Dictionary = {}
	for e in res.steps[0].cleared:
		if e.pos == Vector2i(0, 0):
			entry = e
	eq(entry.get("removed"), false, "iced candy stays")
	eq(res.summary.ice_broken, 1, "ice counted")


func test_iced_candy_cannot_swap() -> void:
	var b := swap_ready_board()
	b.at(Vector2i(3, 0)).ice = 1
	check(not b.can_attempt(Vector2i(2, 0), Vector2i(3, 0)), "iced candy locked")


func test_stone_next_to_match_breaks() -> void:
	var b := swap_ready_board()
	b.at(Vector2i(0, 1)).set_blocker(Cell.Blocker.STONE, 1)
	var res := resolver_for(b).resolve_swap(Vector2i(2, 0), Vector2i(3, 0))
	check(res.summary.obstacles_destroyed >= 1, "stone destroyed")
	check(res.steps[0].obstacle_hits.has(Vector2i(0, 1)), "hit recorded")
	check(board_is_full(b), "hole refilled")


func test_boss_adjacent_hits() -> void:
	var b := swap_ready_board()
	b.at(Vector2i(1, 1)).set_blocker(Cell.Blocker.BOSS, 0)
	b.at(Vector2i(2, 1)).set_blocker(Cell.Blocker.BOSS, 0)
	var res := resolver_for(b).resolve_swap(Vector2i(2, 0), Vector2i(3, 0))
	check(res.summary.boss_adjacent >= 2, "two cleared cells touch the boss")
	eq(b.at(Vector2i(1, 1)).blocker, Cell.Blocker.BOSS, "boss cells untouched")


func test_candies_fall_past_fixed_cells() -> void:
	var b := swap_ready_board()
	b.at(Vector2i(0, 3)).set_blocker(Cell.Blocker.STONE, 2)
	b.at(Vector2i(1, 2)).ice = 2
	resolver_for(b).resolve_swap(Vector2i(2, 0), Vector2i(3, 0))
	check(board_is_full(b), "full with fixed cells present")
	eq(b.at(Vector2i(0, 3)).blocker, Cell.Blocker.STONE, "far stone stays")
	eq(b.at(Vector2i(1, 2)).ice, 2, "far ice stays")


func test_combo_multiplier_grows() -> void:
	var r := resolver_for(pattern_board())
	eq(r.combo_multiplier(1), 1.0, "first step x1")
	eq(r.combo_multiplier(3), 2.0, "third step x2")


func test_settle_fills_holes() -> void:
	var b := pattern_board()
	for p in [Vector2i(3, 3), Vector2i(4, 3), Vector2i(3, 4), Vector2i(4, 4)]:
		b.at(p).clear_candy()
	var r := resolver_for(b)
	var steps := r.settle(r.new_summary())
	check(steps.size() >= 1, "settle produced a step")
	check(board_is_full(b), "holes filled")


func test_full_spectrum_clear() -> void:
	var b := pattern_board()
	var r := resolver_for(b)
	var col := b.colors_by_count()[0]
	var n := b.count_color(col)
	var summary := r.new_summary()
	r.color_clear_most_common(summary)
	check(summary.color_cleared >= n, "cleared every candy of the top color")
	check(board_is_full(b), "refilled")


func test_deterministic_with_seed() -> void:
	var b1 := swap_ready_board(42)
	var b2 := swap_ready_board(42)
	resolver_for(b1).resolve_swap(Vector2i(2, 0), Vector2i(3, 0))
	resolver_for(b2).resolve_swap(Vector2i(2, 0), Vector2i(3, 0))
	eq(b1.snapshot(), b2.snapshot(), "same seed, same result")
