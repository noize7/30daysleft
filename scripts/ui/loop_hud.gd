extends CanvasLayer
## =============================================================================
## LoopHUD — Interfaz del loop diario  [TANDA 9]
## La crea LoopSystem por código (no requiere escena):
##   - Panel "TURNO" arriba a la derecha (cuota, racha, encargos, acciones)
##   - Avisos (toasts) arriba al centro
##   - Ventana modal para los eventos con decisiones
## =============================================================================

const XP_BODY := Color(0.94, 0.93, 0.88)
const XP_PANEL := Color(0.82, 0.82, 0.78)
const XP_BLUE := Color(0.08, 0.28, 0.68)
const XP_BLUE_DARK := Color(0.03, 0.16, 0.48)
const XP_HIGHLIGHT := Color(1.0, 1.0, 1.0)
const XP_SHADOW := Color(0.42, 0.42, 0.40)
const XP_TEXT := Color(0.05, 0.05, 0.05)
const XP_DISABLED := Color(0.45, 0.45, 0.43)
const XP_GREEN := Color(0.0, 0.45, 0.05)
const XP_RED := Color(0.65, 0.05, 0.05)
const XP_YELLOW := Color(0.45, 0.30, 0.0)

var _panel: PanelContainer
var _body: VBoxContainer
var _toggle: Button
var _quota_label: Label
var _quota_bar: ProgressBar
var _streak_label: Label
var _contract_labels: Array = []
var _rest_btn: Button
var _tracks_btn: Button

var _toast_panel: PanelContainer
var _toast_label: Label
var _toast_tween: Tween
var _toast_queue: Array = []
var _toast_busy: bool = false

var _modal: Control
var _modal_title: Label
var _modal_text: Label
var _modal_result: Label
var _modal_choices: VBoxContainer
var _refresh_accum: float = 0.0


func _ready() -> void:
	layer = 45
	_build_panel()
	_build_toast()
	_build_modal()
	LoopSystem.state_changed.connect(_refresh)
	LoopSystem.toast.connect(_show_toast)
	GameManager.money_changed.connect(func(_m): _refresh())
	EventSystem.event_requested.connect(_show_event)
	EventSystem.event_closed.connect(_hide_modal)
	_apply_collapsed()
	_refresh()


func _process(delta: float) -> void:
	var show_hud: bool = GameManager.is_pc_on and not GameManager.is_game_over and not GameManager.tutorial_active
	_panel.visible = show_hud
	if not show_hud:
		_toast_panel.visible = false
		if _modal.visible and not EventSystem.is_active():
			_modal.visible = false
	_refresh_accum += delta
	if _refresh_accum >= 0.25:
		_refresh_accum = 0.0
		if show_hud:
			_refresh()



# =============================================================================
# ESTILO
# =============================================================================

