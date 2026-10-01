class_name Background
extends Node2D
## Vertical gradient with slowly drifting sugar bubbles.

var _bubbles: Array = []
var _t: float = 0.0


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	for i in 22:
		_bubbles.append({
			"pos": Vector2(rng.randf_range(0, 720), rng.randf_range(0, 1600)),
			"r": rng.randf_range(10, 46),
			"speed": rng.randf_range(6, 18),
			"color": Color(Palette.CANDY_COLORS[i % 6], 0.08),
		})


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var w := 720.0
	var h := 2200.0
	draw_polygon(PackedVector2Array([Vector2(0, -200), Vector2(w, -200), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([Palette.BG_TOP, Palette.BG_TOP, Palette.BG_BOTTOM, Palette.BG_BOTTOM]))
	for b in _bubbles:
		var y := fposmod(b.pos.y - _t * b.speed, 1700.0) - 100.0
		var x: float = b.pos.x + sin(_t * 0.5 + b.r) * 12.0
		draw_colored_polygon(Palette.circle_points(Vector2(x, y), b.r, 20), b.color)
