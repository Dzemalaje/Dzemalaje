class_name RunState
extends RefCounted
## One endless run: the board, Sugar HP, score, coins, the boss cycle,
## upgrades and the shop. Views call play_swap() and render the result.
##
## play_swap() returns:
##   valid: bool, attempted: bool, steps: Array (board animation steps),
##   events: Array of {type, ...} for the HUD (damage, heal, boss_spawn, ...)

const START_HP := 100
const FIRST_BOSS_MOVES := 20
const MIN_CALM_MOVES := 10
const MILESTONE_BASE := 1500
const COUNTDOWN_TURNS := 6
const STREAK_MAX := 10
const SNACK_ID := "snack"
const SNACK_HEAL := 25
const RARITY_PRICES := [8, 12, 18, 26]
const OFFER_WEIGHTS := {
	"milestone": [60, 30, 9, 3],
	"boss_reward": [25, 35, 25, 15],
	"shop": [40, 35, 18, 7],
}

var rng := RandomNumberGenerator.new()
var seed_value: int = 0
var board: Board
var mods := Modifiers.new()
var resolver: BoardResolver

var hp: int = START_HP
var max_hp: int = START_HP
var score: int = 0
var coins: int = 0
var moves: int = 0
var streak: int = 0
var best_cascade: int = 0

var boss: Boss = null
var bosses_defeated: int = 0
var calm_length: int = FIRST_BOSS_MOVES
var calm_moves_left: int = FIRST_BOSS_MOVES
var milestone_index: int = 0
var next_milestone: int = MILESTONE_BASE
var last_milestone: int = 0
## Queue of screens the player must go through before the next move:
## "boss_reward", "shop", "milestone".
var pending: Array[String] = []
var game_over: bool = false
var second_chance_ready: bool = true
var full_spectrum_timer: int = 0

var shop_items: Array = []
var shop_reroll_cost: int = 3

var _events: Array = []


func _init(p_seed: int = -1) -> void:
	if p_seed < 0:
		rng.randomize()
		seed_value = int(rng.seed)
	else:
		seed_value = p_seed
		rng.seed = p_seed
	board = Board.new(rng)
	board.fill_initial()
	board.ensure_playable()
	resolver = BoardResolver.new(board, mods, rng)


func is_low_hp() -> bool:
	return hp <= max_hp * 0.25


func score_multiplier() -> float:
	var m := 1.0 + 0.1 * streak
	if is_low_hp():
		m *= 1.0 + mods.val("last_hurrah")
	return m


func next_boss_kind() -> int:
	return BossFactory.kind_for(bosses_defeated + 1)


func countdown_turns() -> int:
	return COUNTDOWN_TURNS + int(mods.val("sticky_fuse"))


func countdown_damage() -> int:
	return 5 + 2 * bosses_defeated


# --- Turn flow ---------------------------------------------------------------

func play_swap(a: Vector2i, b: Vector2i) -> Dictionary:
	var result := {"valid": false, "attempted": false, "steps": [], "events": []}
	if game_over or not pending.is_empty() or not board.can_attempt(a, b):
		return result
	result.attempted = true
	_events = result.events
	var summary := resolver.new_summary()
	if not board.is_valid_swap(a, b):
		if rng.randf() < mods.val("efficient_swaps"):
			_events.append({"type": "free_swap"})
			return result
		_break_streak()
		_end_turn(result, summary)
		return result
	result.valid = true
	var res := resolver.resolve_swap(a, b, summary)
	result.steps.append_array(res.steps)
	_apply_summary(summary, result, true)
	if boss != null and boss.is_dead():
		_defeat_boss(result)
	_end_turn(result, summary)
	return result


