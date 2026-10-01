class_name BoardResolver
extends RefCounted
## Turns a swap into a list of animation steps while mutating the board.
## Each step is: clear -> trigger specials -> damage obstacles/boss ->
## create new specials -> gravity + refill. Steps repeat while matches remain.
##
## Step Dictionary keys:
##   combo, cleared [{pos,color,special,source,removed}], effects [{type,pos,...}],
##   created [{pos,color,special}], moves [{from,to}], spawns [{to,color,order}],
##   obstacle_hits [pos], boss_hits int, score int, snapshot Array

const MAX_STEPS := 60
const BASE_POINTS := 10
const SPECIAL_POINTS := 30

var board: Board
var mods: Modifiers
var rng: RandomNumberGenerator


func _init(p_board: Board, p_mods: Modifiers, p_rng: RandomNumberGenerator) -> void:
	board = p_board
	mods = p_mods
	rng = p_rng


func new_summary() -> Dictionary:
	var by_color: Array[int] = []
	by_color.resize(board.num_colors)
	by_color.fill(0)
	return {
		"cleared": 0,
		"by_color": by_color,
		"color_cleared": 0,
		"specials_created": 0,
		"color_bombs_created": 0,
		"specials_triggered": 0,
		"boss_adjacent": 0,
		"boss_blast": 0,
		"chocolate_destroyed": false,
		"obstacles_destroyed": 0,
		"ice_broken": 0,
		"defused": 0,
		"cascades": 0,
		"score": 0,
	}


func resolve_swap(a: Vector2i, b: Vector2i, summary: Dictionary = {}) -> Dictionary:
	if not board.is_valid_swap(a, b):
		return {"valid": false}
	if summary.is_empty():
		summary = new_summary()
	board.swap(a, b)
	var ca := board.at(a)
	var cb := board.at(b)
	var forced := {}
	var consumed := {}
	var effects: Array = []
	var groups: Array = []
	if ca.special == Cell.Special.COLOR_BOMB and cb.special == Cell.Special.COLOR_BOMB:
		# Two color candies: wipe every candy on the board.
		for p in board.all_positions():
			if board.at(p).has_candy():
				forced[p] = "color"
		consumed[a] = true
		consumed[b] = true
		effects.append({"type": "color", "pos": a, "color": -1})
		summary.specials_triggered += 2
	elif ca.special == Cell.Special.COLOR_BOMB or cb.special == Cell.Special.COLOR_BOMB:
		var bomb_p := a if ca.special == Cell.Special.COLOR_BOMB else b
		var other_p := b if bomb_p == a else a
		forced[bomb_p] = "color"
		consumed[bomb_p] = true
		summary.specials_triggered += 1
		for p in _color_area(board.at(other_p).color, bomb_p, effects):
			forced[p] = "color"
	elif ca.special != Cell.Special.NONE and cb.special != Cell.Special.NONE:
		forced[a] = "match"
		forced[b] = "match"
		groups = MatchFinder.find_groups(board)
	else:
		groups = MatchFinder.find_groups(board)
	return {"valid": true, "steps": _cascade(groups, forced, consumed, [a, b], effects, summary), "summary": summary}


## Clears every candy of the most common color (Full Spectrum), then cascades.
func color_clear_most_common(summary: Dictionary) -> Array:
	var effects: Array = []
	var forced := {}
	var origin := Vector2i(board.width / 2, board.height / 2)
	for p in _color_area(board.colors_by_count()[0], origin, effects):
		forced[p] = "color"
	return _cascade([], forced, {}, [], effects, summary)


## Fills holes (e.g. after a boss leaves the board) and resolves any matches.
func settle(summary: Dictionary) -> Array:
	var grav := _apply_gravity()
	var steps: Array = [{
		"combo": 0, "cleared": [], "effects": [], "created": [],
		"moves": grav.moves, "spawns": grav.spawns, "obstacle_hits": [],
		"boss_hits": 0, "score": 0, "snapshot": board.snapshot(),
	}]
	steps.append_array(_cascade(MatchFinder.find_groups(board), {}, {}, [], [], summary))
	return steps


func combo_multiplier(combo: int) -> float:
	return 1.0 + float(maxi(combo - 1, 0)) * mods.val("combo_starter")


func _cascade(groups: Array, forced: Dictionary, consumed: Dictionary, preferred: Array,
		effects: Array, summary: Dictionary) -> Array:
	var steps: Array = []
	if groups.is_empty() and forced.is_empty():
		return steps
	var combo := 1
	steps.append(_run_step(groups, forced, consumed, preferred, combo, effects, summary))
	while combo < MAX_STEPS:
		groups = MatchFinder.find_groups(board)
		if groups.is_empty():
			break
		combo += 1
		steps.append(_run_step(groups, {}, {}, [], combo, [], summary))
	summary.cascades = maxi(summary.cascades, combo)
	return steps


