class_name SkillTreeView
extends Control
## The five upgrade branches as columns. Capstones unlock after two ranks in
## their branch. Tap a node to read what it does.

signal closed

const TOP := 150.0
const COL_W := 132.0
const NODE := Vector2(118, 118)
const ROW_GAP := 140.0
const LEFT := 30.0

var run: RunState
var _selected: String = ""
var _close_btn: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiKit.theme()
	_close_btn = UiKit.button("Close", _on_close, 300)
	_close_btn.position = Vector2(210, 1170)
	_close_btn.size = Vector2(300, 76)
	add_child(_close_btn)
	hide()


func _on_close() -> void:
	hide()
	closed.emit()


func open(r: RunState) -> void:
	run = r
	_selected = ""
	show()
	queue_redraw()


func _node_rect(branch: int, row: int) -> Rect2:
	var x := LEFT + branch * COL_W + (COL_W - NODE.x) / 2
	return Rect2(Vector2(x, TOP + 80 + row * ROW_GAP), NODE)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for b in 5:
			var ids := UpgradeDB.ids_in_branch(b)
			for row in ids.size():
				if _node_rect(b, row).has_point(event.position):
					_selected = ids[row]
					queue_redraw()
					return


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.01, 0.1, 0.94))
	if run == null:
		return
	Palette.text(self, Vector2(0, 70), "Skill Tree", 46, Palette.ACCENT, HORIZONTAL_ALIGNMENT_CENTER, size.x, true)
	Palette.text(self, Vector2(0, 112), "Capstones unlock after %d ranks in their branch" % UpgradeDB.CAPSTONE_REQUIREMENT, 20,
		Palette.MUTED, HORIZONTAL_ALIGNMENT_CENTER, size.x)
	for b in 5:
		var cx := LEFT + b * COL_W + COL_W / 2
		var bcol: Color = Palette.BRANCH_COLORS[b]
		Palette.draw_branch_icon(self, Vector2(cx, TOP + 26), 26, b)
		Palette.text(self, Vector2(cx - COL_W / 2, TOP + 74), Palette.BRANCH_SHORT[b], 18, bcol, HORIZONTAL_ALIGNMENT_CENTER, COL_W, true)
		var ids := UpgradeDB.ids_in_branch(b)
		# Connector line down the column.
		var first := _node_rect(b, 0).get_center()
		var last := _node_rect(b, ids.size() - 1).get_center()
		draw_line(first, last, Color(bcol, 0.35), 6.0)
		for row in ids.size():
			_draw_node(ids[row], _node_rect(b, row), bcol)
	_draw_details()


func _draw_node(id: String, rect: Rect2, bcol: Color) -> void:
	var rank := run.mods.rank(id)
	var maxr := UpgradeDB.max_rank(id)
	var unlocked := run.mods.is_unlocked(id)
	var bg := Color("2a1838")
	if rank > 0:
		bg = bcol.darkened(0.55 - 0.12 * rank)
	Palette.fill_rounded(self, rect, 20, bg)
	var border := bcol if rank > 0 else (Color("6a5878") if unlocked else Color("3a3040"))
	if id == _selected:
		border = Color.WHITE
	Palette.outline(self, Palette.rounded_rect_points(rect, 20), border, 4.0 if id == _selected else 3.0)
	var title: String = UpgradeDB.get_def(id).name
	var lines := Palette.wrap_lines(title, 17, rect.size.x - 12)
	var text_col := Palette.TEXT if unlocked else Color("7a6a88")
	for i in lines.size():
		Palette.text(self, rect.position + Vector2(0, 34 + i * 22), lines[i], 17, text_col, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, true)
	if not unlocked:
		_draw_lock(rect.position + Vector2(rect.size.x / 2, 88))
	else:
		var pip_w := 14.0
		var total := maxr * pip_w + (maxr - 1) * 6
		for i in maxr:
			var pc := rect.position + Vector2((rect.size.x - total) / 2 + i * (pip_w + 6) + pip_w / 2, 94)
			draw_colored_polygon(Palette.circle_points(pc, 6, 12), Palette.GOLD if i < rank else Color("4a3a58"))
	if UpgradeDB.is_capstone(id):
		Palette.draw_branch_icon(self, rect.position + Vector2(rect.size.x - 8, 8), 12, UpgradeDB.get_def(id).branch, not unlocked)


func _draw_lock(c: Vector2) -> void:
	draw_arc(c + Vector2(0, -6), 8, PI, TAU, 12, Color("7a6a88"), 3.0)
	Palette.fill_rounded(self, Rect2(c + Vector2(-11, -6), Vector2(22, 16)), 4, Color("7a6a88"))


func _draw_details() -> void:
	var box := Rect2(24, 926, 672, 222)
	Palette.fill_rounded(self, box, 22, Palette.PANEL_LIGHT)
	if _selected.is_empty():
		Palette.text(self, box.position + Vector2(0, 112), "Tap a skill to see what it does", 22, Palette.MUTED,
			HORIZONTAL_ALIGNMENT_CENTER, box.size.x)
		return
	var d := UpgradeDB.get_def(_selected)
	var rank := run.mods.rank(_selected)
	var maxr := UpgradeDB.max_rank(_selected)
	Palette.text(self, box.position + Vector2(24, 44), d.name, 30, Palette.BRANCH_COLORS[d.branch], HORIZONTAL_ALIGNMENT_LEFT, -1, true)
	Palette.text(self, box.position + Vector2(24, 44), "Rank %d / %d" % [rank, maxr], 22, Palette.GOLD,
		HORIZONTAL_ALIGNMENT_RIGHT, box.size.x - 48, true)
	var lines := Palette.wrap_lines(d.desc, 22, box.size.x - 48)
	for i in lines.size():
		Palette.text(self, box.position + Vector2(24, 84 + i * 28), lines[i], 22, Palette.TEXT)
	var now := "%s: %s" % [d.label, UpgradeDB.format_value(_selected, rank)]
	if rank < maxr:
		now = UpgradeDB.preview(_selected, rank)
	Palette.text(self, box.position + Vector2(24, 150), now, 22, Palette.ACCENT, HORIZONTAL_ALIGNMENT_LEFT, -1, true)
	if not run.mods.is_unlocked(_selected):
		Palette.text(self, box.position + Vector2(24, 186), "Locked: needs %d ranks in %s" % [
			UpgradeDB.CAPSTONE_REQUIREMENT, UpgradeDB.BRANCH_NAMES[d.branch]], 20, Palette.HP_LOW)
