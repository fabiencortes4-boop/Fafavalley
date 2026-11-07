class_name UiTheme
extends RefCounted
## Thème pixel art construit à partir du « UI Pack Pixel Adventure » de Kenney
## et de la police KenPixel (CC0).

const TEXT := Color(0.99, 0.95, 0.85)
const TEXT_DARK := Color(0.30, 0.18, 0.12)
const ACCENT := Color(1.0, 0.84, 0.36)
const FONT_PATH := "res://assets/kenney/fonts/kenpixel_mini_square.ttf"
const FONT_SIZE := 8

static var _font: FontFile


static func font() -> FontFile:
	if _font == null:
		_font = load(FONT_PATH)
		_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		_font.hinting = TextServer.HINTING_NONE
		_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return _font


## Boîte 9-slice à partir d'une tuile 16x16 de l'UI pack.
static func box(texture_name: String, margin: int = 5, padding: int = 5) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load("res://assets/sprites/%s.png" % texture_name)
	sb.set_texture_margin_all(margin)
	sb.set_content_margin_all(padding)
	return sb


static func build() -> Theme:
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = Settings.font_size()
	var panel := box("ui_panel", 5, 7)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_shadow_color", "Label", Color(0.15, 0.08, 0.05, 0.9))
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 1)
	t.set_constant("line_spacing", "Label", 1)

	var normal := box("ui_button", 5, 6)
	var hover := box("ui_button", 5, 6)
	hover.modulate_color = Color(1.08, 1.05, 0.95)
	var pressed := box("ui_button", 5, 6)
	pressed.modulate_color = Color(0.82, 0.76, 0.68)
	pressed.content_margin_top = 7
	pressed.content_margin_bottom = 5
	var disabled := box("ui_button_disabled", 5, 6)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("hover_pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(state, "Button", TEXT_DARK)
	t.set_color("font_disabled_color", "Button", Color(0.85, 0.88, 0.92))

	var bar_bg := box("ui_slot", 4, 2)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.45, 0.80, 0.36)
	bar_fill.set_border_width_all(0)
	bar_fill.set_expand_margin_all(-3)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill)
	return t