func _style_box(bg: Color, border: Color, radius: int = 0, margin: int = 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = border
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = margin
	sb.content_margin_right = margin
	sb.content_margin_top = margin
	sb.content_margin_bottom = margin
	return sb


func _xp_bevel(bg: Color = XP_PANEL, margin: int = 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = XP_SHADOW
	sb.expand_margin_left = 0
	sb.expand_margin_top = 0
	sb.expand_margin_right = 0
	sb.expand_margin_bottom = 0
	sb.content_margin_left = margin
	sb.content_margin_right = margin
	sb.content_margin_top = margin
	sb.content_margin_bottom = margin
	return sb


func _make_label(text: String, size: int, color: Color = XP_TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _make_button(text: String, size: int = 16) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", XP_TEXT)
	b.add_theme_color_override("font_hover_color", XP_TEXT)
	b.add_theme_color_override("font_pressed_color", XP_TEXT)
	b.add_theme_color_override("font_disabled_color", XP_DISABLED)
	var normal := _xp_bevel()
	normal.border_color = XP_SHADOW
	var hover := _xp_bevel(Color(0.88, 0.88, 0.84))
	hover.border_color = Color(0.18, 0.36, 0.70)
	var pressed := _xp_bevel(Color(0.72, 0.72, 0.68))
	pressed.border_color = XP_SHADOW
	var disabled := _xp_bevel(Color(0.78, 0.78, 0.74))
	disabled.border_color = Color(0.60, 0.60, 0.57)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_stylebox_override("disabled", disabled)
	return b


func _make_xp_progress() -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 18)
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", _xp_bevel(Color(0.98, 0.98, 0.96), 2))
	var fill := StyleBoxFlat.new()
	fill.bg_color = XP_BLUE
	fill.border_width_left = 1
	fill.border_width_top = 1
	fill.border_width_right = 1
	fill.border_width_bottom = 1
	fill.border_color = XP_BLUE_DARK
	fill.content_margin_left = 2
	fill.content_margin_right = 2
	bar.add_theme_stylebox_override("fill", fill)
	return bar


func _click_sfx() -> void:
	if SoundSystem and SoundSystem.has_method("play_button"):
		SoundSystem.play_button()


# =============================================================================
# PANEL TURNO
# =============================================================================

func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 0.0
	_panel.offset_left = -300.0
	_panel.offset_right = -12.0
	_panel.offset_top = 14.0
	_panel.offset_bottom = 14.0
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.grow_vertical = Control.GROW_DIRECTION_END
	var panel_style := _xp_bevel(XP_BODY, 8)
	panel_style.border_color = XP_BLUE_DARK
	panel_style.shadow_color = Color(0, 0, 0, 0.35)
	panel_style.shadow_size = 6
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	_panel.add_child(root)

	var head := PanelContainer.new()
	var head_style := StyleBoxFlat.new()
	head_style.bg_color = XP_BLUE
	head_style.border_width_left = 1
	head_style.border_width_top = 1
	head_style.border_width_right = 1
	head_style.border_width_bottom = 1
	head_style.border_color = XP_BLUE_DARK
	head_style.content_margin_left = 8
	head_style.content_margin_right = 6
	head_style.content_margin_top = 5
	head_style.content_margin_bottom = 5
	head.add_theme_stylebox_override("panel", head_style)
	root.add_child(head)
	var head_row := HBoxContainer.new()
	head.add_child(head_row)
	var title := _make_label("TURNO", 16, Color.WHITE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_row.add_child(title)
	_toggle = _make_button("—", 13)
	_toggle.custom_minimum_size = Vector2(28, 26)
	head_row.add_child(_toggle)
	_toggle.pressed.connect(_on_toggle)

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 6)
	root.add_child(_body)

	_quota_label = _make_label("Cuota: $0 / $0", 16, XP_TEXT)
	_body.add_child(_quota_label)
	_quota_bar = _make_xp_progress()
	_body.add_child(_quota_bar)

	_streak_label = _make_label("Racha: 0", 15, XP_TEXT)
	_body.add_child(_streak_label)

	_body.add_child(HSeparator.new())
	_body.add_child(_make_label("ENCARGOS DEL DÍA", 13, XP_BLUE_DARK))

	for i in range(3):
		var cl := _make_label("", 14, XP_TEXT)
		cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cl.custom_minimum_size = Vector2(262, 0)
		_body.add_child(cl)
		_contract_labels.append(cl)

	_body.add_child(HSeparator.new())
	_rest_btn = _make_button("Descansar", 15)
	_rest_btn.pressed.connect(func():
		_click_sfx()
		LoopSystem.do_rest()
	)
	_body.add_child(_rest_btn)
	_tracks_btn = _make_button("Borrar rastros", 15)
	_tracks_btn.pressed.connect(func():
		_click_sfx()
		LoopSystem.do_clean_tracks()
	)
	_body.add_child(_tracks_btn)


func _on_toggle() -> void:
	_click_sfx()
	LoopSystem.hud_collapsed = not LoopSystem.hud_collapsed
	_apply_collapsed()


func _apply_collapsed() -> void:
	_body.visible = not LoopSystem.hud_collapsed
	_toggle.text = "+" if LoopSystem.hud_collapsed else "—"


func _refresh() -> void:
	if _quota_label == null:
		return
	var q: float = LoopSystem.quota_target
	var e: float = LoopSystem.earned_today
	_quota_label.text = "Cuota: $%d / $%d" % [int(e), int(q)]
	var qcol: Color = XP_GREEN if e >= q else XP_TEXT
	_quota_label.add_theme_color_override("font_color", qcol)
	_quota_bar.max_value = maxf(1.0, q)
	_quota_bar.value = minf(e, q)

	var mult: float = LoopSystem.get_pay_multiplier()
	_streak_label.text = "Racha: %d   (pago ×%.2f)" % [LoopSystem.streak, mult]
	_streak_label.add_theme_color_override("font_color", XP_YELLOW if LoopSystem.streak >= 3 else XP_TEXT)

	for i in range(_contract_labels.size()):
		var lbl: Label = _contract_labels[i]
		if i >= LoopSystem.contracts.size():
			lbl.text = ""
			continue
		var c: Dictionary = LoopSystem.contracts[i]
		var mark: String = "•"
		var col: Color = XP_TEXT
		var extra: String = ""
		if bool(c["done"]):
			mark = "✓"
			col = XP_GREEN
		elif bool(c["failed"]):
			mark = "✗"
			col = XP_RED
		else:
			extra = "  [%s/%s]" % [_fmt_num(float(c["progress"])), _fmt_num(float(c["target"]))]
		lbl.text = "%s %s%s  +$%d" % [mark, str(c["title"]), extra, LoopSystem.contract_reward(c)]
		lbl.add_theme_color_override("font_color", col)

	var rest_left: int = LoopSystem.REST_MAX_PER_DAY - LoopSystem.rests_used
	_rest_btn.text = "Descansar  (%d/%d)  +%d cordura" % [rest_left, LoopSystem.REST_MAX_PER_DAY, int(LoopSystem.REST_SANITY)]
	_rest_btn.disabled = not LoopSystem.can_rest()
	_rest_btn.tooltip_text = "Pasan %d min y pierdes %d%% de batería." % [LoopSystem.REST_MINUTES, int(LoopSystem.REST_BATTERY_PCT)]

	var tr_left: int = LoopSystem.TRACKS_MAX_PER_DAY - LoopSystem.tracks_used
	_tracks_btn.text = "Borrar rastros  $%d  (%d/%d)" % [int(LoopSystem.tracks_cost()), tr_left, LoopSystem.TRACKS_MAX_PER_DAY]
	_tracks_btn.disabled = not LoopSystem.can_clean_tracks()
	_tracks_btn.tooltip_text = "Baja %d de sospecha." % int(LoopSystem.TRACKS_SUSPICION)


func _fmt_num(v: float) -> String:
	if v >= 1000.0:
		return "%.1fk" % (v / 1000.0)
	return "%d" % int(v)


# =============================================================================
# AVISOS
# =============================================================================

func _build_toast() -> void:
	_toast_panel = PanelContainer.new()
	_toast_panel.anchor_left = 0.5
	_toast_panel.anchor_right = 0.5
	_toast_panel.anchor_top = 0.0
	_toast_panel.anchor_bottom = 0.0
	_toast_panel.offset_top = 22.0
	_toast_panel.offset_bottom = 22.0
	_toast_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_panel.grow_vertical = Control.GROW_DIRECTION_END
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.add_theme_stylebox_override("panel", _xp_bevel(XP_BODY, 10))
	_toast_panel.visible = false
	add_child(_toast_panel)
	_toast_label = _make_label("", 20, XP_TEXT)
	_toast_panel.add_child(_toast_label)


func _show_toast(text: String, color: Color) -> void:
	_toast_queue.append([text, color])
	if not _toast_busy:
		_next_toast()


func _next_toast() -> void:
	if _toast_queue.is_empty():
		_toast_busy = false
		_toast_panel.visible = false
		return
	_toast_busy = true
	var item: Array = _toast_queue.pop_front()
	var col: Color = item[1]
	_toast_label.text = str(item[0])
	_toast_label.add_theme_color_override("font_color", col)
	_toast_panel.modulate.a = 0.0
	_toast_panel.visible = true
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast_panel, "modulate:a", 1.0, 0.2)
	_toast_tween.tween_interval(3.2)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.4)
	_toast_tween.tween_callback(_next_toast)