func _run_step(groups: Array, forced: Dictionary, consumed: Dictionary, preferred: Array,
		combo: int, effects: Array, summary: Dictionary) -> Dictionary:
	var to_clear := {}
	for p in forced:
		to_clear[p] = forced[p]

	# Matches, and which specials they will leave behind.
	var created: Array = []
	var created_at := {}
	for g in groups:
		for p in g.cells:
			if not to_clear.has(p):
				to_clear[p] = "match"
		var sp := _modify_special(MatchFinder.special_for(g))
		if sp == Cell.Special.NONE:
			continue
		var pos := MatchFinder.spawn_position(board, g, preferred)
		if pos.x < 0 or created_at.has(pos):
			continue
		created_at[pos] = true
		created.append({"pos": pos, "special": sp,
			"color": Cell.NO_COLOR if sp == Cell.Special.COLOR_BOMB else g.color})

	# Chain-trigger every special caught in the clear.
	var blast_hits := {}
	var queue: Array = []
	for p in to_clear:
		if _can_trigger(p, consumed):
			queue.append(p)
	while not queue.is_empty():
		var p: Vector2i = queue.pop_front()
		if consumed.has(p):
			continue
		consumed[p] = true
		summary.specials_triggered += 1
		var cell := board.at(p)
		var area: Array = []
		var source := "blast"
		var hits := 1
		match cell.special:
			Cell.Special.STRIPED_H:
				area = _row(p.y)
				effects.append({"type": "row", "pos": p})
			Cell.Special.STRIPED_V:
				area = _col(p.x)
				effects.append({"type": "col", "pos": p})
			Cell.Special.BOMB, Cell.Special.MEGA_BOMB:
				var mega := cell.special == Cell.Special.MEGA_BOMB
				var r := mods.bomb_radius() + (1 if mega else 0)
				area = _square(p, r)
				effects.append({"type": "bomb", "pos": p, "radius": r})
				if mega or mods.has("crossfire"):
					area.append_array(_row(p.y))
					area.append_array(_col(p.x))
					effects.append({"type": "row", "pos": p})
					effects.append({"type": "col", "pos": p})
				if rng.randf() < mods.val("double_pop"):
					hits = 2
					effects.append({"type": "double", "pos": p})
			Cell.Special.COLOR_BOMB:
				area = _color_area(board.colors_by_count()[0], p, effects)
				source = "color"
		for q in area:
			var cq := board.at(q)
			if cq.blocker != Cell.Blocker.NONE:
				blast_hits[q] = blast_hits.get(q, 0) + hits
			elif cq.color != Cell.EMPTY and not to_clear.has(q):
				to_clear[q] = source
				if _can_trigger(q, consumed):
					queue.append(q)

	# Remove candies (iced ones lose a layer instead).
	var points := 0
	var cleared: Array = []
	for p in to_clear:
		var c := board.at(p)
		if c.blocker != Cell.Blocker.NONE or c.color == Cell.EMPTY:
			continue
		var source: String = to_clear[p]
		if c.ice > 0:
			c.ice -= 1
			if c.ice == 0:
				summary.ice_broken += 1
			cleared.append({"pos": p, "color": c.color, "special": c.special, "source": source, "removed": false})
			continue
		summary.cleared += 1
		if c.color >= 0:
			summary.by_color[c.color] += 1
		var pts := BASE_POINTS
		if source == "color":
			summary.color_cleared += 1
			pts = roundi(pts * (1.0 + mods.val("spectrum_surge")))
		if c.countdown > 0:
			summary.defused += 1
		points += pts
		cleared.append({"pos": p, "color": c.color, "special": c.special, "source": source, "removed": true})
		c.clear_candy()

	# Damage obstacles next to cleared cells, plus anything a blast reached.
	var obstacle_damage := {}
	var boss_hits := 0
	for entry in cleared:
		var touches_boss := false
		for d in Board.DIRS:
			var q: Vector2i = entry.pos + d
			if not board.in_bounds(q):
				continue
			var kind := board.at(q).blocker
			if kind == Cell.Blocker.STONE or kind == Cell.Blocker.CHOCOLATE:
				obstacle_damage[q] = 1
			elif kind == Cell.Blocker.BOSS:
				touches_boss = true
		if touches_boss:
			summary.boss_adjacent += 1
			boss_hits += 1
	for q in blast_hits:
		if board.at(q).blocker == Cell.Blocker.BOSS:
			summary.boss_blast += blast_hits[q]
			boss_hits += blast_hits[q]
		else:
			obstacle_damage[q] = obstacle_damage.get(q, 0) + blast_hits[q]
	var obstacle_hits: Array = []
	for q in obstacle_damage:
		var c := board.at(q)
		c.blocker_hp -= obstacle_damage[q]
		obstacle_hits.append(q)
		if c.blocker_hp <= 0:
			if c.blocker == Cell.Blocker.CHOCOLATE:
				summary.chocolate_destroyed = true
			summary.obstacles_destroyed += 1
			points += BASE_POINTS * 2
			c.remove_blocker()

	# Place newly created specials in their (now empty) cells.
	var placed: Array = []
	for cr in created:
		var c := board.at(cr.pos)
		if c.blocker == Cell.Blocker.NONE and c.ice == 0 and c.color == Cell.EMPTY:
			c.color = cr.color
			c.special = cr.special
			summary.specials_created += 1
			if cr.special == Cell.Special.COLOR_BOMB:
				summary.color_bombs_created += 1
			points += SPECIAL_POINTS
			placed.append(cr)

	var grav := _apply_gravity()

	var mult := combo_multiplier(combo)
	if combo >= 3:
		mult *= 1.0 + mods.val("fever_score")
	var step_score := roundi(points * mult)
	summary.score += step_score

	return {
		"combo": combo,
		"cleared": cleared,
		"effects": effects,
		"created": placed,
		"moves": grav.moves,
		"spawns": grav.spawns,
		"obstacle_hits": obstacle_hits,
		"boss_hits": boss_hits,
		"score": step_score,
		"snapshot": board.snapshot(),
	}


