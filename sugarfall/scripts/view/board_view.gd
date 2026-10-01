class_name BoardView
extends Node2D
## Renders the board and plays the resolver's step list as animations.
## Input: drag a candy toward a neighbour, or tap two adjacent candies.

signal swap_requested(a: Vector2i, b: Vector2i)
signal combo_reached(combo: int, at: Vector2)

const CELL := 84.0
const SWAP_TIME := 0.13
const POP_TIME := 0.15
const FALL_TIME_PER_CELL := 0.055
const NONE := Vector2i(-1, -1)

var cols: int = 8
var rows: int = 8
var nodes: Dictionary = {}
var snapshot: Array = []
var boss_ref: Boss = null
var selected: Vector2i = NONE
var input_enabled: bool = false
var time: float = 0.0
var boss_flash: float = 0.0

var _candies: Node2D
var _overlay: BoardOverlay
var _fx: Node2D
var _press_cell: Vector2i = NONE
var _press_pos: Vector2 = Vector2.ZERO
var _pressing: bool = false


func _ready() -> void:
	_candies = Node2D.new()
	add_child(_candies)
	_overlay = BoardOverlay.new()
	_overlay.view = self
	add_child(_overlay)
	_fx = Node2D.new()
	add_child(_fx)


func _process(delta: float) -> void:
	time += delta
	boss_flash = maxf(0.0, boss_flash - delta * 2.5)
	_overlay.queue_redraw()


func board_size() -> Vector2:
	return Vector2(cols, rows) * CELL


func cell_center(p: Vector2i) -> Vector2:
	return Vector2(p.x * CELL + CELL / 2, p.y * CELL + CELL / 2)


func _cell_at(local: Vector2) -> Vector2i:
	var p := Vector2i(floori(local.x / CELL), floori(local.y / CELL))
	return p if p.x >= 0 and p.y >= 0 and p.x < cols and p.y < rows else NONE


func _draw() -> void:
	var size := board_size()
	Palette.fill_rounded(self, Rect2(Vector2(-6, -6), size + Vector2(12, 12)), 26, Color("1c0b28", 0.9))
	for y in rows:
		for x in cols:
			var shade := 0.07 if (x + y) % 2 == 0 else 0.12
			Palette.fill_rounded(self, Rect2(Vector2(x, y) * CELL + Vector2(3, 3), Vector2(CELL - 6, CELL - 6)), 12,
				Color(1, 0.85, 1, shade))


# --- Sync --------------------------------------------------------------------

func reset(board: Board, boss: Boss) -> void:
	for n in nodes.values():
		n.queue_free()
	nodes.clear()
	for c in _fx.get_children():
		c.queue_free()
	cols = board.width
	rows = board.height
	selected = NONE
	boss_ref = boss
	sync_snapshot(board.snapshot())
	queue_redraw()


func sync_snapshot(snap: Array) -> void:
	snapshot = snap
	for i in snap.size():
		var p := Vector2i(i % cols, i / cols)
		var d: Dictionary = snap[i]
		var has_candy: bool = d.blocker == Cell.Blocker.NONE and d.color != Cell.EMPTY
		if has_candy:
			var n: CandyNode = nodes.get(p)
			if n == null:
				n = _make_node(p)
			n.setup(d.color, d.special, d.countdown)
			n.position = cell_center(p)
			n.scale = Vector2.ONE
			n.modulate = Color.WHITE
		elif nodes.has(p):
			nodes[p].queue_free()
			nodes.erase(p)
	_overlay.queue_redraw()


func _make_node(p: Vector2i) -> CandyNode:
	var n := CandyNode.new()
	n.position = cell_center(p)
	_candies.add_child(n)
	nodes[p] = n
	return n


# --- Animations ----------------------------------------------------------------

func animate_swap(a: Vector2i, b: Vector2i) -> void:
	var na: CandyNode = nodes.get(a)
	var nb: CandyNode = nodes.get(b)
	if na == null or nb == null:
		return
	var tw := create_tween().set_parallel()
	tw.tween_property(na, "position", cell_center(b), SWAP_TIME).set_trans(Tween.TRANS_SINE)
	tw.tween_property(nb, "position", cell_center(a), SWAP_TIME).set_trans(Tween.TRANS_SINE)
	await tw.finished
	nodes[a] = nb
	nodes[b] = na


func animate_invalid(a: Vector2i, b: Vector2i) -> void:
	var na: CandyNode = nodes.get(a)
	var nb: CandyNode = nodes.get(b)
	if na == null or nb == null:
		return
	var tw := create_tween()
	tw.tween_property(na, "position", cell_center(b), SWAP_TIME)
	tw.parallel().tween_property(nb, "position", cell_center(a), SWAP_TIME)
	tw.tween_property(na, "position", cell_center(a), SWAP_TIME).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(nb, "position", cell_center(b), SWAP_TIME).set_trans(Tween.TRANS_BACK)
	await tw.finished


