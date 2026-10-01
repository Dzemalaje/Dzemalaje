extends "res://tests/test_case.gd"


func _rng(s: int = 7) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


func test_boss_kinds_alternate() -> void:
	eq(BossFactory.kind_for(1), Boss.Kind.ENCASED, "boss 1")
	eq(BossFactory.kind_for(2), Boss.Kind.SPAWNER, "boss 2")
	eq(BossFactory.kind_for(3), Boss.Kind.ENCASED, "boss 3")
	eq(BossFactory.kind_for(5), Boss.Kind.HYBRID, "boss 5")
	eq(BossFactory.kind_for(6), Boss.Kind.SPAWNER, "boss 6")


func test_bosses_scale() -> void:
	var r := _rng()
	check(BossFactory.create(3, r, 6).max_hp > BossFactory.create(1, r, 6).max_hp, "encased hp grows")
	check(BossFactory.create(4, r, 6).max_hp > BossFactory.create(2, r, 6).max_hp, "spawner hp grows")
	eq(BossFactory.create(9, r, 6).size, 3, "late bosses are 3x3")


func test_encased_place_and_remove() -> void:
	var b := pattern_board()
	var boss := BossFactory.create(1, _rng(), 6)
	boss.place(b)
	eq(b.count_blocker(Cell.Blocker.BOSS), 4, "2x2 boss cells")
	eq(boss.cells.size(), 4, "boss tracks its cells")
	boss.remove_from(b)
	eq(b.count_blocker(Cell.Blocker.BOSS), 0, "cells freed")


func test_spawner_stays_off_board() -> void:
	var b := pattern_board()
	var boss := BossFactory.create(2, _rng(), 6)
	boss.place(b)
	eq(b.count_blocker(Cell.Blocker.BOSS), 0, "spawner has no cells")


func test_shell_absorbs_first() -> void:
	var boss := BossFactory.create(1, _rng(), 6)
	var shell := boss.shell
	var split := boss.apply_damage(shell + 3)
	eq(split.shell, shell, "shell took its share")
	eq(split.hp, 3, "rest went to hp")
	eq(boss.hp, boss.max_hp - 3, "hp reduced")


func test_encased_damage_needs_contact() -> void:
	var boss := BossFactory.create(1, _rng(), 6)
	var s := BoardResolver.new(pattern_board(), Modifiers.new(), _rng()).new_summary()
	s.cleared = 12
	s.by_color[0] = 12
	eq(boss.damage_from(s, Modifiers.new()), 0.0, "far matches do nothing")
	s.boss_adjacent = 2
	s.boss_blast = 1
	eq(boss.damage_from(s, Modifiers.new()), 2 * Boss.CONTACT_DAMAGE + Boss.BLAST_DAMAGE, "2 contact + 1 blast")


func test_spawner_weak_color_triple() -> void:
	var boss := BossFactory.create(2, _rng(), 6)
	var s := BoardResolver.new(pattern_board(), Modifiers.new(), _rng()).new_summary()
	s.by_color[boss.weak_color] = 3
	eq(boss.damage_from(s, Modifiers.new()), 9.0, "weak color x3")


func test_attack_and_spawn_timers() -> void:
	var b := pattern_board()
	var r := _rng()
	var boss := BossFactory.create(2, r, 6)
	var attacks := 0
	var spawns := 0
	for i in boss.attack_interval:
		for e in boss.end_turn(b, r, 6):
			if e.type == "boss_attack":
				attacks += 1
			elif e.type == "spawn":
				spawns += 1
	eq(attacks, 1, "one attack per interval")
	check(spawns >= 1, "spawner dropped obstacles")
	check(b.obstacle_count() >= 1, "obstacles on board")


func test_enrage_speeds_attacks() -> void:
	var b := pattern_board()
	var r := _rng()
	var boss := BossFactory.create(1, r, 6)
	boss.moves_in_fight = boss.enrage_after
	var attacks := 0
	for i in boss.attack_interval:
		for e in boss.end_turn(b, r, 6):
			if e.type == "boss_attack":
				attacks += 1
	check(attacks >= 2, "enraged boss attacks twice as often")
