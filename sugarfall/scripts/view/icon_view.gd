class_name IconView
extends Control
## Small custom-drawn icon: a branch emblem, a coin or a candy.

enum Kind { BRANCH, COIN, CANDY, HEART }

var kind: int = Kind.BRANCH
var value: int = 0
var dim: bool = false


static func make(p_kind: int, p_value: int = 0, size: float = 72) -> IconView:
	var v := IconView.new()
	v.kind = p_kind
	v.value = p_value
	v.custom_minimum_size = Vector2(size, size)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


func _draw() -> void:
	var c := size / 2
	var r := minf(size.x, size.y) * 0.46
	match kind:
		Kind.BRANCH:
			Palette.draw_branch_icon(self, c, r, value, dim)
		Kind.COIN:
			Palette.draw_coin(self, c, r * 0.8)
		Kind.CANDY:
			Palette.draw_candy(self, c, r * 0.85, value, Cell.Special.NONE)
		Kind.HEART:
			Palette.draw_branch_icon(self, c, r, UpgradeDB.Branch.MOMENTUM)
