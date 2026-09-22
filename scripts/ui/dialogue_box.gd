extends Control
## =============================================================================
## DialogueBox — UI del sistema de diálogos (mejorado)
##
## - Caja inferior estilo terminal + avatar de robot a la izquierda.
## - Texto con efecto typewriter (aparece poco a poco).
## - Continuar / click en panel salta el typewriter o avanza el diálogo.
## - Durante "waiting" el botón se oculta y se muestra la pista.
## - Botón Continuar un poco más arriba y mejor espaciado.
## - Transiciones de fade robustas sin parpadeos.
## =============================================================================

signal continue_pressed
signal typing_finished

@onready var panel: Panel = $Panel
@onready var portrait: TextureRect = $Panel/HBox/PortraitFrame/Portrait
@onready var portrait_label: Label = $Panel/HBox/PortraitFrame/Portrait/BotLabel
@onready var speaker_label: Label = $Panel/HBox/VBox/SpeakerLabel
@onready var body_label: Label = $Panel/HBox/VBox/BodyLabel
@onready var continue_btn: Button = $Panel/HBox/VBox/ContinueButton
@onready var waiting_label: Label = $Panel/HBox/VBox/WaitingLabel

var _is_waiting: bool = false
var _is_typing: bool = false
var _full_text: String = ""
var _type_tween: Tween = null
var _fade_tween: Tween = null
var _chars_per_second: float = 22.0  # typewriter más lento y legible
var _typed_chars: int = 0

func _ready() -> void:
	visible = false
	modulate.a = 0.0
	# El Control raíz NO bloquea clicks al escritorio. Solo el Panel captura ratón.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_style()
	_reposition_button()
	if continue_btn:
		continue_btn.pressed.connect(_on_continue)
	if panel:
		panel.mouse_filter = Control.MOUSE_FILTER_STOP

func _apply_style() -> void:
	# Panel oscuro tipo terminal
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.09, 0.14, 0.96)
	style.set_corner_radius_all(10)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.25, 0.55, 0.85, 0.7)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 10
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 8
	if panel:
		panel.add_theme_stylebox_override("panel", style)

	if portrait_label:
		portrait_label.text = "BOT"
		portrait_label.add_theme_color_override("font_color", Color(0.45, 0.85, 1.0))
		portrait_label.add_theme_font_size_override("font_size", 22)
		portrait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		portrait_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	if speaker_label:
		speaker_label.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
		speaker_label.add_theme_font_size_override("font_size", 20)
	if body_label:
		body_label.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
		body_label.add_theme_font_size_override("font_size", 18)
		body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body_label.visible_characters = 0
	if waiting_label:
		waiting_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		waiting_label.add_theme_font_size_override("font_size", 16)
		waiting_label.visible = false
	if continue_btn:
		continue_btn.text = "Continuar ▶"
		continue_btn.add_theme_font_size_override("font_size", 17)
		# Estilo del botón un poco más visible
		var btn_style := StyleBoxFlat.new()
		btn_style.bg_color = Color(0.15, 0.35, 0.55, 0.95)
		btn_style.set_corner_radius_all(6)
		btn_style.content_margin_left = 14
		btn_style.content_margin_right = 14
		btn_style.content_margin_top = 6
		btn_style.content_margin_bottom = 6
		btn_style.border_width_left = 1
		btn_style.border_width_top = 1
		btn_style.border_width_right = 1
		btn_style.border_width_bottom = 1
		btn_style.border_color = Color(0.4, 0.7, 1.0, 0.6)
		continue_btn.add_theme_stylebox_override("normal", btn_style)
		var btn_hover := btn_style.duplicate()
		btn_hover.bg_color = Color(0.22, 0.45, 0.7, 0.98)
		continue_btn.add_theme_stylebox_override("hover", btn_hover)
		var btn_pressed := btn_style.duplicate()
		btn_pressed.bg_color = Color(0.1, 0.28, 0.48, 1.0)
		continue_btn.add_theme_stylebox_override("pressed", btn_pressed)

## Sube la caja y el botón Continuar de forma clara (más arriba en pantalla).
func _reposition_button() -> void:
	if panel:
		# Más arriba: deja margen sobre la taskbar y da aire al botón
		panel.offset_top = -230.0
		panel.offset_bottom = -78.0
	if continue_btn:
		continue_btn.custom_minimum_size = Vector2(150, 34)
		var vbox = panel.get_node_or_null("HBox/VBox") if panel else null
		if vbox and vbox is VBoxContainer:
			vbox.add_theme_constant_override("separation", 6)