func _apply_summary(s: Dictionary, result: Dictionary, is_move: bool) -> void:
	var gained := roundi(s.score * score_multiplier())
	score += gained
	best_cascade = maxi(best_cascade, s.cascades)
	if gained > 0:
		_events.append({"type": "score", "amount": gained, "cascades": s.cascades})

	var earned: int = s.specials_created * (1 + int(mods.val("golden_match"))) + s.color_bombs_created * 2
	if is_move and rng.randf() < mods.val("lucky_drop"):
		var drop := rng.randi_range(3, 6)
		earned += drop
		_events.append({"type": "lucky_drop", "amount": drop})
	if earned > 0:
		coins += earned
		_events.append({"type": "coins", "amount": earned})

	if s.cascades >= 4:
		_heal(3 + int(mods.val("sugar_rush")))

	if is_move:
		if s.cascades >= 2:
			streak = mini(streak + 1, STREAK_MAX)
		else:
			_break_streak()

	if boss != null and not boss.is_dead():
		var dmg := boss.damage_from(s, mods)
		if s.cascades >= 4:
			dmg += mods.val("sugar_rush") * 1.5
		if is_low_hp():
			dmg *= 1.0 + mods.val("last_hurrah")
		var amount := roundi(dmg)
		if amount > 0:
			var split := boss.apply_damage(amount)
			_events.append({"type": "boss_damage", "amount": amount, "shell": split.shell, "hp": split.hp})


func _break_streak() -> void:
	streak = floori(streak * mods.val("combo_keeper"))


func _end_turn(result: Dictionary, summary: Dictionary) -> void:
	moves += 1

	var fs_every := int(mods.val("full_spectrum"))
	if fs_every > 0:
		full_spectrum_timer += 1
		if full_spectrum_timer >= fs_every:
			full_spectrum_timer = 0
			var fs_summary := resolver.new_summary()
			result.steps.append_array(resolver.color_clear_most_common(fs_summary))
			_events.append({"type": "full_spectrum"})
			_apply_summary(fs_summary, result, false)
			if boss != null and boss.is_dead():
				_defeat_boss(result)

	for p in Obstacles.tick_countdowns(board):
		_damage(countdown_damage(), "countdown", p)

	var chocolate := board.count_blocker(Cell.Blocker.CHOCOLATE)
	if chocolate > 0 and not summary.chocolate_destroyed:
		var q := Obstacles.spread_chocolate(board, rng)
		if q.x >= 0:
			_events.append({"type": "chocolate_spread", "pos": q})
	if board.count_blocker(Cell.Blocker.CHOCOLATE) > Obstacles.CHOCOLATE_DAMAGE_THRESHOLD:
		_damage(2, "chocolate")

	if boss != null:
		for e in boss.end_turn(board, rng, countdown_turns()):
			if e.type == "boss_attack":
				_damage(e.damage, "boss")
			else:
				_events.append(e)
	else:
		calm_moves_left -= 1
		if bosses_defeated >= 3 and rng.randf() < 0.1 + 0.01 * bosses_defeated:
			var kind := Obstacles.Kind.ICE if rng.randf() < 0.5 else Obstacles.Kind.STONE
			var placed := Obstacles.spawn(board, rng, kind, 1)
			if not placed.is_empty():
				_events.append({"type": "spawn", "kind": kind, "cells": placed})
		if calm_moves_left <= 0:
			_spawn_boss()

	if hp <= 0:
		if second_chance_ready and mods.has("second_chance"):
			second_chance_ready = false
			hp = mini(max_hp, int(mods.val("second_chance")))
			_events.append({"type": "second_chance", "hp": hp})
		else:
			hp = 0
			game_over = true
			_events.append({"type": "game_over"})
			return

	while score >= next_milestone:
		pending.append("milestone")
		milestone_index += 1
		last_milestone = next_milestone
		next_milestone += int(MILESTONE_BASE * pow(1.45, milestone_index))
		_events.append({"type": "milestone"})

	if board.ensure_playable():
		_events.append({"type": "reshuffle"})


func _spawn_boss() -> void:
	boss = BossFactory.create(bosses_defeated + 1, rng, board.num_colors)
	boss.place(board)
	_events.append({"type": "boss_spawn", "name": boss.name, "kind": boss.kind})


