extends SceneTree
## Boots the real main scene and plays it through the UI code path.
##   godot --headless --path sugarfall -s res://tests/smoke_main.gd
## With a display (e.g. xvfb-run ... --rendering-driver opengl3), pass
##   -- --shots=/some/dir   to save screenshots of each screen.

const MOVES := 70

var shots_dir := ""
var main: Node
var errors := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots_dir = arg.substr(8)
	Engine.time_scale = 4.0
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_drive()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	if shots_dir.is_empty():
		return
	await _frames(3)
	var img := root.get_texture().get_image()
	img.save_png("%s/%s.png" % [shots_dir, name])
	print("  screenshot ", name)


func _pick_move() -> Array:
	var run: RunState = main.run
	var moves := run.board.find_valid_moves()
	if run.boss != null and run.boss.on_board():
		for m in moves:
			for c in run.boss.cells:
				if Board.are_adjacent(m[0], c) or Board.are_adjacent(m[1], c):
					return m
	return moves[randi() % moves.size()]


## Puts a hybrid boss and every obstacle type on the board for a screenshot.
func _staged_hybrid() -> void:
	var r: RunState = main.run
	if r.boss != null:
		r.boss.remove_from(r.board)
	r.boss = BossFactory.create(5, r.rng, 6)
	r.boss.place(r.board)
	r.boss.shell = r.boss.max_shell
	r.boss.moves_in_fight = r.boss.enrage_after
	Obstacles.spawn(r.board, r.rng, Obstacles.Kind.ICE, 3, 6, 2)
	Obstacles.spawn(r.board, r.rng, Obstacles.Kind.STONE, 3, 6, 2)
	Obstacles.spawn(r.board, r.rng, Obstacles.Kind.CHOCOLATE, 3)
	Obstacles.spawn(r.board, r.rng, Obstacles.Kind.COUNTDOWN, 2, 4)
	main.board_view.boss_ref = r.boss
	main.board_view.sync_snapshot(r.board.snapshot())
	main.boss_panel.refresh(r)
	main.hud.refresh(r)
	await _shot("10_hybrid_obstacles")
	# Keep playing a few moves on the crowded board through the real UI path.
	for i in 6:
		while main.busy or main.picker.visible or main.shop.visible:
			if main.picker.visible:
				main.picker._choose(main.picker.offer_ids[0])
			elif main.shop.visible:
				main.shop._close()
			await process_frame
		if r.game_over:
			break
		var m := _pick_move()
		main._on_swap_requested(m[0], m[1])
		await process_frame
	while main.busy:
		await process_frame


func _to_screen(local: Vector2) -> Vector2:
	return root.get_final_transform() * (main.board_view.get_global_transform_with_canvas() * local)


func _mouse(pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	Input.parse_input_event(e)
	await _frames(2)


func _motion(pos: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(e)
	await _frames(2)


func _wait_idle() -> void:
	await _frames(2)
	while main.busy:
		await process_frame


## Plays one move by dragging and one by tapping two cells, via real input events.
func _real_input_checks() -> void:
	var m := _pick_move()
	var before: int = main.run.moves
	var pa := _to_screen(main.board_view.cell_center(m[0]))
	var pb := _to_screen(main.board_view.cell_center(m[1]))
	await _mouse(pa, true)
	await _motion(pa.lerp(pb, 0.5))
	await _motion(pb)
	await _mouse(pb, false)
	await _wait_idle()
	if main.run.moves != before + 1:
		errors += 1
		printerr("SMOKE: drag input did not play a move")
	m = _pick_move()
	before = main.run.moves
	pa = _to_screen(main.board_view.cell_center(m[0]))
	pb = _to_screen(main.board_view.cell_center(m[1]))
	await _mouse(pa, true)
	await _mouse(pa, false)
	await _mouse(pb, true)
	await _mouse(pb, false)
	await _wait_idle()
	if main.run.moves != before + 1:
		errors += 1
		printerr("SMOKE: tap-tap input did not play a move")
	print("smoke: real input moves ok=%s" % [errors == 0])


func _drive() -> void:
	await _frames(5)
	await _shot("01_title")
	main._start_playing()
	await _frames(5)
	await _shot("02_board")
	await _real_input_checks()
	var played := 0
	var shot_picker := false
	var shot_shop := false
	var shot_boss := false
	var shot_spawner := false
	var guard := 0
	while played < MOVES and not main.run.game_over and guard < 20000:
		guard += 1
		if main.picker.visible:
			if not shot_picker:
				shot_picker = true
				await _shot("04_upgrade_pick")
			main.picker._choose(main.picker.offer_ids[0])
		elif main.shop.visible:
			if not shot_shop:
				shot_shop = true
				await _shot("05_shop")
			main.shop._close()
		elif not main.busy:
			var run: RunState = main.run
			if run.boss != null and run.boss.on_board() and not shot_boss:
				shot_boss = true
				await _shot("03_encased_boss")
			if run.boss != null and run.boss.kind == Boss.Kind.SPAWNER and run.boss.moves_in_fight >= 4 and not shot_spawner:
				shot_spawner = true
				await _shot("06_spawner_boss")
			var m := _pick_move()
			main._on_swap_requested(m[0], m[1])
			played += 1
			if not run.board.has_valid_move():
				errors += 1
				printerr("SMOKE: board has no valid move after turn")
		await process_frame
	print("smoke: played %d moves, bosses %d, hp %d, score %d" % [played, main.run.bosses_defeated, main.run.hp, main.run.score])
	while main.busy:
		await process_frame
	await _staged_hybrid()
	main._open_tree()
	await _frames(3)
	main.skill_tree._selected = "mega_bomb"
	main.skill_tree.queue_redraw()
	await _shot("07_skill_tree")
	main.skill_tree._on_close()
	await _frames(2)
	main._on_pause()
	await _shot("08_pause")
	main._on_resume()
	main.run.game_over = true
	main.menus.show_game_over(main.run, main.save, false)
	await _shot("09_game_over")
	quit(1 if errors > 0 else 0)
