extends "res://tests/test_case.gd"
## Auto-plays whole runs and checks invariants after every move.

const SEEDS := [1, 2, 3, 4, 5, 6]
const MAX_MOVES := 600


func _pick_move(run: RunState) -> Array:
	var moves := run.board.find_valid_moves()
	if moves.is_empty():
		return []
	if run.boss != null and run.boss.on_board():
		# Prefer swaps next to the boss so encased bosses actually die.
		var best: Array = moves[0]
		var best_d := 99
		for m in moves:
			for c in run.boss.cells:
				var d: int = mini(absi(m[0].x - c.x) + absi(m[0].y - c.y), absi(m[1].x - c.x) + absi(m[1].y - c.y))
				if d < best_d or (d == best_d and run.rng.randf() < 0.3):
					best_d = d
					best = m
		return best
	return moves[run.rng.randi_range(0, moves.size() - 1)]


func _handle_pending(run: RunState) -> void:
	while not run.pending.is_empty():
		var kind := run.pop_pending()
		if kind == "shop":
			run.open_shop()
			for i in run.shop_items.size():
				run.buy(i)
		else:
			var offer := run.make_offer(kind)
			if not offer.is_empty():
				check(run.choose_upgrade(offer[0]), "offered upgrade can be taken")


func _check_invariants(run: RunState, label: String) -> void:
	var b := run.board
	check(board_is_full(b), "%s board full" % label)
	check(not b.has_any_match(), "%s no standing match" % label)
	check(b.has_valid_move(), "%s has a valid move" % label)
	check(run.hp >= 0 and run.hp <= run.max_hp, "%s hp in range (%d/%d)" % [label, run.hp, run.max_hp])
	check(run.coins >= 0, "%s coins >= 0" % label)
	var boss_cells := b.count_blocker(Cell.Blocker.BOSS)
	if run.boss != null and run.boss.on_board():
		eq(boss_cells, run.boss.size * run.boss.size, "%s boss cells" % label)
	else:
		eq(boss_cells, 0, "%s no stray boss cells" % label)


func test_runs_stay_consistent() -> void:
	var total_bosses := 0
	var total_moves := 0
	for s in SEEDS:
		var run := RunState.new(s)
		var failures_before := failures.size()
		while not run.game_over and run.moves < MAX_MOVES:
			var m := _pick_move(run)
			if m.is_empty():
				check(false, "seed %d: no move available" % s)
				break
			var res := run.play_swap(m[0], m[1])
			check(res.valid, "seed %d: chosen move valid" % s)
			for step in res.steps:
				check(step.combo < BoardResolver.MAX_STEPS, "seed %d: cascade terminated" % s)
			if run.game_over:
				break
			_check_invariants(run, "seed %d move %d" % [s, run.moves])
			_handle_pending(run)
			if failures.size() > failures_before + 5:
				break
		total_bosses += run.bosses_defeated
		total_moves += run.moves
		print("  sim seed %d: moves=%d bosses=%d score=%d hp=%d build=%s" % [
			s, run.moves, run.bosses_defeated, run.score, run.hp, ", ".join(run.build_list())])
	check(total_bosses > 0, "some bosses were defeated across seeds")
	check(total_moves > 100, "runs last a while")


func test_first_boss_arrives_on_schedule() -> void:
	var run := RunState.new(11)
	var moves_played := 0
	while run.boss == null and moves_played < 100:
		var m := _pick_move(run)
		run.play_swap(m[0], m[1])
		run.pending.clear()
		moves_played += 1
	eq(moves_played, RunState.FIRST_BOSS_MOVES, "boss after the calm phase")


func test_lethal_damage_ends_run_or_second_chance() -> void:
	var run := RunState.new(12)
	run.hp = 1
	run.boss = BossFactory.create(1, run.rng, 6)
	run.boss.place(run.board)
	run.boss.attack_timer = 1
	var m := _pick_move(run)
	run.play_swap(m[0], m[1])
	check(run.game_over, "boss attack at 1 HP ends the run")

	var run2 := RunState.new(12)
	run2.mods.ranks["second_chance"] = 1
	run2.hp = 1
	run2.boss = BossFactory.create(1, run2.rng, 6)
	run2.boss.place(run2.board)
	run2.boss.attack_timer = 1
	m = _pick_move(run2)
	run2.play_swap(m[0], m[1])
	check(not run2.game_over, "second chance saves the run")
	eq(run2.hp, 15, "restored HP")