func show_dialogue(speaker: String, text: String, waiting: bool = false) -> void:
	# Cancelar cualquier tween anterior para evitar parpadeos / race conditions
	_kill_tweens()

	visible = true
	if speaker_label:
		speaker_label.text = speaker
		# Color distinto si habla el jugador
		var is_player := speaker.strip_edges().to_upper() in ["TÚ", "TU", "JUGADOR", "YO"]
		if is_player:
			speaker_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
		else:
			speaker_label.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))

	_full_text = text
	_is_waiting = waiting

	if body_label:
		body_label.text = _full_text
		body_label.visible_characters = 0

	# Ocultar controles mientras escribimos
	if continue_btn:
		continue_btn.visible = false
		continue_btn.disabled = true
	if waiting_label:
		waiting_label.visible = false

	# Fade-in suave
	modulate.a = 0.0
	_fade_tween = create_tween()
	_fade_tween.set_ease(Tween.EASE_OUT)
	_fade_tween.set_trans(Tween.TRANS_CUBIC)
	_fade_tween.tween_property(self, "modulate:a", 1.0, 0.22)

	# Typewriter
	_start_typewriter()

func hide_dialogue() -> void:
	_kill_tweens()
	_is_typing = false
	_fade_tween = create_tween()
	_fade_tween.set_ease(Tween.EASE_IN)
	_fade_tween.tween_property(self, "modulate:a", 0.0, 0.18)
	_fade_tween.tween_callback(func():
		visible = false
		if body_label:
			body_label.visible_characters = 0
	)

func set_waiting(waiting: bool) -> void:
	_is_waiting = waiting
	_update_controls_visibility()

func highlight_hint(app_name: String) -> void:
	if waiting_label:
		waiting_label.text = "→ Toca el icono «%s» del escritorio" % app_name
		if _is_waiting and not _is_typing:
			waiting_label.visible = true

func _start_typewriter() -> void:
	_is_typing = true
	_typed_chars = 0
	if body_label == null or _full_text.is_empty():
		_finish_typing()
		return

	var total_chars: int = _full_text.length()
	body_label.visible_characters = 0

	# Typewriter por pasos: cada letra (o grupo) avanza y puede sonar
	var delay: float = 1.0 / maxf(1.0, _chars_per_second)
	_type_tween = create_tween()
	for i in range(1, total_chars + 1):
		_type_tween.tween_callback(_type_step.bind(i))
		_type_tween.tween_interval(delay)
	_type_tween.tween_callback(_finish_typing)

func _type_step(visible_count: int) -> void:
	if not _is_typing or body_label == null:
		return
	body_label.visible_characters = visible_count
	_typed_chars = visible_count
	# Sonido de letra (cada N caracteres; no en espacios/saltos de línea)
	if SoundSystem and SoundSystem.sfx_typewriter:
		var every_n: int = maxi(1, SoundSystem.typewriter_every_n_chars)
		if visible_count % every_n == 0:
			var ch: String = _full_text[visible_count - 1] if visible_count > 0 and visible_count <= _full_text.length() else ""
			if ch != " " and ch != "\n" and ch != "\t":
				SoundSystem.play_typewriter()

func _finish_typing() -> void:
	if not _is_typing:
		return
	_is_typing = false
	if body_label:
		body_label.visible_characters = -1  # mostrar todo
	_update_controls_visibility()
	typing_finished.emit()

func _update_controls_visibility() -> void:
	if _is_typing:
		if continue_btn:
			continue_btn.visible = false
			continue_btn.disabled = true
		if waiting_label:
			waiting_label.visible = false
		return

	if _is_waiting:
		if continue_btn:
			continue_btn.visible = false
			continue_btn.disabled = true
		if waiting_label:
			waiting_label.visible = true
			if waiting_label.text.is_empty() or waiting_label.text.begins_with("→ Haz"):
				waiting_label.text = "→ Haz lo que te indico para continuar…"
	else:
		if continue_btn:
			continue_btn.visible = true
			continue_btn.disabled = false
		if waiting_label:
			waiting_label.visible = false

func _skip_typing() -> void:
	if not _is_typing:
		return
	_kill_type_tween()
	if body_label:
		body_label.visible_characters = -1
	_finish_typing()

func _on_continue() -> void:
	if _is_waiting:
		return
	if _is_typing:
		_skip_typing()
		return
	if SoundSystem:
		SoundSystem.play_button()
	continue_pressed.emit()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Solo reaccionar si el click cae sobre el panel
		if panel and panel.get_global_rect().has_point(event.global_position):
			if _is_waiting:
				return
			if _is_typing:
				_skip_typing()
			else:
				if SoundSystem:
					SoundSystem.play_button()
				continue_pressed.emit()

func _kill_tweens() -> void:
	_kill_type_tween()
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null

func _kill_type_tween() -> void:
	if _type_tween and _type_tween.is_valid():
		_type_tween.kill()
	_type_tween = null

func is_typing() -> bool:
	return _is_typing
