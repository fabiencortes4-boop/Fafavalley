class_name UiTheme
extends RefCounted
## Thème « bois et parchemin » construit en code (pas de fichier .tres à maintenir).

const BG := Color(0.24, 0.16, 0.10, 0.92)
const BORDER := Color(0.62, 0.43, 0.22)
const TEXT := Color(0.98, 0.93, 0.80)
const ACCENT := Color(0.95, 0.80, 0.35)


static func box(bg: Color, border: Color, border_width: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(4)
	return sb


static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 10
	t.set_stylebox("panel", "PanelContainer", box(BG, BORDER))
	t.set_stylebox("panel", "Panel", box(BG, BORDER))
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", Color(0.1, 0.06, 0.03))
	t.set_constant("outline_size", "Label", 2)
	var normal := box(Color(0.45, 0.30, 0.16), BORDER)
	normal.set_content_margin_all(5)
	var hover := box(Color(0.55, 0.38, 0.20), ACCENT)
	hover.set_content_margin_all(5)
	var pressed := box(Color(0.35, 0.22, 0.12), ACCENT)
	pressed.set_content_margin_all(5)
	var disabled := box(Color(0.30, 0.24, 0.18), Color(0.4, 0.34, 0.28))
	disabled.set_content_margin_all(5)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", ACCENT)
	t.set_color("font_disabled_color", "Button", Color(0.6, 0.55, 0.5))
	t.set_stylebox("background", "ProgressBar", box(Color(0.15, 0.1, 0.06, 0.9), BORDER, 1))
	t.set_stylebox("fill", "ProgressBar", box(Color(0.45, 0.78, 0.35), Color(0.3, 0.6, 0.25), 1))
	return t