# =============================================================================
# VENTANA DE EVENTOS
# =============================================================================

func _build_modal() -> void:
	_modal = Control.new()
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal.visible = false
	add_child(_modal)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.08, 0.16, 0.48)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(780, 0)
	var modal_style := _xp_bevel(XP_BODY, 14)
	modal_style.border_color = XP_BLUE_DARK
	modal_style.shadow_color = Color(0, 0, 0, 0.45)
	modal_style.shadow_size = 12
	panel.add_theme_stylebox_override("panel", modal_style)
	center.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	var event_header := PanelContainer.new()
	var event_header_style := StyleBoxFlat.new()
	event_header_style.bg_color = XP_BLUE
	event_header_style.border_width_left = 1
	event_header_style.border_width_top = 1
	event_header_style.border_width_right = 1
	event_header_style.border_width_bottom = 1
	event_header_style.border_color = XP_BLUE_DARK
	event_header_style.content_margin_left = 10
	event_header_style.content_margin_right = 10
	event_header_style.content_margin_top = 6
	event_header_style.content_margin_bottom = 6
	v.add_child(event_header)
	_modal_title = _make_label("", 20, Color.WHITE)
	event_header.add_child(_modal_title)

	_modal_text = _make_label("", 18, XP_TEXT)
	_modal_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_modal_text.custom_minimum_size = Vector2(730, 0)
	v.add_child(_modal_text)

	_modal_result = _make_label("", 17, XP_YELLOW)
	_modal_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_modal_result.custom_minimum_size = Vector2(730, 0)
	_modal_result.visible = false
	v.add_child(_modal_result)

	_modal_choices = VBoxContainer.new()
	_modal_choices.add_theme_constant_override("separation", 10)
	v.add_child(_modal_choices)


func _show_event(e: Dictionary) -> void:
	_modal_title.text = str(e.get("title", "Evento"))
	_modal_text.text = str(e.get("text", ""))
	_modal_result.visible = false
	_modal_result.text = ""
	for child in _modal_choices.get_children():
		child.queue_free()
	var choices: Array = e.get("choices", [])
	for i in range(choices.size()):
		var ch: Dictionary = choices[i]
		var b := _make_button(str(ch.get("text", "...")), 20)
		b.custom_minimum_size = Vector2(0, 46)
		b.pressed.connect(_on_choice.bind(i))
		_modal_choices.add_child(b)
	_modal.visible = true


func _on_choice(idx: int) -> void:
	_click_sfx()
	var result: String = EventSystem.choose(idx)
	for child in _modal_choices.get_children():
		child.queue_free()
	_modal_result.text = result
	_modal_result.visible = true
	var cont := _make_button("Continuar", 20)
	cont.custom_minimum_size = Vector2(0, 46)
	cont.pressed.connect(func():
		_click_sfx()
		EventSystem.close()
	)
	_modal_choices.add_child(cont)


func _hide_modal() -> void:
	_modal.visible = false
	_refresh()
