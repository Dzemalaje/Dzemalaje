class_name CandyNode
extends Node2D
## One candy sprite, drawn procedurally.

var color: int = 0
var special: int = Cell.Special.NONE
var countdown: int = 0
var radius: float = 33.0


func setup(p_color: int, p_special: int, p_countdown: int) -> void:
	if p_color == color and p_special == special and p_countdown == countdown:
		return
	color = p_color
	special = p_special
	countdown = p_countdown
	queue_redraw()


func _draw() -> void:
	Palette.draw_candy(self, Vector2.ZERO, radius, color, special)
	if countdown > 0:
		Palette.draw_countdown(self, Vector2.ZERO, radius, countdown)
