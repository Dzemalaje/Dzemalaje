extends Node2D
## Game controller: owns the RunState, routes input to it, plays the results
## through the views and walks the player through pending picks and the shop.

const BOARD_ORIGIN := Vector2(24, 452)

var run: RunState
var save := SaveData.new()
var busy: bool = false
var paused: bool = false

var world: Node2D
var board_view: BoardView
var hud: Hud
var boss_panel: BossPanel
var fx_layer: CanvasLayer
var picker: UpgradePicker
var shop: ShopView
var skill_tree: SkillTreeView
var menus: Menus


func _ready() -> void:
	save.load_data()
	_build()
	_new_run()
	_show_title()


func _build() -> void:
	add_child(Background.new())
	world = Node2D.new()
	add_child(world)
	var clip := Control.new()
	clip.position = BOARD_ORIGIN - Vector2(8, 8)
	clip.size = Vector2(8 * BoardView.CELL + 16, 8 * BoardView.CELL + 16)
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.add_child(clip)
	board_view = BoardView.new()
	board_view.position = Vector2(8, 8)
	clip.add_child(board_view)
	board_view.swap_requested.connect(_on_swap_requested)
	board_view.combo_reached.connect(_on_combo)

	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 1
	add_child(hud_layer)
	hud = Hud.new()
	hud_layer.add_child(hud)
	boss_panel = BossPanel.new()
	hud.add_child(boss_panel)
	hud.pause_pressed.connect(_on_pause)
	hud.tree_pressed.connect(_open_tree)

	fx_layer = CanvasLayer.new()
	fx_layer.layer = 2
	add_child(fx_layer)

	var overlay := CanvasLayer.new()
	overlay.layer = 10
	add_child(overlay)
	picker = UpgradePicker.new()
	overlay.add_child(picker)
	shop = ShopView.new()
	overlay.add_child(shop)
	menus = Menus.new()
	overlay.add_child(menus)
	skill_tree = SkillTreeView.new()
	overlay.add_child(skill_tree)
	menus.play_pressed.connect(_start_playing)
	menus.resume_pressed.connect(_on_resume)
	menus.restart_pressed.connect(_on_restart)
	menus.menu_pressed.connect(_on_menu)
	menus.tree_pressed.connect(_open_tree)


# --- Run lifecycle -------------------------------------------------------------

func _new_run(seed_value: int = -1) -> void:
	run = RunState.new(seed_value)
	board_view.reset(run.board, run.boss)
	hud.refresh(run)
	boss_panel.refresh(run)
	busy = false
	paused = false


func _show_title() -> void:
	board_view.input_enabled = false
	hud.set_buttons_visible(false)
	menus.show_title(save)


func _start_playing() -> void:
	menus.close()
	_new_run()
	hud.set_buttons_visible(true)
	board_view.input_enabled = true


func _on_pause() -> void:
	if busy or run.game_over:
		return
	paused = true
	board_view.input_enabled = false
	menus.show_pause()


func _on_resume() -> void:
	menus.close()
	paused = false
	board_view.input_enabled = true


func _on_restart() -> void:
	_start_playing()


func _on_menu() -> void:
	menus.close()
	_new_run()
	_show_title()


func _open_tree() -> void:
	if busy and not paused:
		return
	var was_enabled := board_view.input_enabled
	board_view.input_enabled = false
	skill_tree.open(run)
	await skill_tree.closed
	if not paused:
		board_view.input_enabled = was_enabled


# --- Turns ------------------------------------------------------------------------

func _on_swap_requested(a: Vector2i, b: Vector2i) -> void:
	if busy or paused or run.game_over or not run.pending.is_empty():
		return
	if not run.board.can_attempt(a, b):
		return
	busy = true
	board_view.input_enabled = false
	var res := run.play_swap(a, b)
	if res.valid:
		await board_view.animate_swap(a, b)
	else:
		await board_view.animate_invalid(a, b)
	for step in res.steps:
		await board_view.animate_step(step)
	board_view.boss_ref = run.boss
	board_view.sync_snapshot(run.board.snapshot())
	await _show_events(res.events)
	hud.refresh(run)
	boss_panel.refresh(run)

	if run.game_over:
		await get_tree().create_timer(0.9).timeout
		var new_best := save.record(run)
		hud.set_buttons_visible(false)
		menus.show_game_over(run, save, new_best)
		busy = false
		return

	await _process_pending()
	busy = false
	board_view.input_enabled = not paused