func _can_trigger(p: Vector2i, consumed: Dictionary) -> bool:
	var c := board.at(p)
	return c.special != Cell.Special.NONE and c.ice == 0 and c.blocker == Cell.Blocker.NONE \
		and not consumed.has(p)


func _modify_special(sp: int) -> int:
	if sp == Cell.Special.NONE or sp == Cell.Special.COLOR_BOMB:
		return sp
	if (sp == Cell.Special.STRIPED_H or sp == Cell.Special.STRIPED_V) and rng.randf() < mods.val("color_spark"):
		return Cell.Special.COLOR_BOMB
	if rng.randf() < mods.val("mega_bomb"):
		return Cell.Special.MEGA_BOMB
	return sp


## Positions cleared by a color effect, including Rainbow Echo and Prismatic Link.
func _color_area(col: int, origin: Vector2i, effects: Array) -> Array:
	var area: Array = []
	var targets: Array[int] = [col]
	if rng.randf() < mods.val("rainbow_echo"):
		for other in board.colors_by_count():
			if other != col:
				targets.append(other)
				break
	for t in targets:
		effects.append({"type": "color", "pos": origin, "color": t})
		for p in board.all_positions():
			var c := board.at(p)
			if c.can_match() and c.color == t:
				area.append(p)
	var extra := int(mods.val("prismatic_link"))
	if extra > 0:
		var pool: Array = []
		for p in board.all_positions():
			if board.at(p).has_candy() and not area.has(p):
				pool.append(p)
		for i in mini(extra, pool.size()):
			var k := rng.randi_range(0, pool.size() - 1)
			area.append(pool[k])
			pool.remove_at(k)
	return area


func _row(y: int) -> Array:
	var out: Array = []
	for x in board.width:
		out.append(Vector2i(x, y))
	return out


func _col(x: int) -> Array:
	var out: Array = []
	for y in board.height:
		out.append(Vector2i(x, y))
	return out


func _square(center: Vector2i, r: int) -> Array:
	var out: Array = []
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var q := center + Vector2i(dx, dy)
			if board.in_bounds(q):
				out.append(q)
	return out


## Candies fall past fixed cells (blockers, iced candies) into the lowest free
## slot of their column; new candies fill the top slots.
func _apply_gravity() -> Dictionary:
	var moves: Array = []
	var spawns: Array = []
	for x in board.width:
		var slots: Array[int] = []
		for y in range(board.height - 1, -1, -1):
			if not board.at(Vector2i(x, y)).is_fixed():
				slots.append(y)
		var candies: Array = []
		for y in slots:
			var c := board.at(Vector2i(x, y))
			if c.color != Cell.EMPTY:
				candies.append([y, c.color, c.special, c.countdown])
		var order := 0
		for k in slots.size():
			var p := Vector2i(x, slots[k])
			var c := board.at(p)
			if k < candies.size():
				var src: Array = candies[k]
				c.color = src[1]
				c.special = src[2]
				c.countdown = src[3]
				if src[0] != p.y:
					moves.append({"from": Vector2i(x, src[0]), "to": p})
			else:
				c.special = Cell.Special.NONE
				c.countdown = 0
				c.color = _refill_color(p)
				spawns.append({"to": p, "color": c.color, "order": order})
				order += 1
	return {"moves": moves, "spawns": spawns}


func _refill_color(p: Vector2i) -> int:
	if rng.randf() < mods.val("chain_reaction"):
		for d in [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var q: Vector2i = p + d
			if board.in_bounds(q) and board.at(q).can_match():
				return board.at(q).color
	return board.random_color()
