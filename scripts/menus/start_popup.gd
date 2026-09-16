extends Control
## Popup Inicio — estilo oscuro compacto

signal shutdown_pressed
signal closed

@onready var panel: Panel = $Panel
@onready var btn_shutdown: Button = $Panel/VBox/BtnShutdown
@onready var btn_cancel: Button = $Panel/VBox/BtnCancel
@onready var title_label: Label = $Panel/VBox/TitleLabel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_style()
	gui_input.connect(_on_bg_input)
	if btn_shutdown:
		btn_shutdown.pressed.connect(func():
			visible = false
			shutdown_pressed.emit()
		)
	if btn_cancel:
		btn_cancel.pressed.connect(func():
			visible = false
			closed.emit()
		)

func _on_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if panel and not panel.get_global_rect().has_point(event.global_position):
			visible = false
			closed.emit()

func show_popup() -> void:
	visible = true
	move_to_front()
	if panel:
		var vp := get_viewport_rect().size
		panel.size = Vector2(240, 160)
		panel.position = Vector2(12, vp.y - panel.size.y - 66)
		panel.modulate.a = 0.0
		panel.scale = Vector2(0.92, 0.92)
		panel.pivot_offset = panel.size * 0.5
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(panel, "modulate:a", 1.0, 0.12)
		tw.tween_property(panel, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func hide_popup() -> void:
	visible = false

func _style() -> void:
	if panel:
		var ps := StyleBoxFlat.new()
		ps.bg_color = Color(0.11, 0.13, 0.18, 0.96)
		ps.border_width_left = 1
		ps.border_width_top = 1
		ps.border_width_right = 1
		ps.border_width_bottom = 1
		ps.border_color = Color(0.4, 0.55, 0.85, 0.5)
		ps.set_corner_radius_all(10)
		ps.shadow_color = Color(0, 0, 0, 0.4)
		ps.shadow_size = 10
		panel.add_theme_stylebox_override("panel", ps)
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.size = Vector2(240, 160)
	if title_label:
		title_label.text = "Inicio"
		title_label.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
		title_label.add_theme_font_size_override("font_size", 18)
	if btn_cancel:
		_blue_btn(btn_cancel)
		btn_cancel.custom_minimum_size = Vector2(200, 38)
	if btn_shutdown:
		var rs := StyleBoxFlat.new()
		rs.bg_color = Color(0.55, 0.15, 0.18)
		rs.set_corner_radius_all(7)
		rs.content_margin_left = 10
		rs.content_margin_right = 10
		rs.content_margin_top = 8
		rs.content_margin_bottom = 8
		rs.border_width_left = 1
		rs.border_width_top = 1
		rs.border_width_right = 1
		rs.border_width_bottom = 1
		rs.border_color = Color(0.9, 0.35, 0.4, 0.5)
		btn_shutdown.add_theme_stylebox_override("normal", rs)
		var rh := rs.duplicate()
		rh.bg_color = Color(0.72, 0.22, 0.25)
		btn_shutdown.add_theme_stylebox_override("hover", rh)
		btn_shutdown.add_theme_color_override("font_color", Color.WHITE)
		btn_shutdown.add_theme_font_size_override("font_size", 16)
		btn_shutdown.custom_minimum_size = Vector2(200, 38)
		btn_shutdown.text = "Apagar PC"

func _blue_btn(btn: Button) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.18, 0.28, 0.48)
	s.set_corner_radius_all(7)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	s.border_width_left = 1
	s.border_width_top = 1
	s.border_width_right = 1
	s.border_width_bottom = 1
	s.border_color = Color(0.4, 0.55, 0.85, 0.4)
	btn.add_theme_stylebox_override("normal", s)
	var h := s.duplicate()
	h.bg_color = Color(0.28, 0.42, 0.72)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 16)