func _process_pending() -> void:
	while not run.pending.is_empty():
		var kind := run.pop_pending()
		match kind:
			"boss_reward", "milestone":
				var offer := run.make_offer(kind)
				if offer.is_empty():
					continue
				picker.open(kind, offer, run)
				var id: String = await picker.chosen
				run.choose_upgrade(id)
			"shop":
				run.open_shop()
				shop.open(run)
				await shop.closed
		hud.refresh(run)
		boss_panel.refresh(run)


func _show_events(events: Array) -> void:
	var pause_after := 0.0
	for e in events:
		match e.type:
			"damage":
				hud.flash_damage()
				_shake(8.0 + e.amount * 0.4)
				var at := hud.hp_bar_center()
				if e.source == "countdown" and e.pos.x >= 0:
					at = board_view.global_position + board_view.cell_center(e.pos)
				_float_text("-%d HP" % e.amount, at, Palette.HP_LOW, 34)
			"heal":
				_float_text("+%d HP" % e.amount, hud.hp_bar_center() + Vector2(120, 0), Palette.HP_GOOD, 30)
			"boss_damage":
				boss_panel.flash = 1.0
				board_view.boss_flash = 1.0
				_float_text("-%d" % e.amount, boss_panel.portrait_center() + Vector2(0, -60), Color("ff7aa0"), 36)
			"coins", "lucky_drop":
				_float_text("+%d" % e.amount, hud.coin_pos() + Vector2(0, 30), Palette.GOLD, 28)
			"boss_spawn":
				_banner("%s appears!" % e.name, Palette.HP_LOW)
				pause_after = 0.9
			"boss_defeated":
				_banner("%s defeated!" % e.name, Palette.GOLD)
				pause_after = 1.0
			"second_chance":
				_banner("Second Chance!", Palette.HP_GOOD)
			"full_spectrum":
				_float_text("Full Spectrum!", Vector2(360, 420), Palette.ACCENT, 34)
			"reshuffle":
				_banner("No moves - shuffle!", Palette.ICE)
				pause_after = maxf(pause_after, 0.6)
			"free_swap":
				_float_text("Free swap", Vector2(360, 800), Palette.MUTED, 28)
			"milestone":
				_float_text("Milestone!", Vector2(360, 480), Palette.ACCENT, 34)
	if pause_after > 0.0:
		await get_tree().create_timer(pause_after).timeout


func _on_combo(combo: int, at: Vector2) -> void:
	var words := ["", "", "Sweet!", "Tasty!", "Delicious!", "Sugar Rush!", "Divine!"]
	var word: String = words[mini(combo, words.size() - 1)]
	_float_text("%s  x%d" % [word, combo], at + Vector2(0, -40 * (combo % 3)), Palette.GOLD, 30 + mini(combo, 6) * 3)


# --- Juice -----------------------------------------------------------------------

func _float_text(text: String, at: Vector2, color: Color, size: int = 30) -> void:
	var l := UiKit.label(text, size, color, true)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.add_theme_color_override("font_outline_color", Color("1a0612"))
	l.add_theme_constant_override("outline_size", 8)
	fx_layer.add_child(l)
	l.reset_size()
	l.position = at - l.size / 2
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "position:y", l.position.y - 70, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.35)
	tw.chain().tween_callback(l.queue_free)


func _banner(text: String, color: Color) -> void:
	var l := UiKit.label(text, 50, color, true)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.add_theme_color_override("font_outline_color", Color("1a0612"))
	l.add_theme_constant_override("outline_size", 12)
	fx_layer.add_child(l)
	l.reset_size()
	l.pivot_offset = l.size / 2
	l.position = Vector2(360, 780) - l.size / 2
	l.scale = Vector2(0.3, 0.3)
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.35)
	tw.tween_callback(l.queue_free)


func _shake(strength: float) -> void:
	var tw := world.create_tween()
	for i in 6:
		var off := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength * (1.0 - i / 6.0)
		tw.tween_property(world, "position", off, 0.035)
	tw.tween_property(world, "position", Vector2.ZERO, 0.04)