func animate_step(step: Dictionary) -> void:
	for e in step.effects:
		_spawn_effect(e)
	if step.boss_hits > 0:
		boss_flash = 1.0

	# Pop cleared candies.
	var pop := create_tween().set_parallel()
	var popping := false
	for c in step.cleared:
		var p: Vector2i = c.pos
		if not c.removed or not nodes.has(p):
			continue
		var n: CandyNode = nodes[p]
		nodes.erase(p)
		pop.tween_property(n, "scale", Vector2(1.35, 1.35), POP_TIME)
		pop.tween_property(n, "modulate:a", 0.0, POP_TIME)
		pop.finished.connect(n.queue_free)
		_sparkle(cell_center(p), Palette.CANDY_COLORS[c.color] if c.color >= 0 else Color.WHITE)
		popping = true
	if popping:
		await pop.finished
	else:
		pop.kill()
	if step.combo >= 2:
		combo_reached.emit(step.combo, global_position + board_size() / 2)

	# New specials pop in where their match was.
	if not step.created.is_empty():
		var grow := create_tween().set_parallel()
		for cr in step.created:
			if nodes.has(cr.pos):
				nodes[cr.pos].queue_free()
			var n := _make_node(cr.pos)
			n.setup(cr.color, cr.special, 0)
			n.scale = Vector2(0.2, 0.2)
			grow.tween_property(n, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK)
		await grow.finished

	# Gravity and refill.
	var fall := create_tween().set_parallel()
	var falling := false
	var moved := {}
	for m in step.moves:
		if nodes.has(m.from):
			moved[m.to] = nodes[m.from]
	for m in step.moves:
		nodes.erase(m.from)
	for to in moved:
		if nodes.has(to) and nodes[to] != moved[to]:
			nodes[to].queue_free()
		nodes[to] = moved[to]
		var n: CandyNode = moved[to]
		var dist := absf(cell_center(to).y - n.position.y) / CELL
		fall.tween_property(n, "position", cell_center(to), FALL_TIME_PER_CELL * dist + 0.08) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		falling = true
	for s in step.spawns:
		if nodes.has(s.to):
			nodes[s.to].queue_free()
		var n := _make_node(s.to)
		n.setup(s.color, Cell.Special.NONE, 0)
		n.position = cell_center(Vector2i(s.to.x, -1 - s.order))
		var dist := float(s.to.y + 1 + s.order)
		fall.tween_property(n, "position", cell_center(s.to), FALL_TIME_PER_CELL * dist + 0.08) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		falling = true
	if falling:
		await fall.finished
	else:
		fall.kill()
	sync_snapshot(step.snapshot)


func _spawn_effect(e: Dictionary) -> void:
	var fx := FxNode.new()
	var c := cell_center(e.pos)
	var w := board_size()
	match e.type:
		"row":
			fx.kind = "row"
			fx.position = Vector2(w.x / 2, c.y)
			fx.extent = Vector2(w.x, CELL * 0.8)
			fx.color = Palette.ACCENT
		"col":
			fx.kind = "col"
			fx.position = Vector2(c.x, w.y / 2)
			fx.extent = Vector2(w.y, CELL * 0.8)
			fx.color = Palette.ACCENT
		"bomb":
			fx.kind = "ring"
			fx.position = c
			fx.radius = CELL * (e.radius + 0.6)
			fx.color = Palette.GOLD
		"color":
			fx.kind = "burst"
			fx.position = c
			fx.radius = CELL * 3.0
		"double":
			fx.kind = "ring"
			fx.position = c
			fx.radius = CELL * 1.2
			fx.color = Color.WHITE
		_:
			fx.queue_free()
			return
	_fx.add_child(fx)
	var tw := fx.create_tween()
	tw.tween_property(fx, "progress", 1.0, 0.35)
	tw.finished.connect(fx.queue_free)


func _sparkle(at: Vector2, col: Color) -> void:
	var fx := FxNode.new()
	fx.kind = "sparkle"
	fx.position = at
	fx.radius = CELL * 0.6
	fx.color = col.lightened(0.3)
	_fx.add_child(fx)
	var tw := fx.create_tween()
	tw.tween_property(fx, "progress", 1.0, 0.3)
	tw.finished.connect(fx.queue_free)


# --- Input ---------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		_pressing = false
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var local := (make_input_local(event) as InputEventMouseButton).position
		if event.pressed:
			var cell := _cell_at(local)
			if cell != NONE:
				_pressing = true
				_press_cell = cell
				_press_pos = local
				get_viewport().set_input_as_handled()
		elif _pressing:
			_pressing = false
			if _press_cell != NONE:
				_tap(_press_cell)
			_press_cell = NONE
	elif event is InputEventMouseMotion and _pressing and _press_cell != NONE:
		var local := (make_input_local(event) as InputEventMouseMotion).position
		var delta := local - _press_pos
		if delta.length() > CELL * 0.35:
			var dir := Vector2i(signi(roundi(delta.x)), 0) if absf(delta.x) > absf(delta.y) else Vector2i(0, signi(roundi(delta.y)))
			var from := _press_cell
			_press_cell = NONE
			selected = NONE
			var to := from + dir
			if to.x >= 0 and to.y >= 0 and to.x < cols and to.y < rows:
				swap_requested.emit(from, to)


func _tap(cell: Vector2i) -> void:
	if selected != NONE and Board.are_adjacent(selected, cell):
		var from := selected
		selected = NONE
		swap_requested.emit(from, cell)
	elif selected == cell:
		selected = NONE
	else:
		selected = cell
