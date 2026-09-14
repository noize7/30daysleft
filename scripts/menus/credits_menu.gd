extends Control
## =============================================================================
## CreditsMenu — Créditos del equipo (escena separada)
## =============================================================================

signal closed

@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var credits_label: Label = $Panel/VBox/CreditsLabel
@onready var btn_back: Button = $Panel/VBox/BtnBack

const CREDITS_TEXT := """Alain Daniel — Programador
JesusVL — Programador
Lautaro Nahuel — Programador

Roberto — Historia y Marketing

Angel — Compositor y Artista
Fernando Marcano — Compositor

Christian — Artista

— 30 DAYS LEFT —
Gracias por jugar."""

func _ready() -> void:
	_apply_xp_style()
	credits_label.text = CREDITS_TEXT
	btn_back.pressed.connect(func(): closed.emit())

func _apply_xp_style() -> void:
	if has_node("Panel"):
		var ps := StyleBoxFlat.new()
		ps.bg_color = Color(0.925, 0.914, 0.847)
		ps.border_width_left = 3
		ps.border_width_top = 3
		ps.border_width_right = 3
		ps.border_width_bottom = 3
		ps.border_color = Color(0.0, 0.329, 0.890)
		ps.set_corner_radius_all(0)
		$Panel.add_theme_stylebox_override("panel", ps)

	if has_node("Wallpaper"):
		$Wallpaper.color = Color(0.15, 0.28, 0.48)

	if has_node("Panel"):
		var ps := StyleBoxFlat.new()
		ps.bg_color = Color(0.925, 0.914, 0.847)
		ps.border_width_left = 3
		ps.border_width_top = 3
		ps.border_width_right = 3
		ps.border_width_bottom = 3
		ps.border_color = Color(0.0, 0.329, 0.890)
		ps.set_corner_radius_all(0)
		$Panel.add_theme_stylebox_override("panel", ps)
	title_label.add_theme_color_override("font_color", Color(0.0, 0.18, 0.5))
	title_label.add_theme_font_size_override("font_size", 28)
	credits_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.15))
	credits_label.add_theme_font_size_override("font_size", 18)
	credits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.141, 0.369, 0.863)
	s.set_corner_radius_all(5)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	btn_back.add_theme_stylebox_override("normal", s)
	var h := s.duplicate()
	h.bg_color = Color(0.235, 0.506, 0.953)
	btn_back.add_theme_stylebox_override("hover", h)
	btn_back.add_theme_color_override("font_color", Color.WHITE)
	btn_back.add_theme_font_size_override("font_size", 18)
