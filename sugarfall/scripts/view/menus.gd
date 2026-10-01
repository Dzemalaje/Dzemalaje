class_name Menus
extends Control
## Title, pause and game over screens.

signal play_pressed
signal resume_pressed
signal restart_pressed
signal menu_pressed
signal tree_pressed

var _root: Control
var _column: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()


func _open(dim: float) -> VBoxContainer:
	if _root != null:
		_root.queue_free()
	var m := UiKit.modal(dim)
	_root = m[0]
	_column = m[1]
	add_child(_root)
	show()
	return _column


func close() -> void:
	hide()
	if _root != null:
		_root.queue_free()
		_root = null


func show_title(save: SaveData) -> void:
	var col := _open(0.55)
	col.add_child(_spacer(40))
	col.add_child(UiKit.label("SUGARFALL", 84, Palette.ACCENT, true))
	col.add_child(UiKit.label("I N F I N I T E", 34, Palette.GOLD, true))
	var candies := HBoxContainer.new()
	candies.alignment = BoxContainer.ALIGNMENT_CENTER
	candies.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 6:
		candies.add_child(IconView.make(IconView.Kind.CANDY, i, 70))
	col.add_child(candies)
	col.add_child(_spacer(10))
	var p := UiKit.panel(10)
	col.add_child(p[0])
	var v: VBoxContainer = p[1]
	v.add_child(UiKit.label("How to play", 28, Palette.GOLD, true))
	for line in [
			"Swipe candies to match 3 or more.",
			"There are no levels: the board never ends.",
			"Every few moves a boss appears. Break its cage or survive its obstacles.",
			"Bosses and obstacles drain your Sugar HP. At 0 the run is over.",
			"Beat bosses and hit score milestones to pick upgrades. Spend coins in the shop."]:
		v.add_child(UiKit.label(line, 22, Palette.TEXT))
	if save.runs > 0:
		col.add_child(UiKit.label("Best: %s points  |  %d bosses" % [Hud._fmt(save.best_score), save.best_bosses], 24, Palette.MUTED, true))
	col.add_child(_centered(UiKit.button("Play", func() -> void: play_pressed.emit(), 420)))


func show_pause() -> void:
	var col := _open(0.75)
	col.add_child(UiKit.label("Paused", 56, Palette.ACCENT, true))
	col.add_child(_spacer(10))
	col.add_child(_centered(UiKit.button("Resume", func() -> void: resume_pressed.emit(), 420)))
	col.add_child(_centered(UiKit.button("Skill Tree", func() -> void: tree_pressed.emit(), 420)))
	col.add_child(_centered(UiKit.button("Restart Run", func() -> void: restart_pressed.emit(), 420)))
	col.add_child(_centered(UiKit.button("Main Menu", func() -> void: menu_pressed.emit(), 420)))


func show_game_over(run: RunState, save: SaveData, new_best: bool) -> void:
	var col := _open(0.8)
	col.add_child(UiKit.label("Sugar Crash!", 64, Palette.HP_LOW, true))
	if new_best:
		col.add_child(UiKit.label("New best score!", 30, Palette.GOLD, true))
	var p := UiKit.panel(8)
	col.add_child(p[0])
	var v: VBoxContainer = p[1]
	v.add_child(UiKit.label(Hud._fmt(run.score), 56, Palette.TEXT, true))
	v.add_child(UiKit.label("points", 22, Palette.MUTED))
	v.add_child(UiKit.label("Bosses defeated: %d" % run.bosses_defeated, 28, Palette.GOLD, true))
	v.add_child(UiKit.label("Moves: %d   |   Best cascade: %d" % [run.moves, run.best_cascade], 24, Palette.TEXT))
	var build := run.build_list()
	v.add_child(UiKit.label("Build", 26, Palette.ACCENT, true))
	v.add_child(UiKit.label(", ".join(build) if not build.is_empty() else "No upgrades taken", 22, Palette.TEXT))
	v.add_child(UiKit.label("Best ever: %s  |  %d bosses" % [Hud._fmt(save.best_score), save.best_bosses], 20, Palette.MUTED))
	col.add_child(_centered(UiKit.button("Play Again", func() -> void: restart_pressed.emit(), 420)))
	col.add_child(_centered(UiKit.button("Main Menu", func() -> void: menu_pressed.emit(), 420)))


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _centered(c: Control) -> Control:
	var box := CenterContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(c)
	return box