func _defeat_boss(result: Dictionary) -> void:
	var b := boss
	boss = null
	bosses_defeated += 1
	var reward := 10 + 3 * b.index
	var bank := maxi(0, b.par_moves - b.moves_in_fight) * int(mods.val("momentum_bank"))
	var interest := mini(int(mods.val("sugar_vault")), floori(coins * mods.val("sweet_interest")))
	coins += reward + bank + interest
	score += 500 * b.index
	_events.append({"type": "boss_defeated", "name": b.name, "reward": reward, "bank": bank,
		"interest": interest, "bonus_score": 500 * b.index})
	_heal(roundi(max_hp * 0.15))
	if b.on_board():
		b.remove_from(board)
		var s := resolver.new_summary()
		result.steps.append_array(resolver.settle(s))
		_apply_summary(s, result, false)
	calm_length = maxi(MIN_CALM_MOVES, 22 - bosses_defeated)
	calm_moves_left = calm_length
	second_chance_ready = true
	pending.append("boss_reward")
	pending.append("shop")


func _damage(amount: int, source: String, pos: Vector2i = Vector2i(-1, -1)) -> void:
	if amount <= 0:
		return
	hp -= amount
	_events.append({"type": "damage", "amount": amount, "source": source, "pos": pos})


func _heal(amount: int) -> void:
	var before := hp
	hp = mini(max_hp, hp + amount)
	if hp > before:
		_events.append({"type": "heal", "amount": hp - before})


# --- Upgrades ----------------------------------------------------------------

func pop_pending() -> String:
	return pending.pop_front() if not pending.is_empty() else ""


## Up to `count` distinct upgrade ids, weighted by rarity for the given source.
func make_offer(source: String, count: int = 3) -> Array[String]:
	var weights: Array = OFFER_WEIGHTS.get(source, OFFER_WEIGHTS.milestone)
	var pool: Array[String] = []
	for id in UpgradeDB.all_ids():
		if mods.can_offer(id):
			pool.append(id)
	var picks: Array[String] = []
	while picks.size() < count and not pool.is_empty():
		var total := 0.0
		for id in pool:
			total += weights[UpgradeDB.get_def(id).rarity]
		var roll := rng.randf() * total
		var chosen := pool[pool.size() - 1]
		for id in pool:
			roll -= weights[UpgradeDB.get_def(id).rarity]
			if roll <= 0.0:
				chosen = id
				break
		picks.append(chosen)
		pool.erase(chosen)
	return picks


func choose_upgrade(id: String) -> bool:
	if not mods.can_offer(id):
		return false
	var old_rank := mods.rank(id)
	mods.ranks[id] = old_rank + 1
	match id:
		"extra_breath":
			var gain := int(UpgradeDB.value(id, old_rank + 1) - UpgradeDB.value(id, old_rank))
			max_hp += gain
			hp += gain
		"sugar_vault":
			coins += 5
	return true


func build_list() -> Array[String]:
	var out: Array[String] = []
	for id in UpgradeDB.all_ids():
		if mods.rank(id) > 0:
			out.append("%s %s" % [UpgradeDB.get_def(id).name, _roman(mods.rank(id))])
	return out


static func _roman(n: int) -> String:
	return ["", "I", "II", "III", "IV"][clampi(n, 0, 4)]


# --- Shop --------------------------------------------------------------------

func open_shop() -> void:
	shop_reroll_cost = 3
	_roll_shop()


func _roll_shop() -> void:
	shop_items.clear()
	for id in make_offer("shop", 3):
		shop_items.append({"id": id, "price": price_for(id), "sold": false})
	shop_items.append({"id": SNACK_ID, "price": _discounted(6), "sold": false})


func price_for(id: String) -> int:
	var base: float = RARITY_PRICES[UpgradeDB.get_def(id).rarity] * (1.0 + 0.25 * mods.rank(id))
	return _discounted(base)


func _discounted(base: float) -> int:
	return maxi(1, roundi(base * (1.0 - mods.val("bargain_hunter"))))


func buy(i: int) -> bool:
	if i < 0 or i >= shop_items.size():
		return false
	var item: Dictionary = shop_items[i]
	if item.sold or coins < item.price:
		return false
	if item.id == SNACK_ID:
		if hp >= max_hp:
			return false
		_events = []
		_heal(SNACK_HEAL)
	elif not choose_upgrade(item.id):
		return false
	coins -= item.price
	item.sold = true
	return true


func reroll_shop() -> bool:
	if coins < shop_reroll_cost:
		return false
	coins -= shop_reroll_cost
	shop_reroll_cost += 1
	_roll_shop()
	return true
