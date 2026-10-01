class_name MatchFinder
extends RefCounted
## Finds match groups. Horizontal and vertical runs that share a cell are
## merged into one group so L and T shapes can be detected.


## Returns an Array of groups. Each group is a Dictionary:
##   cells: Array[Vector2i], color: int, max_len: int,
##   has_h: bool, has_v: bool, cross: Vector2i (shared cell for L/T, or (-1,-1)),
##   longest: Array[Vector2i] (cells of the longest run)
static func find_groups(board: Board) -> Array:
	var runs: Array = []
	for horizontal in [true, false]:
		var outer: int = board.height if horizontal else board.width
		var inner: int = board.width if horizontal else board.height
		for o in outer:
			var i := 0
			while i < inner:
				var p := Vector2i(i, o) if horizontal else Vector2i(o, i)
				var c := board.at(p)
				if not c.can_match():
					i += 1
					continue
				var run_cells: Array[Vector2i] = [p]
				var j := i + 1
				while j < inner:
					var q := Vector2i(j, o) if horizontal else Vector2i(o, j)
					var cq := board.at(q)
					if not cq.can_match() or cq.color != c.color:
						break
					run_cells.append(q)
					j += 1
				if run_cells.size() >= 3:
					runs.append({"cells": run_cells, "horizontal": horizontal, "color": c.color})
				i = j

	# Union runs that share any cell.
	var parent: Array[int] = []
	for k in runs.size():
		parent.append(k)
	var owner := {}
	for k in runs.size():
		for p in runs[k].cells:
			if owner.has(p):
				_union(parent, owner[p], k)
			else:
				owner[p] = k

	var by_root := {}
	for k in runs.size():
		var r := _find(parent, k)
		if not by_root.has(r):
			by_root[r] = []
		by_root[r].append(runs[k])

	var groups: Array = []
	for r in by_root:
		var group_runs: Array = by_root[r]
		var seen := {}
		var counts := {}
		var cells: Array[Vector2i] = []
		var has_h := false
		var has_v := false
		var longest: Array = []
		for run in group_runs:
			if run.horizontal:
				has_h = true
			else:
				has_v = true
			if run.cells.size() > longest.size():
				longest = run.cells
			for p in run.cells:
				counts[p] = counts.get(p, 0) + 1
				if not seen.has(p):
					seen[p] = true
					cells.append(p)
		var cross := Vector2i(-1, -1)
		for p in counts:
			if counts[p] > 1:
				cross = p
				break
		groups.append({
			"cells": cells,
			"color": group_runs[0].color,
			"max_len": longest.size(),
			"has_h": has_h,
			"has_v": has_v,
			"cross": cross,
			"longest": longest,
			"longest_horizontal": _is_horizontal(longest),
		})
	return groups


## Which special a group creates, before upgrade modifiers.
static func special_for(group: Dictionary) -> int:
	if group.max_len >= 5:
		return Cell.Special.COLOR_BOMB
	if group.has_h and group.has_v:
		return Cell.Special.BOMB
	if group.max_len == 4:
		return Cell.Special.STRIPED_H if group.longest_horizontal else Cell.Special.STRIPED_V
	return Cell.Special.NONE


## Where the created special appears: the swapped cell if it's in the group,
## then the L/T corner, then the middle of the longest run. Iced cells keep
## their candy, so they can't host a new special.
static func spawn_position(board: Board, group: Dictionary, preferred: Array) -> Vector2i:
	var candidates: Array = []
	for p in preferred:
		if group.cells.has(p):
			candidates.append(p)
	if group.cross != Vector2i(-1, -1):
		candidates.append(group.cross)
	var longest: Array = group.longest
	if not longest.is_empty():
		candidates.append(longest[longest.size() / 2])
	candidates.append_array(group.cells)
	for p in candidates:
		if board.at(p).ice == 0:
			return p
	return Vector2i(-1, -1)


static func _is_horizontal(run_cells: Array) -> bool:
	return run_cells.size() >= 2 and run_cells[0].y == run_cells[1].y


static func _find(parent: Array[int], k: int) -> int:
	while parent[k] != k:
		parent[k] = parent[parent[k]]
		k = parent[k]
	return k


static func _union(parent: Array[int], a: int, b: int) -> void:
	var ra := _find(parent, a)
	var rb := _find(parent, b)
	if ra != rb:
		parent[rb] = ra
