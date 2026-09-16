extends Panel
class_name AppWindow
## =============================================================================
## AppWindow — Ventana estilo Windows XP (arrastrable)
## =============================================================================

signal closed

@onready var title_bar: Panel = $TitleBar
@onready var title_label: Label = $TitleBar/TitleLabel
@onready var close_btn: Button = $TitleBar/CloseButton
@onready var content: Control = $Content

@export var app_title: String = "Aplicación"
@export var window_size: Vector2 = Vector2(620, 480)
@export var title_font_size: int = 25

var _signals_connected: bool = false
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	_apply_xp_style()
	_connect_ui_signals()
	_apply_layout()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_clamp_to_viewport()

func setup(title: String, wsize: Vector2 = Vector2(620, 480)) -> void:
	app_title = title
	window_size = wsize
	_apply_layout()
	_apply_xp_style()
	_connect_ui_signals()
	_clamp_to_viewport()
	# Animación solo aquí (tras add_child + tamaño real)
	_play_open_anim()

## Aparición suave al abrir (escala + fade)
func _play_open_anim() -> void:
	if size.x < 2.0 or size.y < 2.0:
		modulate.a = 1.0
		scale = Vector2.ONE
		return
	pivot_offset = size * 0.5
	scale = Vector2(0.97, 0.97)
	modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2.ONE, 0.15).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.12)


## Evita que la ventana quede más grande que la pantalla o fuera de ella
## (se llama al crearla y cada vez que cambia el tamaño de la ventana del juego).
func _clamp_to_viewport() -> void:
	var vp: Vector2 = get_viewport_rect().size
	var w: Vector2 = size
	w.x = minf(w.x, maxf(320.0, vp.x - 20.0))
	w.y = minf(w.y, maxf(240.0, vp.y - 78.0))
	if w != size:
		size = w
		custom_minimum_size = w
	position.x = clampf(position.x, 0.0, maxf(0.0, vp.x - size.x))
	position.y = clampf(position.y, 0.0, maxf(0.0, vp.y - size.y - 58.0))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED or what == NOTIFICATION_RESIZED:
		if is_inside_tree():
			_clamp_to_viewport()

func _apply_layout() -> void:
	size = window_size
	custom_minimum_size = window_size
	var tb := get_node_or_null("TitleBar") as Panel
	var tl := get_node_or_null("TitleBar/TitleLabel") as Label
	var cb := get_node_or_null("TitleBar/CloseButton") as Button
	var ct := get_node_or_null("Content") as Control
	var tb_h: float = 46.0
	if tb:
		tb.position = Vector2(0, 0)
		tb.size = Vector2(window_size.x, tb_h)
		tb.mouse_filter = Control.MOUSE_FILTER_STOP
	if tl:
		tl.text = app_title
		tl.position = Vector2(14, 8)
		tl.size = Vector2(window_size.x - 64, tb_h - 12)
		tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if cb:
		cb.position = Vector2(window_size.x - 46, 7)
		cb.size = Vector2(38, 34)
	if ct:
		ct.position = Vector2(12, tb_h + 6)
		ct.size = Vector2(window_size.x - 24, window_size.y - tb_h - 18)

func _connect_ui_signals() -> void:
	if _signals_connected:
		return
	var cb := get_node_or_null("TitleBar/CloseButton") as Button
	var tb := get_node_or_null("TitleBar") as Panel
	if cb and not cb.pressed.is_connected(_on_close_pressed):
		cb.pressed.connect(_on_close_pressed)
	if tb and not tb.gui_input.is_connected(_on_title_input):
		tb.gui_input.connect(_on_title_input)
	_signals_connected = true

func _on_close_pressed() -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2(0.94, 0.94), 0.12).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "modulate:a", 0.0, 0.12)
	tw.chain().tween_callback(func():
		visible = false
		modulate.a = 1.0
		scale = Vector2.ONE
		closed.emit()
	)

func _on_title_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging = true
				_drag_offset = get_global_mouse_position() - global_position
				move_to_front()
				accept_event()
			else:
				_dragging = false
				accept_event()
	elif event is InputEventMouseMotion and _dragging:
		global_position = get_global_mouse_position() - _drag_offset
		# La ventana completa debe quedar dentro de la pantalla (deja sitio a la taskbar)
		var vp := get_viewport_rect().size
		position.x = clampf(position.x, 0.0, maxf(0.0, vp.x - size.x))
		position.y = clampf(position.y, 0.0, maxf(0.0, vp.y - size.y - 58.0))
		accept_event()

func _apply_xp_style() -> void:
	# Cuerpo de ventana: beige suave + borde azul + sombra
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.94, 0.93, 0.88)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.12, 0.32, 0.72)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 12
	add_theme_stylebox_override("panel", style)

	# Barra de título azul con esquinas superiores redondeadas
	var tb := get_node_or_null("TitleBar") as Panel
	if tb:
		var tb_style := StyleBoxFlat.new()
		tb_style.bg_color = Color(0.08, 0.28, 0.68)
		tb_style.corner_radius_top_left = 5
		tb_style.corner_radius_top_right = 5
		tb_style.corner_radius_bottom_right = 0
		tb_style.corner_radius_bottom_left = 0
		tb_style.border_width_bottom = 1
		tb_style.border_color = Color(0.25, 0.5, 0.95, 0.5)
		tb.add_theme_stylebox_override("panel", tb_style)

	var tl := get_node_or_null("TitleBar/TitleLabel") as Label
	if tl:
		tl.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
		tl.add_theme_font_size_override("font_size", title_font_size)

	# Botón cerrar más limpio
	var cb := get_node_or_null("TitleBar/CloseButton") as Button
	if cb:
		var close_style := StyleBoxFlat.new()
		close_style.bg_color = Color(0.78, 0.12, 0.16)
		close_style.set_corner_radius_all(4)
		close_style.content_margin_left = 6
		close_style.content_margin_right = 6
		cb.add_theme_stylebox_override("normal", close_style)
		var ch := close_style.duplicate()
		ch.bg_color = Color(0.95, 0.25, 0.28)
		cb.add_theme_stylebox_override("hover", ch)
		var cp := close_style.duplicate()
		cp.bg_color = Color(0.55, 0.08, 0.1)
		cb.add_theme_stylebox_override("pressed", cp)
		cb.add_theme_color_override("font_color", Color.WHITE)
		cb.add_theme_font_size_override("font_size", 15)
		cb.text = "X"
