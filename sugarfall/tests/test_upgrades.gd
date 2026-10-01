extends "res://tests/test_case.gd"


func test_db_is_complete() -> void:
	eq(UpgradeDB.all_ids().size(), 25, "25 upgrades")
	for branch in 5:
		var ids := UpgradeDB.ids_in_branch(branch)
		eq(ids.size(), 5, "branch %d has 5" % branch)
		var capstones := 0
		for id in ids:
			if UpgradeDB.is_capstone(id):
				capstones += 1
		eq(capstones, 1, "branch %d has one capstone" % branch)


func test_capstone_needs_two_picks() -> void:
	var m := Modifiers.new()
	check(not m.can_offer("mega_bomb"), "locked at start")
	m.ranks["bigger_blast"] = 1
	check(not m.can_offer("mega_bomb"), "still locked after one")
	m.ranks["double_pop"] = 1
	check(m.can_offer("mega_bomb"), "unlocked after two")


func test_maxed_upgrades_not_offered() -> void:
	var run := RunState.new(3)
	run.mods.ranks["crossfire"] = 1
	for i in 30:
		check(not run.make_offer("boss_reward").has("crossfire"), "maxed crossfire never offered")


func test_offer_is_distinct() -> void:
	var run := RunState.new(5)
	for i in 20:
		var offer := run.make_offer("milestone")
		eq(offer.size(), 3, "three cards")
		var seen := {}
		for id in offer:
			check(not seen.has(id), "no duplicates")
			seen[id] = true


func test_extra_breath_raises_max_hp() -> void:
	var run := RunState.new(1)
	run.choose_upgrade("extra_breath")
	eq(run.max_hp, RunState.START_HP + 15, "max hp +15")
	eq(run.hp, RunState.START_HP + 15, "healed by the same amount")


func test_preview_text() -> void:
	eq(UpgradeDB.preview("bigger_blast", 0), "Bomb radius: 1 -> 2", "int preview")
	eq(UpgradeDB.preview("color_spark", 1), "Color Candy chance: 15% -> 30%", "pct preview")
	eq(UpgradeDB.preview("full_spectrum", 0), "Auto color clear: Off -> every 12 moves", "every preview")


func test_shop_buy_and_discount() -> void:
	var run := RunState.new(9)
	run.coins = 100
	run.open_shop()
	eq(run.shop_items.size(), 4, "3 upgrades + snack")
	var item: Dictionary = run.shop_items[0]
	var price: int = item.price
	check(run.buy(0), "bought")
	eq(run.coins, 100 - price, "paid")
	check(not run.buy(0), "can't buy twice")
	var full := run.price_for("crossfire")
	run.mods.ranks["bargain_hunter"] = 2
	check(run.price_for("crossfire") < full, "bargain hunter discounts")


func test_snack_needs_missing_hp() -> void:
	var run := RunState.new(9)
	run.coins = 100
	run.open_shop()
	var snack := run.shop_items.size() - 1
	check(not run.buy(snack), "full hp: snack refused")
	run.hp = 50
	check(run.buy(snack), "snack bought")
	eq(run.hp, 50 + RunState.SNACK_HEAL, "healed")
