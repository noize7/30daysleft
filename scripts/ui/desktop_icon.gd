extends Control
class_name DesktopIcon
## =============================================================================
## DesktopIcon — Icono de escritorio estilo Windows XP
##
## FUNCIONALIDAD:
##   • Muestra textura personalizada O un cuadrado de color (fallback)
##   • Click corto  → emite señal "activated" (abre la app)
##   • Arrastrar    → mueve el icono libremente por el escritorio
##   • Se puede escalar con icon_scale
##
## CÓMO ASIGNAR TUS PROPIOS ICONOS:
##   1. Abre main.tscn → selecciona el nodo Main
##   2. Inspector → grupo "Iconos del escritorio"
##   3. Arrastra PNG/SVG a icon_trabajo / icon_correo / icon_archivos
##   4. Ajusta icon_scale (0.5 – 3.0)
## =============================================================================

## Señal emitida cuando el jugador hace click (sin arrastrar).
## app_name debe coincidir con el nombre que usa DesktopUI.open_app()
signal activated(app_name: String)

# --- EXPORTS (visibles en el Inspector de Godot) -----------------------------
## Nombre interno de la aplicación que se abrirá
@export var app_name: String = "App"
## Textura del icono. Si es null → se dibuja un cuadrado de color
@export var icon_texture: Texture2D
## Color del cuadrado cuando no hay textura asignada
@export var fallback_color: Color = Color(0.2, 0.4, 0.8)
## Escala visual (0.5 = pequeño, 1.0 = normal, 2.0 = grande)
@export_range(0.5, 3.0, 0.1) var icon_scale: float = 1.5

# --- Estado interno del arrastre --------------------------------------------
var _dragging: bool = false               # ¿Se está arrastrando ahora?
var _drag_offset: Vector2 = Vector2.ZERO  # Diferencia ratón ↔ posición del icono
var _press_pos: Vector2 = Vector2.ZERO    # Dónde se pulsó el botón
var _moved: bool = false                  # ¿Se superó el umbral de arrastre?

## Píxeles mínimos de movimiento para considerar "arrastre" y no "click"
const DRAG_THRESHOLD: float = 6.0

## Al entrar en el árbol de nodos: prepara cursor y dibuja el icono.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	mouse_entered.connect(_on_hover_enter)
	mouse_exited.connect(_on_hover_exit)
	_rebuild()

func _on_hover_enter() -> void:
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.08, 1.08), 0.12).set_ease(Tween.EASE_OUT)

func _on_hover_exit() -> void:
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE, 0.12).set_ease(Tween.EASE_OUT)

## Configura el icono desde código (llamado por Main._create_desktop_icons).
## p_name  → nombre de la app
## p_color → color de respaldo
## p_tex   → textura opcional (puede ser null)
## p_scale → escala visual
func setup(p_name: String, p_color: Color, p_tex: Texture2D, p_scale: float) -> void:
	app_name = p_name
	fallback_color = p_color
	icon_texture = p_tex
	icon_scale = p_scale
	_rebuild()

## Reconstruye los hijos visuales según textura y escala actuales.
func _rebuild() -> void:
	# Elimina visual anterior
	for child in get_children():
		child.queue_free()

	# Tamaños proporcionales a la escala
	var icon_sz: float = 56.0 * icon_scale
	var total_w: float = maxf(icon_sz + 24.0, 96.0 * icon_scale)
	var total_h: float = icon_sz + 36.0 * icon_scale
	custom_minimum_size = Vector2(total_w, total_h)
	size = Vector2(total_w, total_h)
	pivot_offset = Vector2(total_w * 0.5, total_h * 0.5)

	# --- Visual: textura personalizada o cuadrado de color -------------------
	if icon_texture != null:
		var tex_rect := TextureRect.new()
		tex_rect.texture = icon_texture
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.size = Vector2(icon_sz, icon_sz)
		tex_rect.position = Vector2((total_w - icon_sz) * 0.5, 4.0)
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tex_rect)
	else:
		# Fallback: panel redondeado con color (mientras no haya assets)
		var square := Panel.new()
		square.size = Vector2(icon_sz, icon_sz)
		square.position = Vector2((total_w - icon_sz) * 0.5, 4.0)
		square.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var st := StyleBoxFlat.new()
		st.bg_color = fallback_color
		st.set_corner_radius_all(int(10 * icon_scale))
		st.border_width_left = 2
		st.border_width_top = 2
		st.border_width_right = 2
		st.border_width_bottom = 2
		st.border_color = Color(1, 1, 1, 0.45)
		square.add_theme_stylebox_override("panel", st)
		add_child(square)

	# --- Etiqueta con el nombre de la app ------------------------------------
	var lbl := Label.new()
	lbl.text = app_name
	lbl.position = Vector2(0, icon_sz + 8.0 * icon_scale)
	lbl.size = Vector2(total_w, 30.0 * icon_scale)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", Color.WHITE)
	# Sombra para legibilidad sobre el wallpaper azul
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.add_theme_font_size_override("font_size", int(18 * icon_scale))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)

## Gestiona la diferencia entre click (abrir app) y arrastre (mover icono).
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				# Inicio de posible arrastre
				_dragging = true
				_moved = false
				_press_pos = mb.global_position
				# Offset para que el icono no "salte" al centro del cursor
				_drag_offset = position - get_parent().get_local_mouse_position()
				move_to_front()  # Traer al frente mientras se arrastra
				accept_event()
			else:
				# Soltar el botón
				if _dragging:
					_dragging = false
					# Si no se movió lo suficiente → es un click → abrir app
					if not _moved:
						# Feedback visual de click
						var tw := create_tween()
						tw.tween_property(self, "scale", Vector2(0.92, 0.92), 0.06)
						tw.tween_property(self, "scale", Vector2(1.08, 1.08), 0.08)
						if VFXSystem:
							VFXSystem.spawn_sparkles(global_position + size * 0.5, 6)
						activated.emit(app_name)
					_clamp_to_desktop()
					# Si se arrastró, guardar la nueva posición (persiste en el guardado)
					if _moved:
						GameManager.set_icon_position(app_name, position)
						if GameManager.is_pc_on:
							SaveManager.save_game()
					accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		# Si superó el umbral → ya no es click, es arrastre
		if _press_pos.distance_to(mm.global_position) > DRAG_THRESHOLD:
			_moved = true
		# Seguir al ratón
		position = get_parent().get_local_mouse_position() + _drag_offset
		_clamp_to_desktop()
		accept_event()

## Evita que el icono salga del escritorio (deja margen inferior para la taskbar).
func _clamp_to_desktop() -> void:
	var parent_ctrl := get_parent() as Control
	if parent_ctrl == null:
		return
	var max_x: float = parent_ctrl.size.x - size.x - 8.0
	var max_y: float = parent_ctrl.size.y - size.y - 60.0  # espacio taskbar
	position.x = clampf(position.x, 8.0, maxf(8.0, max_x))
	position.y = clampf(position.y, 8.0, maxf(8.0, max_y))
