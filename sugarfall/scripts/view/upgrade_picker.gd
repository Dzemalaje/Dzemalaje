class_name UpgradePicker
extends Control
## "Choose 1 of 3" screen after a boss or a score milestone.

signal chosen(id: String)

var offer_ids: Array = []
var _column: VBoxContainer


func _ready() -> void:
	var m := UiKit.modal()
	var root: Control = m[0]
	_column = m[1]
	add_child(root)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()


func open(source: String, offer: Array, run: RunState) -> void:
	offer_ids = offer.duplicate()
	UiKit.clear_children(_column)
	var boss := source == "boss_reward"
	_column.add_child(UiKit.label("Boss defeated!" if boss else "Milestone reached!", 44,
		Palette.GOLD if boss else Palette.ACCENT, true))
	_column.add_child(UiKit.label("Choose one upgrade", 24, Palette.MUTED))
	for id in offer:
		var card := UpgradeCard.make(id, run.mods.rank(id))
		card.pressed.connect(_choose.bind(id))
		_column.add_child(card)
	show()


func _choose(id: String) -> void:
	hide()
	chosen.emit(id)
