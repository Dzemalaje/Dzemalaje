class_name Hud
extends Control
## Top bar (score, coins, pause), Sugar HP bar and bottom bar (streak, build).

signal pause_pressed
signal tree_pressed

const HP_RECT := Rect2(12, 104, 696, 46)
const BOTTOM_RECT := Rect2(12, 1136, 696, 132)

var run: RunState
var _hp_shown: float = 100.0
var _hp_flash: float = 0.0
var _pause_btn: Button
var _tree_btn: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiKit.theme()
	_pause_btn = UiKit.button("II", func() -> void: pause_pressed.emit(), 72)
	_pause_btn.position = Vector2(628, 18)
	_pause_btn.size = Vector2(72, 72)
	add_child(_pause_btn)
	_tree_btn = UiKit.button("Skill Tree", func() -> void: tree_pressed.emit(), 200)
	_tree_btn.position = Vector2(494, 1166)
	_tree_btn.size = Vector2(200, 72)
	add_child(_tree_btn)


func set_buttons_visible(v: bool) -> void:
	_pause_btn.visible = v
	_tree_btn.visible = v


func refresh(r: RunState) -> void:
	run = r
	queue_redraw()


func flash_damage() -> void:
	_hp_flash = 1.0


func _process(delta: float) -> void:
	if run == null:
		return
	var target := float(run.hp)
	if absf(_hp_shown - target) > 0.1 or _hp_flash > 0.0:
		_hp_shown = move_toward(_hp_shown, target, maxf(30.0, absf(_hp_shown - target) * 4.0) * delta)
		_hp_flash = maxf(0.0, _hp_flash - delta * 2.0)
		queue_redraw()


func hp_bar_center() -> Vector2:
	return HP_RECT.get_center()


func coin_pos() -> Vector2:
	return Vector2(440, 56)


func _draw() -> void:
	if run == null:
		return
	# Top bar.
	Palette.fill_rounded(self, Rect2(12, 10, 604, 86), 22, Palette.PANEL)
	Palette.text(self, Vector2(34, 42), "SCORE", 18, Palette.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, true)
	Palette.text(self, Vector2(34, 82), _fmt(run.score), 36, Palette.TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, true)
	Palette.draw_coin(self, coin_pos(), 18)
	Palette.text(self, Vector2(466, 68), str(run.coins), 32, Palette.GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, true)
	Palette.text(self, Vector2(300, 42), "MOVES", 18, Palette.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, true)
	Palette.text(self, Vector2(300, 80), str(run.moves), 30, Palette.TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, true)

	# Sugar HP.
	Palette.fill_rounded(self, HP_RECT, 20, Color("1a0a22"))
	var ratio := clampf(_hp_shown / run.max_hp, 0.0, 1.0)
	var col := Palette.HP_GOOD if ratio > 0.5 else (Palette.HP_MID if ratio > 0.25 else Palette.HP_LOW)
	col = col.lerp(Color.WHITE, _hp_flash * 0.6)
	if ratio > 0.0:
		var fill := Rect2(HP_RECT.position + Vector2(4, 4), Vector2(maxf((HP_RECT.size.x - 8) * ratio, 30), HP_RECT.size.y - 8))
		Palette.fill_rounded(self, fill, 16, col)
		Palette.fill_rounded(self, Rect2(fill.position + Vector2(8, 4), Vector2(maxf(fill.size.x - 16, 4), 8)), 4, Color(1, 1, 1, 0.3))
	Palette.text(self, HP_RECT.position + Vector2(0, 32), "Sugar HP  %d / %d" % [run.hp, run.max_hp], 24,
		Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, HP_RECT.size.x, true)

	# Bottom bar.
	Palette.fill_rounded(self, BOTTOM_RECT, 22, Palette.PANEL)
	var mult := run.score_multiplier()
	Palette.text(self, BOTTOM_RECT.position + Vector2(22, 40), "Streak %d" % run.streak, 24, Palette.TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, true)
	Palette.text(self, BOTTOM_RECT.position + Vector2(22, 72), "Score x%.1f" % mult, 22,
		Palette.GOLD if mult > 1.0 else Palette.MUTED)
	Palette.text(self, BOTTOM_RECT.position + Vector2(22, 106), "Next milestone %s" % _fmt(run.next_milestone), 18, Palette.MUTED)
	# Branch progress chips.
	for b in 5:
		var c := BOTTOM_RECT.position + Vector2(228 + b * 50, 52)
		var progress := 0
		for id in UpgradeDB.ids_in_branch(b):
			progress += run.mods.rank(id)
		Palette.draw_branch_icon(self, c, 20, b, progress == 0)
		Palette.text(self, c + Vector2(-20, 52), str(progress), 20, Palette.TEXT if progress > 0 else Palette.MUTED,
			HORIZONTAL_ALIGNMENT_CENTER, 40, true)


static func _fmt(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out
