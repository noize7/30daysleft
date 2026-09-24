extends Control
## PauseMenu — estilo oscuro pulido

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
	if LocaleSystem and not LocaleSystem.language_changed.is_connected(_apply_locale):
		LocaleSystem.language_changed.connect(func(_l): _apply_locale())

	process_mode = Node.PROCESS_MODE_ALWAYS
	# Por encima de diálogos (z=100) y del escritorio
	z_index = 250
	z_as_relative = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_style()
	btn_resume.pressed.connect(func():
		_play_ui_click()
		resume_pressed.emit()
	)
	btn_save.pressed.connect(_on_save)
	btn_load.pressed.connect(_on_load)
	btn_main.pressed.connect(func():
		_play_ui_click()
		main_menu_pressed.emit()
	)
	btn_quit.pressed.connect(func():
		_play_ui_click()
		quit_pressed.emit()
	)
	for btn in [btn_resume, btn_save, btn_load, btn_main, btn_quit]:
		if btn:
			btn.mouse_entered.connect(_hover.bind(btn))
			btn.mouse_exited.connect(_unhover.bind(btn))
	visible = false

func _play_ui_click() -> void:
	if SoundSystem:
		SoundSystem.play_button()

func _hover(btn: Button) -> void:
	var tw := create_tween()
	tw.tween_property(btn, "scale", Vector2(1.04, 1.04), 0.08)

func _unhover(btn: Button) -> void:
	var tw := create_tween()
	tw.tween_property(btn, "scale", Vector2.ONE, 0.08)

func show_pause() -> void:
	visible = true
	# Siempre encima de diálogos / misiones / escritorio
	z_index = 250
	z_as_relative = false
	move_to_front()
	if status_label:
		status_label.text = ""
	modulate.a = 0.0
	if has_node("Panel"):
		$Panel.scale = Vector2(0.95, 0.95)
		$Panel.pivot_offset = $Panel.size * 0.5
	# Pausar TODO el juego (diálogos, misiones, tiempo, batería…)
	get_tree().paused = true
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)  # la animación del menú sigue en pausa
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.2)
	if has_node("Panel"):
		tw.tween_property($Panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func hide_pause() -> void:
	visible = false
	get_tree().paused = false

func _on_save() -> void:
	_play_ui_click()
	if SaveManager and SaveManager.has_method("save_game"):
		SaveManager.save_game()
		status_label.text = "✓ Partida guardada"
		status_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.55))
	else:
		status_label.text = "Error al guardar"
		status_label.add_theme_color_override("font_color", Color(0.95, 0.35, 0.35))
	save_pressed.emit()

func _on_load() -> void:
	_play_ui_click()
	if SaveManager and SaveManager.has_method("load_game"):
		var ok = SaveManager.load_game()
		if ok:
			status_label.text = "✓ Partida cargada"
			status_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.55))
		else:
			status_label.text = "No hay partida guardada"
			status_label.add_theme_color_override("font_color", Color(0.95, 0.55, 0.35))
	load_pressed.emit()

func _apply_style() -> void:
	call_deferred("_apply_locale")
	# Dim overlay if missing
	if not has_node("Dim"):
		var dim := ColorRect.new()
		dim.name = "Dim"
		dim.color = Color(0.02, 0.03, 0.06, 0.65)
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dim.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(dim)
		move_child(dim, 0)

	if has_node("Panel"):
		var ps := StyleBoxFlat.new()
		ps.bg_color = Color(0.11, 0.13, 0.18, 0.96)
		ps.border_width_left = 1
		ps.border_width_top = 1
		ps.border_width_right = 1
		ps.border_width_bottom = 1
		ps.border_color = Color(0.4, 0.55, 0.85, 0.5)
		ps.set_corner_radius_all(12)
		ps.shadow_color = Color(0, 0, 0, 0.5)
		ps.shadow_size = 14
		$Panel.add_theme_stylebox_override("panel", ps)

	if title_label:
		title_label.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
		title_label.add_theme_font_size_override("font_size", 36)
		title_label.text = "PAUSA"

	for btn in [btn_resume, btn_save, btn_load, btn_main, btn_quit]:
		if btn == null:
			continue
		_style_btn(btn)
		btn.pivot_offset = Vector2(120, 24)

	if status_label:
		status_label.add_theme_font_size_override("font_size", 20)
		status_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.85))

func _style_btn(btn: Button) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.18, 0.28, 0.48)
	s.set_corner_radius_all(8)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	s.border_width_left = 1
	s.border_width_top = 1
	s.border_width_right = 1
	s.border_width_bottom = 1
	s.border_color = Color(0.4, 0.55, 0.85, 0.4)
	btn.add_theme_stylebox_override("normal", s)
	var h := s.duplicate()
	h.bg_color = Color(0.28, 0.42, 0.72)
	h.border_color = Color(0.55, 0.75, 1.0, 0.65)
	btn.add_theme_stylebox_override("hover", h)
	var p := s.duplicate()
	p.bg_color = Color(0.12, 0.2, 0.38)
	btn.add_theme_stylebox_override("pressed", p)
	btn.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
	btn.add_theme_font_size_override("font_size", 24)
	btn.custom_minimum_size = Vector2(300, 56)


func _apply_locale() -> void:
	if LocaleSystem == null:
		return
	if title_label:
		title_label.text = LocaleSystem.t("pause.title", "Pausa")
	var map = {
		"BtnResume": "pause.resume",
		"BtnSave": "pause.save",
		"BtnLoad": "pause.load",
		"BtnMainMenu": "pause.main_menu",
		"BtnQuit": "pause.quit",
	}
	for node_name in map:
		var b = find_child(node_name, true, false)
		if b and b is Button:
			b.text = LocaleSystem.t(map[node_name], b.text)
