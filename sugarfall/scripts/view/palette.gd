class_name Palette
extends RefCounted
## Colors and procedural drawing for candies, obstacles, bosses and icons.
## Everything is drawn in code so the project needs no art assets.

const CANDY_COLORS := [
	Color("ff4f6d"), # cherry
	Color("ff9a2e"), # orange
	Color("ffd93d"), # lemon
	Color("4cd17a"), # lime
	Color("3fa7ff"), # blueberry
	Color("b066ff"), # grape
]
const CANDY_NAMES := ["Cherry", "Orange", "Lemon", "Lime", "Blueberry", "Grape"]
const BRANCH_COLORS := [Color("ff6fae"), Color("ff7a3d"), Color("9b7bff"), Color("38c98a"), Color("f5c542")]
const BRANCH_SHORT := ["Combo", "Bombs", "Chroma", "Momentum", "Economy"]
const RARITY_COLORS := [Color("d8c8e0"), Color("6fd3ff"), Color("ffb84d"), Color("ff5fd2")]

const BG_TOP := Color("3a1450")
const BG_BOTTOM := Color("150822")
const PANEL := Color("2c1340", 0.92)
const PANEL_LIGHT := Color("43205c")
const ACCENT := Color("ff6fae")
const TEXT := Color("fff4fb")
const MUTED := Color("c7a6d8")
const GOLD := Color("ffcf4a")
const HP_GOOD := Color("57e08a")
const HP_MID := Color("ffd23f")
const HP_LOW := Color("ff4f5e")
const SHELL := Color("e0a050")
const CHOCOLATE := Color("6b3a22")
const STONE := Color("8b8496")
const ICE := Color("bfe9ff")


static func font() -> Font:
	return ThemeDB.fallback_font


static var _bold: FontVariation


static func bold_font() -> Font:
	if _bold == null:
		_bold = FontVariation.new()
		_bold.base_font = ThemeDB.fallback_font
		_bold.variation_embolden = 0.9
	return _bold


# --- Shapes -------------------------------------------------------------------

