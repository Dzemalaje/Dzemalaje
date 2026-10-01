class_name BoardOverlay
extends Node2D
## Draws obstacles, the encased boss and the selection ring above candies.

var view: BoardView


func _draw() -> void:
	var cell := BoardView.CELL
	var snap: Array = view.snapshot
	if snap.is_empty():
		return
	var cols: int = view.cols
	var boss_rect := Rect2()
	var has_boss := false
	for i in snap.size():
		var d: Dictionary = snap[i]
		var p := Vector2i(i % cols, i / cols)
		var rect := Rect2(Vector2(p) * cell, Vector2(cell, cell)).grow(-2)
		match d.blocker:
			Cell.Blocker.STONE:
				Palette.draw_stone(self, rect, d.blocker_hp)
			Cell.Blocker.CHOCOLATE:
				Palette.draw_chocolate(self, rect)
			Cell.Blocker.BOSS:
				var r := Rect2(Vector2(p) * cell, Vector2(cell, cell))
				boss_rect = r if not has_boss else boss_rect.merge(r)
				has_boss = true
		if d.ice > 0:
			Palette.draw_ice(self, rect, d.ice)
	if has_boss:
		var boss: Boss = view.boss_ref
		var kind := boss.kind if boss != null else Boss.Kind.ENCASED
		var enraged := boss != null and boss.is_enraged()
		var inner := boss_rect.grow(-4)
		Palette.fill_rounded(self, inner, 22, Color("1a0a18", 0.85))
		var shake := Vector2(sin(view.time * 60.0), cos(view.time * 47.0)) * 6.0 * view.boss_flash
		Palette.draw_boss(self, inner.get_center() + shake, inner.size.x * 0.4, kind, enraged, view.time, view.boss_flash)
		if boss != null:
			Palette.draw_cage(self, inner, boss.shell_layers())
	if view.selected.x >= 0:
		var c: Vector2 = view.cell_center(view.selected)
		var pulse := 0.5 + 0.5 * sin(view.time * 8.0)
		draw_arc(c, cell * 0.47, 0, TAU, 40, Color(1, 1, 1, 0.6 + 0.4 * pulse), 4.0, true)
