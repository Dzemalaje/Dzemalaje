class_name BossPanel
extends Control
## Shows the current boss (portrait, HP, shell, timers) or the calm countdown.

const RECT := Rect2(12, 160, 696, 278)

var run: RunState
var flash: float = 0.0
var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2.ZERO
	size = Vector2(720, 450)


func refresh(r: RunState) -> void:
	run = r
	queue_redraw()


func portrait_center() -> Vector2:
	return RECT.position + Vector2(118, 150)


func _process(delta: float) -> void:
	_t += delta
	flash = maxf(0.0, flash - delta * 2.5)
	queue_redraw()


func _draw() -> void:
	if run == null:
		return
	var boss := run.boss
	var border := Palette.HP_LOW if boss != null and boss.is_enraged() else Color("ff9fd0", 0.35)
	Palette.fill_rounded(self, RECT, 26, Palette.PANEL)
	Palette.outline(self, Palette.rounded_rect_points(RECT, 26), border, 3.0)
	if boss == null:
		_draw_calm()
	else:
		_draw_boss(boss)


func _draw_calm() -> void:
	var kind := run.next_boss_kind()
	var x := RECT.position.x + 236
	var y := RECT.position.y
	Palette.draw_boss(self, portrait_center(), 70, kind, false, _t, 0.0)
	draw_colored_polygon(Palette.circle_points(portrait_center(), 100), Color(0.1, 0.02, 0.15, 0.55))
	Palette.text(self, Vector2(x, y + 52), "Calm before the storm", 30, Palette.TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, true)
	Palette.text(self, Vector2(x, y + 92), "Boss #%d arrives in %d moves" % [run.bosses_defeated + 1, run.calm_moves_left],
		24, Palette.GOLD)
	var bar := Rect2(x, y + 112, 430, 22)
	Palette.fill_rounded(self, bar, 11, Color("1a0a22"))
	var ratio := 1.0 - float(run.calm_moves_left) / maxf(1.0, run.calm_length)
	if ratio > 0.02:
		Palette.fill_rounded(self, Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), 11, Palette.ACCENT)
	Palette.text(self, Vector2(x, y + 170), "Next: %s boss" % Boss.KIND_NAMES[kind], 22, Palette.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, true)
	var lines := Palette.wrap_lines(_hint(kind), 20, 440)
	for i in lines.size():
		Palette.text(self, Vector2(x, y + 202 + i * 26), lines[i], 20, Palette.MUTED)


func _draw_boss(boss: Boss) -> void:
	var x := RECT.position.x + 236
	var y := RECT.position.y
	Palette.draw_boss(self, portrait_center(), 78, boss.kind, boss.is_enraged(), _t, flash)
	Palette.text(self, Vector2(x, y + 46), boss.name, 32, Palette.TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, true)
	var tag := "%s  |  Boss #%d" % [Boss.KIND_NAMES[boss.kind], boss.index]
	if boss.is_enraged():
		tag = "ENRAGED  |  " + tag
	Palette.text(self, Vector2(x, y + 76), tag, 20, Palette.HP_LOW if boss.is_enraged() else Palette.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, true)

	# HP bar.
	var bar := Rect2(x, y + 90, 430, 34)
	Palette.fill_rounded(self, bar, 14, Color("1a0a22"))
	var ratio := clampf(float(boss.hp) / boss.max_hp, 0, 1)
	if ratio > 0:
		Palette.fill_rounded(self, Rect2(bar.position + Vector2(3, 3), Vector2(maxf((bar.size.x - 6) * ratio, 24), bar.size.y - 6)), 12,
			Color("ff4f7a").lerp(Color.WHITE, flash * 0.5))
	Palette.text(self, bar.position + Vector2(0, 25), "%d / %d" % [boss.hp, boss.max_hp], 20, Color.WHITE,
		HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, true)
	var row := y + 136
	if boss.max_shell > 0:
		var sbar := Rect2(x, row, 430, 18)
		Palette.fill_rounded(self, sbar, 9, Color("1a0a22"))
		if boss.shell > 0:
			Palette.fill_rounded(self, Rect2(sbar.position, Vector2(sbar.size.x * boss.shell / boss.max_shell, sbar.size.y)), 9, Palette.SHELL)
		Palette.text(self, Vector2(x, row + 40), "Shell %d" % boss.shell if boss.shell > 0 else "Shell broken!", 18,
			Palette.SHELL if boss.shell > 0 else Palette.HP_GOOD, HORIZONTAL_ALIGNMENT_LEFT, -1, true)
		row += 26

	var info_y := y + 196
	Palette.text(self, Vector2(x + 140, info_y - 18), "Attack in %d  (%d dmg)" % [maxi(boss.attack_timer, 1), boss.attack_damage], 20,
		Palette.HP_LOW, HORIZONTAL_ALIGNMENT_LEFT, -1, true)
	if boss.spawns_obstacles():
		Palette.text(self, Vector2(x + 140, info_y + 10), "Drops obstacles in %d" % maxi(boss.spawn_timer, 1), 20, Palette.ICE)
	if boss.kind == Boss.Kind.SPAWNER and boss.weak_color >= 0:
		Palette.text(self, Vector2(x + 140, info_y + 38), "Weak to %s (3x)" % Palette.CANDY_NAMES[boss.weak_color], 20, Palette.GOLD)
		Palette.draw_candy(self, Vector2(x + 410, info_y + 30), 18, boss.weak_color, Cell.Special.NONE)
	var par_left := boss.par_moves - boss.moves_in_fight
	Palette.text(self, Vector2(RECT.position.x + 30, y + 266), ("Par: %d moves left" % par_left) if par_left > 0 else "Over par", 18,
		Palette.MUTED)
	var enrage_in := boss.enrage_after - boss.moves_in_fight
	if enrage_in > 0:
		Palette.text(self, Vector2(x + 140, info_y + 66), "Enrages in %d" % enrage_in, 18, Palette.MUTED)
	else:
		Palette.text(self, Vector2(x + 140, info_y + 66), "Attacks faster!", 18, Palette.HP_LOW, HORIZONTAL_ALIGNMENT_LEFT, -1, true)


static func _hint(kind: int) -> String:
	match kind:
		Boss.Kind.SPAWNER:
			return "Floats above the board. Every clear hurts it; its weak color hurts 3x. Drops ice and stone."
		Boss.Kind.HYBRID:
			return "Encased in the board AND drops obstacles. Match next to it and blast it with bombs."
	return "Sits inside the board behind a caramel cage. Match next to it or blast it to break through."
