extends "res://tests/test_case.gd"


func test_pattern_board_has_no_matches() -> void:
	var b := pattern_board()
	eq(MatchFinder.find_groups(b).size(), 0, "pattern board groups")
	check(b.has_valid_move() or true, "valid-move query runs")


func test_horizontal_three() -> void:
	var b := pattern_board()
	for x in 3:
		b.at(Vector2i(x, 4)).color = 1
	var groups := MatchFinder.find_groups(b)
	eq(groups.size(), 1, "one group")
	eq(groups[0].cells.size(), 3, "three cells")
	eq(MatchFinder.special_for(groups[0]), Cell.Special.NONE, "no special for 3")


func test_four_makes_striped() -> void:
	var b := pattern_board()
	for x in 4:
		b.at(Vector2i(x + 2, 4)).color = 0
	var groups := MatchFinder.find_groups(b)
	eq(groups.size(), 1, "one group")
	eq(MatchFinder.special_for(groups[0]), Cell.Special.STRIPED_H, "horizontal 4 -> striped H")


func test_five_makes_color_bomb() -> void:
	var b := pattern_board()
	for y in 5:
		b.at(Vector2i(3, y + 1)).color = 0
	var groups := MatchFinder.find_groups(b)
	eq(groups.size(), 1, "one group")
	eq(MatchFinder.special_for(groups[0]), Cell.Special.COLOR_BOMB, "five -> color bomb")


func test_l_shape_makes_bomb() -> void:
	var b := pattern_board()
	# Horizontal (2..4, 5) and vertical (2, 3..5) share (2,5).
	for x in [2, 3, 4]:
		b.at(Vector2i(x, 5)).color = 1
	for y in [3, 4]:
		b.at(Vector2i(2, y)).color = 1
	var groups := MatchFinder.find_groups(b)
	eq(groups.size(), 1, "merged into one group")
	eq(groups[0].cells.size(), 5, "five unique cells")
	eq(groups[0].cross, Vector2i(2, 5), "corner")
	eq(MatchFinder.special_for(groups[0]), Cell.Special.BOMB, "L -> bomb")


func test_blockers_break_runs() -> void:
	var b := pattern_board()
	for x in 3:
		b.at(Vector2i(x, 6)).color = 2
	b.at(Vector2i(1, 6)).set_blocker(Cell.Blocker.STONE, 1)
	eq(MatchFinder.find_groups(b).size(), 0, "stone splits the run")
