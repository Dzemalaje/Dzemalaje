class_name FxNode
extends Node2D
## Short-lived effect (row/column blast, bomb ring, color burst, sparkle).
## Animate `progress` from 0 to 1, then free.

var kind: String = "ring"
var extent: Vector2 = Vector2.ZERO
var radius: float = 40.0
var color: Color = Color.WHITE
var progress: float = 0.0:
	set(v):
		progress = v
		queue_redraw()


func _draw() -> void:
	var a := 1.0 - progress
	match kind:
		"row", "col":
			var thick := extent.y * (1.0 - progress * 0.8)
			var size := Vector2(extent.x, thick) if kind == "row" else Vector2(thick, extent.x)
			draw_rect(Rect2(-size / 2, size), Color(color, 0.75 * a))
			var core := Vector2(extent.x, thick * 0.3) if kind == "row" else Vector2(thick * 0.3, extent.x)
			draw_rect(Rect2(-core / 2, core), Color(1, 1, 1, a))
		"ring":
			var r := radius * (0.25 + 0.75 * progress)
			draw_arc(Vector2.ZERO, r, 0, TAU, 48, Color(color, a), 4.0 + 14.0 * a, true)
			draw_colored_polygon(Palette.circle_points(Vector2.ZERO, r * 0.8), Color(1, 1, 1, 0.25 * a))
		"burst":
			for i in 12:
				var dir := Vector2.from_angle(TAU * i / 12.0 + progress)
				draw_line(dir * radius * 0.2 * (1 + progress), dir * radius * (0.4 + progress), Color(Palette.CANDY_COLORS[i % 6], a), 6.0, true)
		"sparkle":
			for i in 6:
				var dir := Vector2.from_angle(TAU * i / 6.0)
				draw_colored_polygon(Palette.circle_points(dir * radius * progress, 5.0 * a + 1.0, 8), Color(color, a))
