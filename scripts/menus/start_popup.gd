extends Control
## Ventanita de Inicio estilo Windows (fija, no arrastrable)

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
	# Clic fuera del panel cierra el popup
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if panel and not panel.get_global_rect().has_point(event.global_position):
			visible = false
			closed.emit()

func show_popup() -> void:
	visible = true
	move_to_front()
	if panel:
		var vp := get_viewport_rect().size
		panel.size = Vector2(230, 150)
		panel.position = Vector2(10, vp.y - panel.size.y - 66)

func hide_popup() -> void:
	visible = false

func _style() -> void:
	if panel:
		var ps := StyleBoxFlat.new()
		ps.bg_color = Color(0.925, 0.914, 0.847)
		ps.border_width_left = 2
		ps.border_width_top = 2
		ps.border_width_right = 2
		ps.border_width_bottom = 2
		ps.border_color = Color(0.0, 0.329, 0.890)
		panel.add_theme_stylebox_override("panel", ps)
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.size = Vector2(230, 150)
	if title_label:
		title_label.text = "Inicio"
		title_label.add_theme_color_override("font_color", Color(0.0, 0.15, 0.45))
		title_label.add_theme_font_size_override("font_size", 20)
	if btn_cancel:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.141, 0.369, 0.863)
		s.set_corner_radius_all(4)
		s.content_margin_left = 10
		s.content_margin_right = 10
		s.content_margin_top = 8
		s.content_margin_bottom = 8
		btn_cancel.add_theme_stylebox_override("normal", s)
		var h := s.duplicate()
		h.bg_color = Color(0.235, 0.506, 0.953)
		btn_cancel.add_theme_stylebox_override("hover", h)
		btn_cancel.add_theme_color_override("font_color", Color.WHITE)
		btn_cancel.add_theme_font_size_override("font_size", 17)
		btn_cancel.custom_minimum_size = Vector2(190, 40)
	if btn_shutdown:
		var rs := StyleBoxFlat.new()
		rs.bg_color = Color(0.75, 0.15, 0.15)
		rs.set_corner_radius_all(4)
		rs.content_margin_left = 10
		rs.content_margin_right = 10
		rs.content_margin_top = 8
		rs.content_margin_bottom = 8
		btn_shutdown.add_theme_stylebox_override("normal", rs)
		var rh := rs.duplicate()
		rh.bg_color = Color(0.9, 0.25, 0.25)
		btn_shutdown.add_theme_stylebox_override("hover", rh)
		btn_shutdown.add_theme_color_override("font_color", Color.WHITE)
		btn_shutdown.add_theme_font_size_override("font_size", 17)
		btn_shutdown.custom_minimum_size = Vector2(190, 40)
		btn_shutdown.text = "Apagar PC"
