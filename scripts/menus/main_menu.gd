extends Control
## =============================================================================
## MainMenu — Menú principal estilo Windows XP / 8
## Escena separada (no construida por código en runtime).
## =============================================================================

signal play_pressed
signal continue_pressed
signal options_pressed
signal credits_pressed
signal quit_pressed

@onready var title_label: Label = $CenterPanel/VBox/TitleLabel
@onready var subtitle_label: Label = $CenterPanel/VBox/SubtitleLabel
@onready var btn_play: Button = $CenterPanel/VBox/BtnPlay
@onready var btn_continue: Button = $CenterPanel/VBox/BtnContinue
@onready var btn_options: Button = $CenterPanel/VBox/BtnOptions
@onready var btn_credits: Button = $CenterPanel/VBox/BtnCredits
@onready var btn_quit: Button = $CenterPanel/VBox/BtnQuit
@onready var version_label: Label = $VersionLabel

func _ready() -> void:
	_apply_xp_style()
	btn_play.pressed.connect(func(): play_pressed.emit())
	btn_continue.pressed.connect(func(): continue_pressed.emit())
	btn_options.pressed.connect(func(): options_pressed.emit())
	btn_credits.pressed.connect(func(): credits_pressed.emit())
	btn_quit.pressed.connect(func(): quit_pressed.emit())
	_refresh_continue()

func _refresh_continue() -> void:
	var has_save := false
	if SaveManager and SaveManager.has_method("has_save"):
		has_save = SaveManager.has_save()
	elif FileAccess.file_exists("user://save/game_save.json"):
		has_save = true
	btn_continue.visible = has_save
	btn_continue.disabled = not has_save

func _apply_xp_style() -> void:
	# Fondo azul XP clásico
	if has_node("Wallpaper"):
		$Wallpaper.color = Color(0.227, 0.431, 0.647)

	# Panel central estilo ventana XP
	if has_node("CenterPanel"):
		var ps := StyleBoxFlat.new()
		ps.bg_color = Color(0.925, 0.914, 0.847)
		ps.border_width_left = 3
		ps.border_width_top = 3
		ps.border_width_right = 3
		ps.border_width_bottom = 3
		ps.border_color = Color(0.0, 0.329, 0.890)
		ps.set_corner_radius_all(0)
		$CenterPanel.add_theme_stylebox_override("panel", ps)
		title_label.add_theme_color_override("font_color", Color(0.0, 0.2, 0.55))
	else:
		title_label.add_theme_color_override("font_color", Color.WHITE)

	title_label.add_theme_font_size_override("font_size", 48)
	subtitle_label.add_theme_color_override("font_color", Color(0.2, 0.25, 0.35))
	subtitle_label.add_theme_font_size_override("font_size", 20)

	for btn in [btn_play, btn_continue, btn_options, btn_credits, btn_quit]:
		_style_button(btn)

	version_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	version_label.add_theme_font_size_override("font_size", 14)

func _style_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.141, 0.369, 0.863)
	normal.set_corner_radius_all(6)
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10
	normal.border_width_bottom = 2
	normal.border_color = Color(0.08, 0.22, 0.55)

	var hover := normal.duplicate()
	hover.bg_color = Color(0.235, 0.506, 0.953)

	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.10, 0.28, 0.70)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 22)
	btn.custom_minimum_size = Vector2(300, 54)
