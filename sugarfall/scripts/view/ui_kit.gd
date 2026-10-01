class_name UiKit
extends RefCounted
## Theme and small widget factories shared by every screen.

static var _theme: Theme


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = Palette.font()
	t.default_font_size = 26
	t.set_color("font_color", "Label", Palette.TEXT)

	t.set_stylebox("normal", "Button", box(Palette.ACCENT, 20, Palette.ACCENT.lightened(0.3), 0, 22, 12))
	t.set_stylebox("hover", "Button", box(Palette.ACCENT.lightened(0.12), 20, Color.WHITE, 2, 22, 12))
	t.set_stylebox("pressed", "Button", box(Palette.ACCENT.darkened(0.2), 20, Color.WHITE, 2, 22, 12))
	t.set_stylebox("disabled", "Button", box(Color("5a4566"), 20, Color("5a4566"), 0, 22, 12))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_font("font", "Button", Palette.bold_font())
	t.set_font_size("font_size", "Button", 28)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(state, "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color("a898b0"))

	t.set_stylebox("panel", "PanelContainer", box(Color("2c1340", 0.97), 30, Color("ff9fd0", 0.8), 3, 30, 26))
	_theme = t
	return t


static func box(bg: Color, radius: int, border: Color = Color.TRANSPARENT, border_w: int = 0,
		margin_h: float = 16, margin_v: float = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(border_w)
	s.content_margin_left = margin_h
	s.content_margin_right = margin_h
	s.content_margin_top = margin_v
	s.content_margin_bottom = margin_v
	s.anti_aliasing = true
	return s


static func label(text: String, size: int = 26, color: Color = Palette.TEXT, bold: bool = false,
		align: int = HORIZONTAL_ALIGNMENT_CENTER, wrap: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", Palette.bold_font())
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func button(text: String, on_press: Callable, min_width: float = 360) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 76)
	b.pressed.connect(on_press)
	return b


## Full-screen dimmed layer with a centered column. Returns [root, column].
static func modal(dim: float = 0.72) -> Array:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.theme = theme()
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.0, 0.08, dim)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(660, 0)
	column.add_theme_constant_override("separation", 18)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(column)
	return [root, column]


static func panel(child_separation: int = 14) -> Array:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", child_separation)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	return [p, v]


static func clear_children(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()
