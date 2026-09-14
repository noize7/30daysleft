extends Control
## PauseMenu — pausa real del juego (Escape)

signal resume_pressed
signal save_pressed
signal load_pressed
signal main_menu_pressed
signal quit_pressed

@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var btn_resume: Button = $Panel/VBox/BtnResume
@onready var btn_save: Button = $Panel/VBox/BtnSave
@onready var btn_load: Button = $Panel/VBox/BtnLoad
@onready var btn_main: Button = $Panel/VBox/BtnMainMenu
@onready var btn_quit: Button = $Panel/VBox/BtnQuit
@onready var status_label: Label = $Panel/VBox/StatusLabel

func _ready() -> void:
	# Debe procesar aunque el árbol esté pausado
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_xp_style()
	btn_resume.pressed.connect(func(): resume_pressed.emit())
	btn_save.pressed.connect(_on_save)
	btn_load.pressed.connect(_on_load)
	btn_main.pressed.connect(func(): main_menu_pressed.emit())
	btn_quit.pressed.connect(func(): quit_pressed.emit())
	visible = false

func show_pause() -> void:
	visible = true
	status_label.text = ""
	get_tree().paused = true

func hide_pause() -> void:
	visible = false
	get_tree().paused = false

func _on_save() -> void:
	if SaveManager and SaveManager.has_method("save_game"):
		SaveManager.save_game()
		status_label.text = "Partida guardada."
		status_label.add_theme_color_override("font_color", Color(0.1, 0.5, 0.1))
	else:
		status_label.text = "Error al guardar."
		status_label.add_theme_color_override("font_color", Color(0.7, 0.1, 0.1))
	save_pressed.emit()

func _on_load() -> void:
	if SaveManager and SaveManager.has_method("load_game"):
		var ok = SaveManager.load_game()
		if ok:
			status_label.text = "Partida cargada."
			status_label.add_theme_color_override("font_color", Color(0.1, 0.5, 0.1))
		else:
			status_label.text = "No hay partida guardada."
			status_label.add_theme_color_override("font_color", Color(0.7, 0.1, 0.1))
	load_pressed.emit()

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
	if title_label:
		title_label.add_theme_color_override("font_color", Color(0.0, 0.15, 0.45))
		title_label.add_theme_font_size_override("font_size", 28)
	for btn in [btn_resume, btn_save, btn_load, btn_main, btn_quit]:
		if btn == null:
			continue
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.141, 0.369, 0.863)
		s.set_corner_radius_all(5)
		s.content_margin_left = 14
		s.content_margin_right = 14
		s.content_margin_top = 10
		s.content_margin_bottom = 10
		btn.add_theme_stylebox_override("normal", s)
		var h := s.duplicate()
		h.bg_color = Color(0.235, 0.506, 0.953)
		btn.add_theme_stylebox_override("hover", h)
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_font_size_override("font_size", 20)
		btn.custom_minimum_size = Vector2(240, 48)
	if status_label:
		status_label.add_theme_font_size_override("font_size", 16)
