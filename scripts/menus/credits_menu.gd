extends Control
## CreditsMenu — estilo oscuro

signal closed

@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var credits_label: Label = $Panel/VBox/CreditsLabel
@onready var btn_back: Button = $Panel/VBox/BtnBack

const CREDITS_TEXT := """Alain Daniel — Programador
JesusVL — Programador
Roberto — Historia y Marketing
Angel — Compositor y Artista
Fernando Marcano — Compositor

— 30 DAYS LEFT —
Gracias por jugar."""

func _ready() -> void:
	_apply_style()
	credits_label.text = CREDITS_TEXT
	btn_back.pressed.connect(func():
		if SoundSystem:
			SoundSystem.play_button()
		closed.emit()
	)
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.35)

func _apply_style() -> void:
	if has_node("Wallpaper"):
		$Wallpaper.color = Color(0.05, 0.07, 0.12)

	if has_node("Panel"):
		var ps := StyleBoxFlat.new()
		ps.bg_color = Color(0.11, 0.13, 0.18, 0.95)
		ps.border_width_left = 1
		ps.border_width_top = 1
		ps.border_width_right = 1
		ps.border_width_bottom = 1
		ps.border_color = Color(0.4, 0.55, 0.85, 0.5)
		ps.set_corner_radius_all(12)
		ps.shadow_color = Color(0, 0, 0, 0.45)
		ps.shadow_size = 14
		$Panel.add_theme_stylebox_override("panel", ps)

	if title_label:
		title_label.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
		title_label.add_theme_font_size_override("font_size", 40)
		title_label.text = LocaleSystem.t("credits.title", "CRÉDITOS") if LocaleSystem else "CRÉDITOS"
	if credits_label:
		credits_label.add_theme_color_override("font_color", Color(0.7, 0.78, 0.9))
		credits_label.add_theme_font_size_override("font_size", 22)
		credits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	if btn_back:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.18, 0.28, 0.48)
		s.set_corner_radius_all(8)
		s.content_margin_left = 16
		s.content_margin_right = 16
		s.content_margin_top = 10
		s.content_margin_bottom = 10
		s.border_width_left = 1
		s.border_width_top = 1
		s.border_width_right = 1
		s.border_width_bottom = 1
		s.border_color = Color(0.4, 0.55, 0.85, 0.45)
		btn_back.add_theme_stylebox_override("normal", s)
		var h := s.duplicate()
		h.bg_color = Color(0.28, 0.42, 0.72)
		btn_back.add_theme_stylebox_override("hover", h)
		btn_back.add_theme_color_override("font_color", Color.WHITE)
		btn_back.add_theme_font_size_override("font_size", 24)
