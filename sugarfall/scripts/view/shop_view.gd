class_name ShopView
extends Control
## Coin shop between bosses: three upgrades, a healing snack and a reroll.

signal closed

var run: RunState
var _column: VBoxContainer


func _ready() -> void:
	var m := UiKit.modal()
	add_child(m[0])
	_column = m[1]
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()


func open(r: RunState) -> void:
	run = r
	_rebuild()
	show()


func _rebuild() -> void:
	UiKit.clear_children(_column)
	_column.add_child(UiKit.label("Candy Shop", 44, Palette.GOLD, true))
	var coins_row := HBoxContainer.new()
	coins_row.alignment = BoxContainer.ALIGNMENT_CENTER
	coins_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coins_row.add_child(IconView.make(IconView.Kind.COIN, 0, 40))
	coins_row.add_child(UiKit.label("%d coins" % run.coins, 28, Palette.GOLD, true, HORIZONTAL_ALIGNMENT_LEFT, false))
	_column.add_child(coins_row)

	for i in run.shop_items.size():
		var item: Dictionary = run.shop_items[i]
		if item.id == RunState.SNACK_ID:
			_column.add_child(_snack_row(i, item))
		else:
			var footer := "SOLD" if item.sold else "%d coins" % item.price
			var card := UpgradeCard.make(item.id, run.mods.rank(item.id), footer)
			card.disabled = item.sold or run.coins < item.price or not run.mods.can_offer(item.id)
			card.pressed.connect(_buy.bind(i))
			_column.add_child(card)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	var reroll := UiKit.button("Reroll (%d)" % run.shop_reroll_cost, _reroll, 300)
	reroll.disabled = run.coins < run.shop_reroll_cost
	buttons.add_child(reroll)
	buttons.add_child(UiKit.button("Continue", _close, 300))
	_column.add_child(buttons)


func _snack_row(i: int, item: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(660, 90)
	b.add_theme_stylebox_override("normal", UiKit.box(Color("3a1a50"), 24, Palette.HP_GOOD, 3))
	b.add_theme_stylebox_override("hover", UiKit.box(Color("4a2466"), 24, Color.WHITE, 3))
	var label := "SOLD" if item.sold else "%d coins" % item.price
	b.text = "Sugar Snack: heal %d HP   -   %s" % [RunState.SNACK_HEAL, label]
	b.add_theme_font_size_override("font_size", 24)
	b.disabled = item.sold or run.coins < item.price or run.hp >= run.max_hp
	b.pressed.connect(_buy.bind(i))
	return b


func _buy(i: int) -> void:
	if run.buy(i):
		_rebuild()


func _reroll() -> void:
	if run.reroll_shop():
		_rebuild()


func _close() -> void:
	hide()
	closed.emit()