static func circle_points(center: Vector2, r: float, segments: int = 28, squash: float = 1.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		var a := TAU * i / segments
		pts.append(center + Vector2(cos(a) * r, sin(a) * r * squash))
	return pts


static func rounded_rect_points(rect: Rect2, radius: float, seg: int = 5) -> PackedVector2Array:
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var pts := PackedVector2Array()
	var corners := [
		[rect.position + Vector2(rect.size.x - r, r), -PI / 2],
		[rect.position + Vector2(rect.size.x - r, rect.size.y - r), 0.0],
		[rect.position + Vector2(r, rect.size.y - r), PI / 2],
		[rect.position + Vector2(r, r), PI],
	]
	for c in corners:
		for i in seg + 1:
			var a: float = c[1] + (PI / 2) * i / seg
			pts.append(c[0] + Vector2(cos(a), sin(a)) * r)
	return pts


static func polygon_points(center: Vector2, r: float, sides: int, rotation: float = -PI / 2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in sides:
		var a := rotation + TAU * i / sides
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	return pts


static func star_points(center: Vector2, r: float, inner: float, points: int = 5) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in points * 2:
		var a := -PI / 2 + PI * i / points
		var rr := r if i % 2 == 0 else r * inner
		pts.append(center + Vector2(cos(a), sin(a)) * rr)
	return pts


static func candy_shape(color_idx: int, c: Vector2, r: float) -> PackedVector2Array:
	match color_idx:
		0: return circle_points(c, r * 0.92)
		1: return rounded_rect_points(Rect2(c - Vector2(r, r) * 0.8, Vector2(r, r) * 1.6), r * 0.32)
		2: return polygon_points(c, r * 1.02, 4)
		3: return polygon_points(c, r * 0.95, 6, 0.0)
		4: return circle_points(c, r * 0.95, 28, 0.78)
		5: return star_points(c, r * 1.02, 0.56)
	return circle_points(c, r)


static func outline(ci: CanvasItem, pts: PackedVector2Array, color: Color, width: float) -> void:
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, color, width, true)


static func fill_rounded(ci: CanvasItem, rect: Rect2, radius: float, color: Color) -> void:
	ci.draw_colored_polygon(rounded_rect_points(rect, radius), color)


# --- Candies ------------------------------------------------------------------

static func draw_candy(ci: CanvasItem, c: Vector2, r: float, color_idx: int, special: int) -> void:
	if special == Cell.Special.COLOR_BOMB:
		_draw_color_bomb(ci, c, r)
		return
	var base: Color = CANDY_COLORS[clampi(color_idx, 0, CANDY_COLORS.size() - 1)]
	if special == Cell.Special.BOMB or special == Cell.Special.MEGA_BOMB:
		# Wrapper ends.
		for side in [-1.0, 1.0]:
			var tip := c + Vector2(side * r * 1.08, 0)
			var wing := PackedVector2Array([c + Vector2(side * r * 0.55, -r * 0.18), tip + Vector2(0, -r * 0.42),
				tip + Vector2(0, r * 0.42), c + Vector2(side * r * 0.55, r * 0.18)])
			ci.draw_colored_polygon(wing, base.darkened(0.15))
	var shape := candy_shape(color_idx, c, r)
	var shadow := PackedVector2Array()
	for p in shape:
		shadow.append(p + Vector2(0, r * 0.12))
	ci.draw_colored_polygon(shadow, Color(0, 0, 0, 0.28))
	ci.draw_colored_polygon(shape, base)
	var inner := PackedVector2Array()
	for p in shape:
		inner.append(c + (p - c) * 0.62 + Vector2(-r * 0.08, -r * 0.12))
	ci.draw_colored_polygon(inner, base.lightened(0.28))
	outline(ci, shape, base.darkened(0.35), 3.0)
	ci.draw_colored_polygon(circle_points(c + Vector2(-r * 0.32, -r * 0.38), r * 0.17, 12, 0.7), Color(1, 1, 1, 0.75))

	match special:
		Cell.Special.STRIPED_H:
			for k in [-1, 0, 1]:
				var y: float = c.y + k * r * 0.3
				ci.draw_line(Vector2(c.x - r * 0.62, y), Vector2(c.x + r * 0.62, y), Color(1, 1, 1, 0.9), 4.0, true)
		Cell.Special.STRIPED_V:
			for k in [-1, 0, 1]:
				var x: float = c.x + k * r * 0.3
				ci.draw_line(Vector2(x, c.y - r * 0.62), Vector2(x, c.y + r * 0.62), Color(1, 1, 1, 0.9), 4.0, true)
		Cell.Special.BOMB:
			ci.draw_arc(c, r * 0.42, 0, TAU, 24, Color(1, 1, 1, 0.9), 4.0, true)
		Cell.Special.MEGA_BOMB:
			ci.draw_arc(c, r * 0.42, 0, TAU, 24, Color(1, 1, 1, 0.9), 4.0, true)
			ci.draw_arc(c, r * 1.02, 0, TAU, 32, GOLD, 4.0, true)
			ci.draw_line(c - Vector2(r * 0.25, 0), c + Vector2(r * 0.25, 0), Color.WHITE, 3.0)
			ci.draw_line(c - Vector2(0, r * 0.25), c + Vector2(0, r * 0.25), Color.WHITE, 3.0)


static func _draw_color_bomb(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_colored_polygon(circle_points(c + Vector2(0, r * 0.12), r * 0.9), Color(0, 0, 0, 0.3))
	ci.draw_colored_polygon(circle_points(c, r * 0.9), Color("4a2616"))
	ci.draw_colored_polygon(circle_points(c + Vector2(-r * 0.1, -r * 0.12), r * 0.62), Color("6a3a22"))
	var sprinkles := [Vector2(-0.45, -0.2), Vector2(0.1, -0.55), Vector2(0.5, -0.15), Vector2(-0.15, 0.25),
		Vector2(0.35, 0.45), Vector2(-0.5, 0.4), Vector2(0.05, -0.05), Vector2(0.55, 0.15), Vector2(-0.2, -0.6)]
	for i in sprinkles.size():
		var p: Vector2 = c + sprinkles[i] * r
		var dir := Vector2.from_angle(i * 1.7)
		ci.draw_line(p - dir * r * 0.1, p + dir * r * 0.1, CANDY_COLORS[i % CANDY_COLORS.size()], 5.0, true)
	outline(ci, circle_points(c, r * 0.9), Color("2a1208"), 3.0)
	ci.draw_colored_polygon(circle_points(c + Vector2(-r * 0.35, -r * 0.4), r * 0.15, 12, 0.7), Color(1, 1, 1, 0.6))


static func draw_countdown(ci: CanvasItem, c: Vector2, r: float, turns: int) -> void:
	var at := c + Vector2(r * 0.5, r * 0.5)
	ci.draw_colored_polygon(circle_points(at, r * 0.42), Color("1c0d16"))
	ci.draw_arc(at, r * 0.42, 0, TAU, 20, HP_LOW, 3.0, true)
	var f := bold_font()
	var size := 24
	var txt := str(turns)
	var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	ci.draw_string(f, at + Vector2(-w / 2, size * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color.WHITE)


# --- Obstacles ----------------------------------------------------------------

static func draw_stone(ci: CanvasItem, rect: Rect2, hp: int) -> void:
	fill_rounded(ci, rect.grow(-2), 14, STONE.darkened(0.25))
	fill_rounded(ci, Rect2(rect.position + Vector2(2, 2), rect.size - Vector2(4, 9)), 14, STONE)
	var c := rect.get_center()
	for spot in [Vector2(-0.2, -0.15), Vector2(0.22, 0.05), Vector2(-0.05, 0.25)]:
		ci.draw_colored_polygon(circle_points(c + spot * rect.size, rect.size.x * 0.07, 10), STONE.darkened(0.2))
	if hp >= 2:
		outline(ci, rounded_rect_points(rect.grow(-5), 12), Color("d9d3e2"), 3.0)


static func draw_chocolate(ci: CanvasItem, rect: Rect2) -> void:
	fill_rounded(ci, rect.grow(-1), 10, CHOCOLATE.darkened(0.3))
	var half := (rect.size - Vector2(10, 10)) / 2
	for ix in 2:
		for iy in 2:
			var r := Rect2(rect.position + Vector2(4, 4) + Vector2(ix * (half.x + 2), iy * (half.y + 2)), half)
			fill_rounded(ci, r, 6, CHOCOLATE)
			ci.draw_line(r.position + Vector2(4, 4), r.position + Vector2(r.size.x - 4, 4), CHOCOLATE.lightened(0.25), 2.0)


static func draw_ice(ci: CanvasItem, rect: Rect2, layers: int) -> void:
	var col := Color(ICE.r, ICE.g, ICE.b, 0.28 + 0.18 * layers)
	fill_rounded(ci, rect.grow(-2), 12, col)
	outline(ci, rounded_rect_points(rect.grow(-2), 12), Color(1, 1, 1, 0.85), 3.0)
	var c := rect.get_center()
	ci.draw_line(c + Vector2(-20, -24), c + Vector2(-6, -8), Color(1, 1, 1, 0.8), 2.0)
	ci.draw_line(c + Vector2(-6, -8), c + Vector2(-12, 6), Color(1, 1, 1, 0.8), 2.0)
	if layers >= 2:
		ci.draw_line(c + Vector2(14, 10), c + Vector2(26, 24), Color(1, 1, 1, 0.8), 2.0)
		ci.draw_line(c + Vector2(14, 10), c + Vector2(24, -4), Color(1, 1, 1, 0.8), 2.0)


# --- Bosses -------------------------------------------------------------------

static func boss_color(kind: int) -> Color:
	match kind:
		Boss.Kind.SPAWNER: return Color("7b3fb8")
		Boss.Kind.HYBRID: return Color("2f7a5a")
	return Color("5a2340")


## Boss face/body in a square of half-size r around c.
static func draw_boss(ci: CanvasItem, c: Vector2, r: float, kind: int, enraged: bool, t: float, flash: float) -> void:
	var body := boss_color(kind)
	if enraged:
		body = body.lerp(Color("c42a3a"), 0.35 + 0.15 * sin(t * 6.0))
	body = body.lerp(Color.WHITE, clampf(flash, 0, 1) * 0.6)
	var bob := sin(t * 2.2) * r * 0.03
	c += Vector2(0, bob)
	if kind == Boss.Kind.SPAWNER:
		# Floating sorceress: round head, tall hat, wand.
		ci.draw_colored_polygon(circle_points(c + Vector2(0, r * 0.95), r * 0.55, 24, 0.22), Color(0, 0, 0, 0.25))
		ci.draw_colored_polygon(circle_points(c + Vector2(0, r * 0.15), r * 0.62), body)
		var hat := PackedVector2Array([c + Vector2(-r * 0.78, -r * 0.2), c + Vector2(r * 0.78, -r * 0.2),
			c + Vector2(r * 0.12, -r * 1.05), c + Vector2(-r * 0.05, -r * 0.95)])
		ci.draw_colored_polygon(hat, Color("2b0f3d"))
		ci.draw_line(c + Vector2(-r * 0.6, -r * 0.28), c + Vector2(r * 0.6, -r * 0.28), GOLD, 5.0)
		ci.draw_line(c + Vector2(r * 0.7, r * 0.3), c + Vector2(r * 1.0, -r * 0.3), Color("f0e0c0"), 5.0)
		ci.draw_colored_polygon(star_points(c + Vector2(r * 1.0, -r * 0.36), r * 0.16, 0.45), GOLD)
	else:
		var rect := Rect2(c - Vector2(r, r) * 0.9, Vector2(r, r) * 1.8)
		fill_rounded(ci, rect, r * 0.35, body)
		for i in 3:
			var y := rect.position.y + rect.size.y * (0.25 + 0.25 * i)
			ci.draw_line(Vector2(rect.position.x + r * 0.2, y), Vector2(rect.end.x - r * 0.2, y), body.lightened(0.15), r * 0.08)
		if kind == Boss.Kind.HYBRID:
			for side in [-1.0, 1.0]:
				var horn := PackedVector2Array([c + Vector2(side * r * 0.5, -r * 0.85), c + Vector2(side * r * 0.85, -r * 1.25),
					c + Vector2(side * r * 0.8, -r * 0.7)])
				ci.draw_colored_polygon(horn, Color("f2e6c8"))
	# Face.
	var eye_y := c.y + (r * 0.05 if kind == Boss.Kind.SPAWNER else -r * 0.18)
	for side in [-1.0, 1.0]:
		var e := Vector2(c.x + side * r * 0.3, eye_y)
		ci.draw_colored_polygon(circle_points(e, r * 0.18), Color.WHITE)
		ci.draw_colored_polygon(circle_points(e + Vector2(0, r * 0.05), r * 0.09), Color("1a0a14"))
		var brow_in := Vector2(c.x + side * r * 0.12, eye_y - r * (0.18 if enraged else 0.24))
		var brow_out := Vector2(c.x + side * r * 0.48, eye_y - r * 0.3)
		ci.draw_line(brow_in, brow_out, Color("1a0a14"), r * 0.07)
	var mouth_y := eye_y + r * 0.42
	var mouth := PackedVector2Array([Vector2(c.x - r * 0.32, mouth_y), Vector2(c.x + r * 0.32, mouth_y),
		Vector2(c.x + r * 0.2, mouth_y + r * 0.18), Vector2(c.x - r * 0.2, mouth_y + r * 0.18)])
	ci.draw_colored_polygon(mouth, Color("2a0a18"))
	for i in 3:
		var tx := c.x - r * 0.2 + r * 0.2 * i
		ci.draw_colored_polygon(PackedVector2Array([Vector2(tx - r * 0.06, mouth_y), Vector2(tx + r * 0.06, mouth_y),
			Vector2(tx, mouth_y + r * 0.09)]), Color.WHITE)


## Caramel cage bars over an encased boss, one ring per shell layer.
static func draw_cage(ci: CanvasItem, rect: Rect2, layers: int) -> void:
	if layers <= 0:
		return
	var bars := 5
	for i in bars:
		var x := rect.position.x + rect.size.x * (i + 0.5) / bars
		ci.draw_line(Vector2(x, rect.position.y + 4), Vector2(x, rect.end.y - 4), SHELL.darkened(0.25), 7.0)
		ci.draw_line(Vector2(x - 1, rect.position.y + 4), Vector2(x - 1, rect.end.y - 4), SHELL, 3.0)
	for k in mini(layers, 4):
		var g := rect.grow(-3 - k * 7)
		outline(ci, rounded_rect_points(g, 16), SHELL if k % 2 == 0 else Color("fff0dc"), 5.0)


# --- Icons --------------------------------------------------------------------

static func draw_branch_icon(ci: CanvasItem, c: Vector2, r: float, branch: int, dim: bool = false) -> void:
	var col: Color = BRANCH_COLORS[branch]
	if dim:
		col = col.lerp(Color("555060"), 0.7)
	ci.draw_colored_polygon(circle_points(c, r), col.darkened(0.45))
	outline(ci, circle_points(c, r), col, 3.0)
	match branch:
		UpgradeDB.Branch.COMBO:
			var bolt := PackedVector2Array([c + Vector2(r * 0.1, -r * 0.7), c + Vector2(-r * 0.4, r * 0.1), c + Vector2(-r * 0.02, r * 0.1),
				c + Vector2(-r * 0.15, r * 0.7), c + Vector2(r * 0.4, -r * 0.12), c + Vector2(r * 0.02, -r * 0.12)])
			ci.draw_colored_polygon(bolt, col.lightened(0.3))
		UpgradeDB.Branch.BOMB:
			ci.draw_colored_polygon(circle_points(c + Vector2(-r * 0.08, r * 0.12), r * 0.45), Color("1b1020"))
			ci.draw_line(c + Vector2(r * 0.15, -r * 0.2), c + Vector2(r * 0.42, -r * 0.5), Color("e6d0a0"), 3.0)
			ci.draw_colored_polygon(star_points(c + Vector2(r * 0.48, -r * 0.56), r * 0.2, 0.45), GOLD)
		UpgradeDB.Branch.CHROMA:
			var cols := [Color("ff5f6d"), Color("4cd17a"), Color("3fa7ff")]
			for i in 3:
				var off := Vector2.from_angle(-PI / 2 + TAU * i / 3) * r * 0.25
				ci.draw_colored_polygon(circle_points(c + off, r * 0.36), Color(cols[i], 0.85))
		UpgradeDB.Branch.MOMENTUM:
			var heart := PackedVector2Array()
			for i in 32:
				var t := TAU * i / 32
				var x := 16 * pow(sin(t), 3)
				var y := -(13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t))
				heart.append(c + Vector2(x, y) * r * 0.034 + Vector2(0, r * 0.05))
			ci.draw_colored_polygon(heart, col.lightened(0.25))
		UpgradeDB.Branch.ECONOMY:
			draw_coin(ci, c, r * 0.55)


static func draw_coin(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_colored_polygon(circle_points(c, r), GOLD.darkened(0.2))
	ci.draw_colored_polygon(circle_points(c + Vector2(-r * 0.05, -r * 0.05), r * 0.82), GOLD)
	ci.draw_arc(c, r * 0.55, 0, TAU, 18, GOLD.darkened(0.25), 2.0, true)
	ci.draw_colored_polygon(circle_points(c + Vector2(-r * 0.3, -r * 0.35), r * 0.15, 10), Color(1, 1, 1, 0.7))


# --- Text ---------------------------------------------------------------------

static func text(ci: CanvasItem, pos: Vector2, s: String, size: int, color: Color = TEXT,
		align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1, bold: bool = false) -> void:
	var f := bold_font() if bold else font()
	ci.draw_string(f, pos, s, align, width, size, color)


static func wrap_lines(s: String, size: int, max_width: float) -> PackedStringArray:
	var f := font()
	var lines := PackedStringArray()
	var line := ""
	for word in s.split(" "):
		var attempt := word if line.is_empty() else line + " " + word
		if f.get_string_size(attempt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > max_width and not line.is_empty():
			lines.append(line)
			line = word
		else:
			line = attempt
	if not line.is_empty():
		lines.append(line)
	return lines
