class_name UpgradeCard
extends PanelContainer
## A tappable upgrade card: branch icon, name, rarity/rank, description, preview.

signal pressed

var disabled: bool = false:
	set(v):
		disabled = v
		modulate = Color(1, 1, 1, 0.45) if v else Color.WHITE
		_restyle()

var _branch_col: Color = Color.WHITE
var _hover: bool = false
var _down: bool = false


static func make(id: String, current_rank: int, footer: String = "") -> UpgradeCard:
	var card := UpgradeCard.new()
	card._build(id, current_rank, footer)
	return card


func _build(id: String, current_rank: int, footer: String) -> void:
	var d := UpgradeDB.get_def(id)
	_branch_col = Palette.BRANCH_COLORS[d.branch]
	custom_minimum_size = Vector2(660, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))
	_restyle()

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 16)
	add_child(row)

	var icon := IconView.make(IconView.Kind.BRANCH, d.branch, 84)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)

	col.add_child(UiKit.label(d.name, 30, Palette.TEXT, true, HORIZONTAL_ALIGNMENT_LEFT))
	var rank_text := "New" if current_rank == 0 else "Rank %d -> %d" % [current_rank, current_rank + 1]
	var tag := "%s  |  %s  |  %s" % [UpgradeDB.RARITY_NAMES[d.rarity], UpgradeDB.BRANCH_NAMES[d.branch], rank_text]
	if d.get("capstone", false):
		tag = "Capstone  |  " + tag
	col.add_child(UiKit.label(tag, 18, Palette.RARITY_COLORS[d.rarity], true, HORIZONTAL_ALIGNMENT_LEFT))
	col.add_child(UiKit.label(d.desc, 22, Palette.TEXT, false, HORIZONTAL_ALIGNMENT_LEFT))
	col.add_child(UiKit.label(UpgradeDB.preview(id, current_rank), 22, _branch_col.lightened(0.25), true, HORIZONTAL_ALIGNMENT_LEFT))
	if not footer.is_empty():
		col.add_child(UiKit.label(footer, 24, Palette.GOLD, true, HORIZONTAL_ALIGNMENT_LEFT))


func _set_hover(v: bool) -> void:
	_hover = v
	_restyle()


func _restyle() -> void:
	var lit := _hover and not disabled
	add_theme_stylebox_override("panel", UiKit.box(Color("4a2466") if lit else Color("3a1a50"), 24,
		Color.WHITE if lit else _branch_col, 3, 18, 14))


func _gui_input(event: InputEvent) -> void:
	if disabled or not (event is InputEventMouseButton) or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		_down = true
	elif _down:
		_down = false
		if Rect2(Vector2.ZERO, size).has_point(event.position):
			pressed.emit()
	accept_event()
