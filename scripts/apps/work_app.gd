extends Control
## WorkApp — UI de Trabajo con minijuegos ricos (Tanda 8++)
##
## Minijuegos:
##   click     — ritmo + combo + feedback visual
##   timing    — barra móvil: zona verde (ok) / zona dorada (perfecto)
##   sequence  — Simon de 4 colores (botón o teclado 1-4)
##   hold      — mantén y suelta en zona segura (barra visual)
##   rapid     — spam con combo; ventana se estrecha
##   classify  — clasifica izquierda/derecha (temática narrativa)
##   type      — escribe secuencia (botones o teclado)
##   decrypt   — descifra un código: elige el dígito correcto en secuencia

@onready var header: Label = $Root/Header
@onready var level_progress: Label = $Root/LevelProgress
@onready var work_status: Label = $Root/WorkStatus
@onready var job_list: ItemList = $Root/MainRow/JobList
@onready var job_details: Label = $Root/MainRow/JobDetails
@onready var timer_bar: ProgressBar = $Root/TimerBar
@onready var timer_label: Label = $Root/TimerRow/TimerLabel
@onready var click_area: Button = $Root/TimerRow/ClickArea
@onready var start_job_button: Button = $Root/BottomRow/StartJobButton
@onready var reward_label: Label = $Root/BottomRow/RewardLabel

var _selected_idx: int = 0
var _is_working: bool = false
var _clicks_done: int = 0
var _clicks_needed: int = 0
var _current_job: Dictionary = {}
var _payment_option: OptionButton = null
var _minigame_type: String = "click"

# --- Estado compartido de minijuego ---
var _score: float = 0.0
var _combo: int = 0
var _max_combo: int = 0
var _hits: int = 0
var _misses: int = 0
var _perfects: int = 0
var _mg_overlay: Control = null
var _mg_status: Label = null
var _mg_progress: ProgressBar = null
var _mg_hint: Label = null
var _mg_flash: ColorRect = null
var _mg_buttons: Array = []
var _process_mg: bool = false

# Timing
var _marker_pos: float = 0.0
var _marker_dir: float = 1.0
var _marker_speed: float = 1.4
var _zone_center: float = 0.5
var _zone_width: float = 0.14
var _perfect_width: float = 0.04
var _timing_canvas: Control = null

# Sequence (Simon)
var _seq_pattern: Array = []
var _seq_player_idx: int = 0
var _seq_showing: bool = false
var _seq_colors: Array = [
	Color(0.90, 0.22, 0.22),
	Color(0.20, 0.78, 0.32),
	Color(0.22, 0.42, 0.95),
	Color(0.95, 0.78, 0.15)
]
var _seq_labels: Array = ["1", "2", "3", "4"]

# Hold
var _hold_active: bool = false
var _hold_value: float = 0.0
var _hold_safe_min: float = 0.55
var _hold_safe_max: float = 0.85
var _hold_canvas: Control = null

# Rapid
var _rapid_window: float = 0.0
var _last_click_ms: int = 0

# Classify
var _classify_left_label: String = "A"
var _classify_right_label: String = "B"
var _classify_prompt: String = ""
var _classify_answer: int = 0

# Type
var _type_target: String = ""
var _type_progress: int = 0
var _type_keys: Array = ["W", "A", "S", "D", "E", "R", "F", "G"]

# Decrypt
var _decrypt_code: Array = []
var _decrypt_idx: int = 0
var _decrypt_options: Array = []

var MINIGAME_DESC := {
	"click": (LocaleSystem.t("work.desc_click", "Ritmo + combo. Clica con buen tempo para multiplicar.") if LocaleSystem else "Ritmo + combo. Clica con buen tempo para multiplicar."),
	"timing": (LocaleSystem.t("work.mg_timing", "Barra móvil: zona verde = ok, zona dorada = PERFECTO.") if LocaleSystem else "Barra móvil: zona verde = ok, zona dorada = PERFECTO."),
	"sequence": (LocaleSystem.t("work.desc_sequence", "Memoriza y repite la secuencia (botones o teclas 1-4).") if LocaleSystem else "Memoriza y repite la secuencia (botones o teclas 1-4)."),
	"hold": (LocaleSystem.t("work.mg_hold", "Mantén pulsado y suelta dentro de la zona segura.") if LocaleSystem else "Mantén pulsado y suelta dentro de la zona segura."),
	"rapid": (LocaleSystem.t("work.mg_spam", "Clics rápidos. Mantén el ritmo o pierdes el combo.") if LocaleSystem else "Clics rápidos. Mantén el ritmo o pierdes el combo."),
	"classify": (LocaleSystem.t("work.mg_classify", "Clasifica cada ítem a izquierda o derecha.") if LocaleSystem else "Clasifica cada ítem a izquierda o derecha."),
	"type": "Pulsa las teclas en el orden indicado (teclado o botones).",
	"decrypt": (LocaleSystem.t("work.mg_code", "Descifra el código eligiendo el dígito correcto.") if LocaleSystem else "Descifra el código eligiendo el dígito correcto.")
}

func _ready() -> void:
	_style()
	_ensure_payment_ui()
	if job_list and not job_list.item_selected.is_connected(_on_job_selected):
		job_list.item_selected.connect(_on_job_selected)
	if start_job_button and not start_job_button.pressed.is_connected(_on_start_job):
		start_job_button.pressed.connect(_on_start_job)
	if click_area and not click_area.pressed.is_connected(_on_work_click):
		click_area.pressed.connect(_on_work_click)
	if click_area:
		click_area.visible = false
		# Hold needs button_down / button_up
		if not click_area.button_down.is_connected(_on_hold_down):
			click_area.button_down.connect(_on_hold_down)
		if not click_area.button_up.is_connected(_on_hold_up):
			click_area.button_up.connect(_on_hold_up)
	GameManager.job_level_changed.connect(func(_l): refresh())
	GameManager.jobs_completed_changed.connect(func(_c): refresh())
	TimeManager.work_hours_changed.connect(func(_w): refresh())
	if GameManager.has_signal("payment_method_changed"):
		GameManager.payment_method_changed.connect(func(_m): _sync_payment_ui())
	set_process(true)
	refresh()

func _process(delta: float) -> void:
	if not _is_working or not _process_mg:
		return
	match _minigame_type:
		"timing":
			_process_timing(delta)
		"hold":
			_process_hold(delta)
		"rapid":
			_process_rapid(delta)

func _ensure_payment_ui() -> void:
	if _payment_option != null and is_instance_valid(_payment_option):
		return
	var row := HBoxContainer.new()
	row.name = "PaymentRow"
	var lbl := Label.new()
	lbl.text = "Cobro: "
	lbl.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15))
	lbl.add_theme_font_size_override("font_size", 30)
	row.add_child(lbl)
	_payment_option = OptionButton.new()
	_payment_option.add_item((LocaleSystem.t("work.online_method", "Online (rápido, +sospecha)") if LocaleSystem else "Online (rápido, +sospecha)"), 0)
	_payment_option.add_item((LocaleSystem.t("work.cash_method", "Efectivo (sin sospecha, riesgo retraso/fallo)") if LocaleSystem else "Efectivo (sin sospecha, riesgo retraso/fallo)"), 1)
	_payment_option.custom_minimum_size = Vector2(280, 28)
	_payment_option.item_selected.connect(_on_payment_selected)
	row.add_child(_payment_option)
	var root_node = $Root
	if root_node:
		root_node.add_child(row)
		var bottom = root_node.get_node_or_null("BottomRow")
		if bottom:
			root_node.move_child(row, bottom.get_index())
	_sync_payment_ui()

func _sync_payment_ui() -> void:
	if _payment_option == null:
		return
	var idx: int = 0 if GameManager.payment_method == "online" else 1
	_payment_option.select(idx)

func _on_payment_selected(idx: int) -> void:
	if SoundSystem:
		SoundSystem.play_click(true)
	var method: String = "online" if idx == 0 else "cash"
	if GameManager.has_method("set_payment_method"):
		GameManager.set_payment_method(method)
	else:
		GameManager.payment_method = method

func _style() -> void:
	for lbl in [header, level_progress, work_status, job_details, timer_label, reward_label]:
		if lbl:
			lbl.add_theme_color_override("font_color", Color(0.12, 0.12, 0.12))
			lbl.add_theme_font_size_override("font_size", 32)
	if header:
		header.add_theme_color_override("font_color", Color(0.0, 0.0, 0.5))
		header.add_theme_font_size_override("font_size", 30)
	if job_details:
		job_details.add_theme_font_size_override("font_size", 30)
		job_details.clip_text = false
		job_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if click_area:
		var cstyle := StyleBoxFlat.new()
		cstyle.bg_color = Color(0.902, 0.494, 0.133)
		cstyle.set_corner_radius_all(5)
		click_area.add_theme_stylebox_override("normal", cstyle)
		click_area.add_theme_color_override("font_color", Color.WHITE)
	if start_job_button:
		var bstyle := StyleBoxFlat.new()
		bstyle.bg_color = Color(0.141, 0.369, 0.863)
		bstyle.set_corner_radius_all(5)
		start_job_button.add_theme_stylebox_override("normal", bstyle)
		start_job_button.add_theme_color_override("font_color", Color.WHITE)
	if timer_bar:
		var tfill := StyleBoxFlat.new()
		tfill.bg_color = Color(0.141, 0.369, 0.863)
		tfill.set_corner_radius_all(3)
		timer_bar.add_theme_stylebox_override("fill", tfill)

func refresh() -> void:
	if _is_working:
		return
	if header:
		header.text = (LocaleSystem.t("work.header_level", "Centro de Trabajo  |  Nivel %d") if LocaleSystem else "Centro de Trabajo  |  Nivel %d") % GameManager.job_level
	if level_progress:
		var next_req: int = WorkSystem.get_next_level_requirement()
		if next_req < 0:
			level_progress.text = (LocaleSystem.t("work.max_level", "Nivel máximo  •  Trabajos: %d") if LocaleSystem else "Nivel máximo  •  Trabajos: %d") % GameManager.jobs_completed
		else:
			level_progress.text = (LocaleSystem.t("work.progress", "Progreso: %d / %d para Nivel %d") if LocaleSystem else "Progreso: %d / %d para Nivel %d") % [
				GameManager.jobs_completed, next_req, GameManager.job_level + 1
			]
	if work_status:
		if TimeManager.is_work_time:
			work_status.text = LocaleSystem.t("work.on_hours", "HORARIO LABORAL (01:00–05:00) — Trabaja ahora") if LocaleSystem else "HORARIO LABORAL (01:00–05:00) — Trabaja ahora"
			work_status.add_theme_color_override("font_color", Color(0.0, 0.45, 0.05))
		else:
			work_status.text = LocaleSystem.t("work.off_hours", "Fuera de horario — apaga el PC para avanzar al día siguiente") if LocaleSystem else "Fuera de horario — apaga el PC para avanzar al día siguiente"
			work_status.add_theme_color_override("font_color", Color(0.7, 0.15, 0.05))
	if job_list:
		job_list.add_theme_font_size_override("font_size", 27)
		job_list.clear()
		var available: Array = WorkSystem.get_available_jobs()
		for job in available:
			var suffix: String = ""
			if float(job.get("sanity_cost", 0)) > 0:
				suffix = " ⚠"
			var mg: String = str(job.get("minigame", "click"))
			var mg_icon: String = {
				"click": "●", "timing": "⏱", "sequence": "◈",
				"hold": "▮", "rapid": "⚡", "classify": "⇄", "type": "⌨",
				"decrypt": "🔓"
			}.get(mg, "●")
			job_list.add_item("%s Lv%d  %s  ($%d-$%d)%s" % [
				mg_icon, int(job["level"]), (WorkSystem.localized_job_name(job) if WorkSystem and WorkSystem.has_method("localized_job_name") else str(job["name"])),
				int(job["min_pay"]), int(job["max_pay"]), suffix
			])
		if available.size() > 0:
			_selected_idx = clampi(_selected_idx, 0, available.size() - 1)
			job_list.select(_selected_idx)
			_on_job_selected(_selected_idx)
	if start_job_button:
		start_job_button.disabled = _is_working or not TimeManager.is_work_time
	_sync_payment_ui()

func _on_job_selected(idx: int) -> void:
	if SoundSystem:
		SoundSystem.play_click(true)
	_selected_idx = idx
	var available: Array = WorkSystem.get_available_jobs()
	if idx < 0 or idx >= available.size():
		if job_details:
			job_details.text = LocaleSystem.t("work.select", "Selecciona un trabajo") if LocaleSystem else "Selecciona un trabajo"
		return
	var job: Dictionary = available[idx]
	if job_details:
		var extra: String = ""
		var sc: float = float(job.get("sanity_cost", 0))
		if sc > 0:
			extra = (LocaleSystem.t("work.sanity_cost", "\\n⚠ Coste de cordura: ~%.1f") if LocaleSystem else "\\n⚠ Coste de cordura: ~%.1f") % sc
		if bool(job.get("can_generate_clue", false)):
			extra += "\n🔍 Puede generar pista"
		var mg: String = str(job.get("minigame", "click"))
		extra += "\n🎮 %s" % MINIGAME_DESC.get(mg, "Clics")
		job_details.text = (LocaleSystem.t("work.job_details", "%s\\n\\n%s\\n\\nPago: $%d - $%d\\nDuración: ~%ds\\nObjetivo: %d aciertos%s") if LocaleSystem else "%s\\n\\n%s\\n\\nPago: $%d - $%d\\nDuración: ~%ds\\nObjetivo: %d aciertos%s") % [
			(WorkSystem.localized_job_name(job) if WorkSystem and WorkSystem.has_method("localized_job_name") else str(job["name"])), (WorkSystem.localized_job_desc(job) if WorkSystem and WorkSystem.has_method("localized_job_desc") else str(job.get("description", ""))),
			int(job["min_pay"]), int(job["max_pay"]),
			int(job.get("duration", 10)), int(job.get("clicks_required", 5)),
			extra
		]

# =============================================================================
# INICIO / FIN DE TRABAJO
# =============================================================================

func _on_start_job() -> void:
	if SoundSystem:
		SoundSystem.play_button()
	if _is_working or not TimeManager.is_work_time:
		return
	var available: Array = WorkSystem.get_available_jobs()
	if _selected_idx < 0 or _selected_idx >= available.size():
		return
	_current_job = available[_selected_idx]
	if _current_job.has("requires_internet"):
		var need: int = int(_current_job["requires_internet"])
		if UpgradeSystem.get_level("internet") < need:
			if reward_label:
				reward_label.text = "Necesitas Internet nivel %d" % need
			return

	_is_working = true
	_clicks_done = 0
	_clicks_needed = int(_current_job.get("clicks_required", 5))
	_minigame_type = str(_current_job.get("minigame", "click"))
	_score = 0.0
	_combo = 0
	_max_combo = 0
	_hits = 0
	_misses = 0
	_perfects = 0
	_process_mg = true

	if start_job_button:
		start_job_button.disabled = true
		start_job_button.text = (LocaleSystem.t("work.working", "Trabajando...") if LocaleSystem else "Trabajando...")
	if reward_label:
		reward_label.text = ""
	if job_list:
		job_list.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_build_minigame_ui()
	_start_minigame_logic()

	var duration: float = float(_current_job.get("duration", 10))
	if UpgradeSystem and UpgradeSystem.has_method("get_cooldown_mult"):
		duration *= UpgradeSystem.get_cooldown_mult()
	var elapsed: float = 0.0
	if timer_bar:
		timer_bar.value = 0
		timer_bar.max_value = duration

	while elapsed < duration and _is_working and GameManager.is_pc_on:
		await get_tree().create_timer(0.05).timeout
		elapsed += 0.05
		if timer_bar:
			timer_bar.value = elapsed
		if timer_label:
			timer_label.text = "Tiempo: %.1fs" % maxf(0.0, duration - elapsed)
		GameManager.spend_battery(0.008)
		# Completar antes de tiempo si ya alcanzaste el objetivo con buena precisión
		if _clicks_done >= _clicks_needed and _hits > 0:
			await get_tree().create_timer(0.35).timeout
			break

	_finish_job()

func _finish_job() -> void:
	_process_mg = false
	_hold_active = false
	if _current_job.is_empty():
		_is_working = false
		_destroy_minigame_ui()
		return

	# Precisión + perfects + combo
	var total_attempts: int = maxi(1, _hits + _misses)
	var accuracy: float = float(_hits) / float(total_attempts)
	var progress: float = clampf(float(_clicks_done) / float(maxi(1, _clicks_needed)), 0.0, 1.0)
	var combo_bonus: float = clampf(float(_max_combo) * 0.025, 0.0, 0.18)
	var perfect_bonus: float = clampf(float(_perfects) * 0.03, 0.0, 0.12)
	var quality: float = clampf(progress * 0.50 + accuracy * 0.28 + combo_bonus + perfect_bonus + 0.20, 0.55, 1.20)

	var base_pay: float = randf_range(float(_current_job["min_pay"]), float(_current_job["max_pay"]))
	var final_pay: float = base_pay * quality
	GameManager.complete_job(final_pay, _current_job)

	if reward_label:
		var cpu_mult: float = 1.0
		if UpgradeSystem and UpgradeSystem.has_method("get_pay_multiplier"):
			cpu_mult = UpgradeSystem.get_pay_multiplier()
		elif UpgradeSystem and UpgradeSystem.has_method("get_cpu_multiplier"):
			cpu_mult = UpgradeSystem.get_cpu_multiplier()
		var method_txt: String = "Online" if GameManager.payment_method == "online" else (LocaleSystem.t("work.cash", "Efectivo") if LocaleSystem else "Efectivo")
		var grade: String = "S" if quality >= 1.08 else ("A" if quality >= 0.92 else ("B" if quality >= 0.72 else ("C" if quality >= 0.52 else "D")))
		var grade_col := Color(0.05, 0.55, 0.15)
		if grade == "S":
			grade_col = Color(1.0, 0.85, 0.15)
		elif grade == "A":
			grade_col = Color(0.2, 0.85, 0.35)
		elif grade == "D":
			grade_col = Color(0.85, 0.25, 0.2)
		reward_label.text = "+$%.0f  [%s]  prec.%.0f%%  PERF×%d  combo×%d  CPU×%.2f  [%s]" % [
			final_pay * cpu_mult, grade, accuracy * 100.0, _perfects, _max_combo, cpu_mult, method_txt
		]
		reward_label.add_theme_color_override("font_color", grade_col)
		reward_label.pivot_offset = reward_label.size * 0.5
		var tw := create_tween()
		tw.tween_property(reward_label, "scale", Vector2(1.15, 1.15), 0.1)
		tw.tween_property(reward_label, "scale", Vector2.ONE, 0.18)

	_is_working = false
	_current_job = {}
	_destroy_minigame_ui()
	if start_job_button:
		start_job_button.text = (LocaleSystem.t("work.start_job", ">  Empezar trabajo") if LocaleSystem else ">  Empezar trabajo")
		start_job_button.disabled = not TimeManager.is_work_time
	if click_area:
		click_area.visible = false
		click_area.disabled = false
	if timer_label:
		timer_label.text = ""
	if job_list:
		job_list.mouse_filter = Control.MOUSE_FILTER_STOP
	refresh()

# =============================================================================
# UI DINÁMICA DEL MINIJUEGO
# =============================================================================

func _build_minigame_ui() -> void:
	_destroy_minigame_ui()
	var root_node = $Root
	if root_node == null:
		return

	_mg_overlay = PanelContainer.new()
	_mg_overlay.name = "MinigameOverlay"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.13, 0.94)
	style.set_corner_radius_all(10)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.35, 0.60, 0.90, 0.75)
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 6
	_mg_overlay.add_theme_stylebox_override("panel", style)
	_mg_overlay.custom_minimum_size = Vector2(0, 120)
	_mg_overlay.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	root_node.clip_contents = true
	root_node.add_child(_mg_overlay)
	var timer_row = root_node.get_node_or_null("TimerRow")
	if timer_row:
		root_node.move_child(_mg_overlay, timer_row.get_index())
	# Ocultar lista/detalles mientras se juega para no desbordar la ventana
	var main_row = root_node.get_node_or_null("MainRow")
	if main_row:
		main_row.visible = false
	var hdr = root_node.get_node_or_null("Header")
	if hdr:
		hdr.visible = false
	var lvl = root_node.get_node_or_null("LevelProgress")
	if lvl:
		lvl.visible = false
	var wst = root_node.get_node_or_null("WorkStatus")
	if wst:
		wst.visible = false

	# Flash overlay for hit/miss feedback
	_mg_flash = ColorRect.new()
	_mg_flash.color = Color(1, 1, 1, 0)
	_mg_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mg_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mg_overlay.add_child(_mg_flash)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_mg_overlay.add_child(vbox)

	_mg_status = Label.new()
	_mg_status.add_theme_font_size_override("font_size", 30)
	_mg_status.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
	_mg_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_mg_status)

	_mg_progress = ProgressBar.new()
	_mg_progress.custom_minimum_size = Vector2(0, 12)
	_mg_progress.max_value = float(_clicks_needed)
	_mg_progress.value = 0
	var pfill := StyleBoxFlat.new()
	pfill.bg_color = Color(0.18, 0.72, 0.42)
	pfill.set_corner_radius_all(4)
	_mg_progress.add_theme_stylebox_override("fill", pfill)
	var pbg := StyleBoxFlat.new()
	pbg.bg_color = Color(0.12, 0.14, 0.18)
	pbg.set_corner_radius_all(4)
	_mg_progress.add_theme_stylebox_override("background", pbg)
	vbox.add_child(_mg_progress)

	_mg_hint = Label.new()
	_mg_hint.add_theme_font_size_override("font_size", 27)
	_mg_hint.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95))
	_mg_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mg_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_mg_hint)

	match _minigame_type:
		"timing":
			_build_timing_area(vbox)
		"sequence":
			_build_sequence_area(vbox)
		"classify":
			_build_classify_area(vbox)
		"type":
			_build_type_area(vbox)
		"decrypt":
			_build_decrypt_area(vbox)
		"hold":
			_build_hold_area(vbox)
			if click_area:
				click_area.visible = true
				click_area.disabled = false
				click_area.text = _default_click_text()
		_:
			if click_area:
				click_area.visible = true
				click_area.disabled = false
				click_area.text = _default_click_text()

	_update_mg_status()

func _destroy_minigame_ui() -> void:
	_mg_buttons.clear()
	_timing_canvas = null
	_hold_canvas = null
	_mg_flash = null
	if _mg_overlay and is_instance_valid(_mg_overlay):
		_mg_overlay.queue_free()
	_mg_overlay = null
	_mg_status = null
	_mg_progress = null
	_mg_hint = null
	var root_node = get_node_or_null("Root")
	if root_node:
		root_node.clip_contents = false
		for n in ["MainRow", "Header", "LevelProgress", "WorkStatus"]:
			var c = root_node.get_node_or_null(n)
			if c:
				c.visible = true

func _update_mg_status() -> void:
	if _mg_status:
		var perf := ""
		if _perfects > 0:
			perf = "   ·   ★%d" % _perfects
		_mg_status.text = "✓ %d/%d   ·   COMBO ×%d   ·   ✕ %d%s" % [
			_clicks_done, _clicks_needed, _combo, _misses, perf
		]
	if _mg_progress and _minigame_type != "hold":
		_mg_progress.max_value = float(_clicks_needed)
		_mg_progress.value = float(_clicks_done)

func _default_click_text() -> String:
	match _minigame_type:
		"hold":
			return (LocaleSystem.t("work.hold_release", "MANTÉN Y SUELTA") if LocaleSystem else "MANTÉN Y SUELTA")
		"rapid":
			return (LocaleSystem.t("work.spam_click", "¡SPAM CLICK!") if LocaleSystem else "¡SPAM CLICK!")
		_:
			return "CLICK  %d/%d" % [_clicks_done, _clicks_needed]

func _flash_feedback(good: bool, perfect: bool = false) -> void:
	if _mg_flash == null or not is_instance_valid(_mg_flash):
		return
	var col: Color
	if perfect:
		col = Color(1.0, 0.9, 0.2, 0.35)
	elif good:
		col = Color(0.2, 1.0, 0.4, 0.22)
	else:
		col = Color(1.0, 0.2, 0.2, 0.28)
	_mg_flash.color = col
	var tw := create_tween()
	tw.tween_property(_mg_flash, "color:a", 0.0, 0.22)

func _register_hit(amount: int = 1, perfect: bool = false) -> void:
	_hits += 1
	_combo += 1
	if perfect:
		_perfects += 1
		_combo += 1  # perfect da combo extra
	_max_combo = maxi(_max_combo, _combo)
	_clicks_done = mini(_clicks_needed, _clicks_done + amount)
	_update_mg_status()
	_flash_feedback(true, perfect)
	if SoundSystem:
		SoundSystem.play_click()
	if click_area and click_area.visible:
		click_area.pivot_offset = click_area.size * 0.5
		var tw := create_tween()
		tw.tween_property(click_area, "scale", Vector2(0.90, 0.90), 0.04)
		tw.tween_property(click_area, "scale", Vector2.ONE, 0.09)
	if is_instance_valid(VFXSystem) and _mg_overlay and is_instance_valid(_mg_overlay):
		var center := _mg_overlay.global_position + _mg_overlay.size * 0.5
		VFXSystem.spawn_sparkles(center, 6 if perfect else 3)
	if _clicks_done >= _clicks_needed:
		if click_area:
			click_area.text = (LocaleSystem.t("work.completed", "¡COMPLETADO!") if LocaleSystem else "¡COMPLETADO!")
			click_area.disabled = true
		if _mg_hint:
			_mg_hint.text = (LocaleSystem.t("work.objective_done", "¡Objetivo cumplido! Terminando…") if LocaleSystem else "¡Objetivo cumplido! Terminando…")
		if is_instance_valid(VFXSystem) and _mg_overlay and is_instance_valid(_mg_overlay):
			VFXSystem.spawn_sparkles(_mg_overlay.global_position + _mg_overlay.size * 0.5, 14)

func _register_miss() -> void:
	_misses += 1
	_combo = 0
	_update_mg_status()
	_flash_feedback(false)
	if _mg_hint:
		var tw := create_tween()
		tw.tween_property(_mg_hint, "modulate", Color(1, 0.35, 0.35), 0.08)
		tw.tween_property(_mg_hint, "modulate", Color.WHITE, 0.25)

# =============================================================================
# LÓGICA POR MINIJUEGO
# =============================================================================

func _start_minigame_logic() -> void:
	match _minigame_type:
		"timing":
			_marker_pos = 0.0
			_marker_dir = 1.0
			_marker_speed = 0.70 + float(GameManager.job_level) * 0.08
			_zone_center = randf_range(0.35, 0.65)
			_zone_width = maxf(0.20, 0.30 - float(GameManager.job_level) * 0.015)
			_perfect_width = maxf(0.06, 0.10 - float(GameManager.job_level) * 0.005)
			if _mg_hint:
				_mg_hint.text = (LocaleSystem.t("work.zone_perfect_hint", "Zona VERDE = ok · Zona DORADA = PERFECTO (+combo)") if LocaleSystem else "Zona VERDE = ok · Zona DORADA = PERFECTO (+combo)")
		"sequence":
			_seq_pattern.clear()
			_seq_player_idx = 0
			_seq_showing = false
			_add_sequence_step()
			if _mg_hint:
				_mg_hint.text = "Observa… luego repite (teclas 1-4 o botones)"
			call_deferred("_show_sequence")
		"hold":
			_hold_active = false
			_hold_value = 0.0
			_hold_safe_min = 0.38 + randf() * 0.08
			_hold_safe_max = minf(0.95, _hold_safe_min + 0.35 - float(GameManager.job_level) * 0.015)
			if click_area:
				click_area.text = LocaleSystem.t("work.hold_action", "MANTÉN… y suelta en la zona") if LocaleSystem else "MANTÉN… y suelta en la zona"
			if _mg_hint:
				_mg_hint.text = LocaleSystem.t("work.hold_hint", "Mantén. Suelta en la zona AMARILLA. Centro = perfecto.") if LocaleSystem else "Mantén. Suelta en la zona AMARILLA. Centro = perfecto."
		"rapid":
			_last_click_ms = 0
			_rapid_window = 1.05 - float(GameManager.job_level) * 0.04
			if click_area:
				click_area.text = (LocaleSystem.t("work.spam_click_n", "¡SPAM CLICK!  0/%d") if LocaleSystem else "¡SPAM CLICK!  0/%d") % _clicks_needed
			if _mg_hint:
				_mg_hint.text = LocaleSystem.t("work.spam_hint", "Clica rápido. Si paras, pierdes el combo.") if LocaleSystem else "Clica rápido. Si paras, pierdes el combo."
		"classify":
			_next_classify_item()
		"type":
			_generate_type_target()
			if _mg_hint:
				_mg_hint.text = "Teclea o pulsa botones:  %s" % _type_target
		"decrypt":
			_generate_decrypt()
			if _mg_hint:
				_mg_hint.text = LocaleSystem.t("work.digit_hint", "Elige el dígito correcto del código") if LocaleSystem else "Elige el dígito correcto del código"
		_:
			if click_area:
				click_area.text = "CLICK  0/%d" % _clicks_needed
			if _mg_hint:
				_mg_hint.text = (LocaleSystem.t("work.rhythm_hint", "Clica con ritmo. Los combos aumentan la paga.") if LocaleSystem else "Clica con ritmo. Los combos aumentan la paga.")

# --- CLICK (ritmo) ---
func _on_work_click() -> void:
	if not _is_working:
		return
	if _minigame_type in ["sequence", "classify", "type"]:
		return  # usan sus propios botones
	if _minigame_type == "hold":
		return  # se gestiona con button_down/up
	if _minigame_type == "timing":
		_try_timing_hit()
		return
	if _minigame_type == "rapid":
		_try_rapid_hit()
		return
	# click normal con combo por ritmo
	var now := Time.get_ticks_msec()
	if _last_click_ms > 0:
		var gap: int = now - _last_click_ms
		if gap < 120:
			# demasiado rápido / spam sin ritmo → no cuenta extra
			pass
		elif gap > 900:
			_combo = 0
	_last_click_ms = now
	_register_hit()
	if click_area and _clicks_done < _clicks_needed:
		click_area.text = "CLICK  %d/%d  (x%d)" % [_clicks_done, _clicks_needed, _combo]

# --- TIMING (barra móvil) ---
func _build_timing_area(parent: VBoxContainer) -> void:
	_timing_canvas = Control.new()
	_timing_canvas.custom_minimum_size = Vector2(0, 32)
	_timing_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(_timing_canvas)
	_timing_canvas.draw.connect(_draw_timing_bar)

	var hit_btn := Button.new()
	hit_btn.text = "▶  GOLPEAR"
	hit_btn.custom_minimum_size = Vector2(0, 40)
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.2, 0.55, 0.3)
	bs.set_corner_radius_all(6)
	hit_btn.add_theme_stylebox_override("normal", bs)
	hit_btn.add_theme_color_override("font_color", Color.WHITE)
	hit_btn.add_theme_font_size_override("font_size", 32)
	hit_btn.pressed.connect(_try_timing_hit)
	parent.add_child(hit_btn)
	_mg_buttons.append(hit_btn)

func _draw_timing_bar() -> void:
	if _timing_canvas == null:
		return
	var r := Rect2(Vector2.ZERO, _timing_canvas.size)
	if r.size.x < 4:
		return
	# fondo con borde
	_timing_canvas.draw_rect(r, Color(0.12, 0.14, 0.18))
	_timing_canvas.draw_rect(r, Color(0.3, 0.4, 0.5, 0.5), false, 2.0)
	# zona verde (ok)
	var zx := r.size.x * (_zone_center - _zone_width * 0.5)
	var zw := r.size.x * _zone_width
	_timing_canvas.draw_rect(Rect2(zx, 4, zw, r.size.y - 8), Color(0.18, 0.72, 0.32, 0.80))
	# zona dorada (perfecto)
	var px := r.size.x * (_zone_center - _perfect_width * 0.5)
	var pw := r.size.x * _perfect_width
	_timing_canvas.draw_rect(Rect2(px, 2, pw, r.size.y - 4), Color(1.0, 0.85, 0.15, 0.95))
	# marcador
	var mx := r.size.x * _marker_pos
	_timing_canvas.draw_rect(Rect2(mx - 4, 0, 8, r.size.y), Color(1.0, 0.95, 0.3))
	_timing_canvas.draw_rect(Rect2(mx - 1.5, 0, 3, r.size.y), Color(1, 1, 1))

func _process_timing(delta: float) -> void:
	_marker_pos += _marker_dir * _marker_speed * delta
	if _marker_pos >= 1.0:
		_marker_pos = 1.0
		_marker_dir = -1.0
	elif _marker_pos <= 0.0:
		_marker_pos = 0.0
		_marker_dir = 1.0
	if _timing_canvas:
		_timing_canvas.queue_redraw()

func _try_timing_hit() -> void:
	if not _is_working or _clicks_done >= _clicks_needed:
		return
	var dist: float = absf(_marker_pos - _zone_center)
	if dist <= _perfect_width * 0.5:
		_register_hit(1, true)
		_zone_center = randf_range(0.22, 0.78)
		_marker_speed = minf(2.2, _marker_speed + 0.04)
		if _mg_hint:
			_mg_hint.text = (LocaleSystem.t("work.perfect_zone", "★★ PERFECTO ★★  Zona nueva") if LocaleSystem else "★★ PERFECTO ★★  Zona nueva")
	elif dist <= _zone_width * 0.5:
		_register_hit(1, false)
		_zone_center = randf_range(0.22, 0.78)
		_marker_speed = minf(2.0, _marker_speed + 0.03)
		if _mg_hint:
			_mg_hint.text = (LocaleSystem.t("work.try_gold", "Bien. Intenta la zona dorada…") if LocaleSystem else "Bien. Intenta la zona dorada…")
	else:
		_register_miss()
		if _mg_hint:
			_mg_hint.text = (LocaleSystem.t("work.outside", "Fuera… espera el marcador") if LocaleSystem else "Fuera… espera el marcador")

# --- SEQUENCE (Simon) ---
func _build_sequence_area(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	for i in range(4):
		var b := Button.new()
		b.text = _seq_labels[i]
		b.custom_minimum_size = Vector2(48, 40)
		b.add_theme_font_size_override("font_size", 30)
		var st := StyleBoxFlat.new()
		st.bg_color = _seq_colors[i].darkened(0.25)
		st.set_corner_radius_all(8)
		b.add_theme_stylebox_override("normal", st)
		var st_h := st.duplicate()
		st_h.bg_color = _seq_colors[i]
		b.add_theme_stylebox_override("hover", st_h)
		b.add_theme_stylebox_override("pressed", st_h)
		b.add_theme_color_override("font_color", Color.WHITE)
		var idx := i
		b.pressed.connect(func(): _on_sequence_press(idx))
		row.add_child(b)
		_mg_buttons.append(b)

func _add_sequence_step() -> void:
	_seq_pattern.append(randi() % 4)

func _show_sequence() -> void:
	if not _is_working:
		return
	_seq_showing = true
	_seq_player_idx = 0
	if _mg_hint:
		_mg_hint.text = "Observa…"
	for btn in _mg_buttons:
		if is_instance_valid(btn):
			btn.disabled = true
	await get_tree().create_timer(0.4).timeout
	for step in _seq_pattern:
		if not _is_working:
			return
		_flash_seq_button(int(step))
		await get_tree().create_timer(0.75).timeout
	for btn in _mg_buttons:
		if is_instance_valid(btn):
			btn.disabled = false
	_seq_showing = false
	if _mg_hint:
		_mg_hint.text = (LocaleSystem.t("work.your_turn", "Tu turno — repite la secuencia (%d pasos)") if LocaleSystem else "Tu turno — repite la secuencia (%d pasos)") % _seq_pattern.size()

func _flash_seq_button(idx: int) -> void:
	if idx < 0 or idx >= _mg_buttons.size():
		return
	var b: Button = _mg_buttons[idx]
	if not is_instance_valid(b):
		return
	var st := StyleBoxFlat.new()
	st.bg_color = _seq_colors[idx]
	st.set_corner_radius_all(8)
	b.add_theme_stylebox_override("normal", st)
	b.scale = Vector2(1.08, 1.08)
	if SoundSystem:
		SoundSystem.play_click(true)
	get_tree().create_timer(0.35).timeout.connect(func():
		if is_instance_valid(b):
			var st2 := StyleBoxFlat.new()
			st2.bg_color = _seq_colors[idx].darkened(0.25)
			st2.set_corner_radius_all(8)
			b.add_theme_stylebox_override("normal", st2)
			b.scale = Vector2.ONE
	)

func _on_sequence_press(idx: int) -> void:
	if not _is_working or _seq_showing or _clicks_done >= _clicks_needed:
		return
	if _seq_player_idx >= _seq_pattern.size():
		return
	if int(_seq_pattern[_seq_player_idx]) == idx:
		_flash_seq_button(idx)
		_seq_player_idx += 1
		if _seq_player_idx >= _seq_pattern.size():
			# secuencia completa
			_register_hit()
			if _clicks_done < _clicks_needed:
				_add_sequence_step()
				await get_tree().create_timer(0.45).timeout
				_show_sequence()
	else:
		_register_miss()
		if _mg_hint:
			_mg_hint.text = (LocaleSystem.t("work.seq_error", "¡Error! Se reinicia la secuencia…") if LocaleSystem else "¡Error! Se reinicia la secuencia…")
		_seq_pattern.clear()
		_add_sequence_step()
		await get_tree().create_timer(0.6).timeout
		_show_sequence()

# --- HOLD ---
func _build_hold_area(parent: VBoxContainer) -> void:
	_hold_canvas = Control.new()
	_hold_canvas.custom_minimum_size = Vector2(0, 28)
	_hold_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(_hold_canvas)
	_hold_canvas.draw.connect(_draw_hold_bar)

func _draw_hold_bar() -> void:
	if _hold_canvas == null:
		return
	var r := Rect2(Vector2.ZERO, _hold_canvas.size)
	if r.size.x < 4:
		return
	_hold_canvas.draw_rect(r, Color(0.12, 0.14, 0.18))
	# zona segura
	var zx := r.size.x * _hold_safe_min
	var zw := r.size.x * (_hold_safe_max - _hold_safe_min)
	_hold_canvas.draw_rect(Rect2(zx, 4, zw, r.size.y - 8), Color(0.95, 0.8, 0.15, 0.85))
	# centro perfecto
	var mid := (_hold_safe_min + _hold_safe_max) * 0.5
	var pw := r.size.x * 0.04
	_hold_canvas.draw_rect(Rect2(r.size.x * mid - pw * 0.5, 2, pw, r.size.y - 4), Color(1.0, 0.95, 0.4, 1.0))
	# valor actual
	var vx := r.size.x * _hold_value
	_hold_canvas.draw_rect(Rect2(0, 0, vx, r.size.y), Color(0.3, 0.65, 1.0, 0.45))
	_hold_canvas.draw_rect(Rect2(vx - 2, 0, 4, r.size.y), Color(1, 1, 1))

func _on_hold_down() -> void:
	if not _is_working or _minigame_type != "hold":
		return
	if _clicks_done >= _clicks_needed:
		return
	_hold_active = true
	_hold_value = 0.0

func _on_hold_up() -> void:
	if not _is_working or _minigame_type != "hold":
		return
	if not _hold_active:
		return
	_hold_active = false
	var mid := (_hold_safe_min + _hold_safe_max) * 0.5
	var is_perfect := absf(_hold_value - mid) < 0.04
	if _hold_value >= _hold_safe_min and _hold_value <= _hold_safe_max:
		_register_hit(1, is_perfect)
		if _mg_hint:
			_mg_hint.text = "★★ PERFECTO" if is_perfect else (LocaleSystem.t("work.safe_zone", "¡Bien! Zona segura.") if LocaleSystem else "¡Bien! Zona segura.")
		_hold_safe_min = 0.35 + randf() * 0.15
		_hold_safe_max = minf(0.95, _hold_safe_min + 0.30 + randf() * 0.08)
	else:
		_register_miss()
		if _mg_hint:
			if _hold_value < _hold_safe_min:
				_mg_hint.text = "Demasiado pronto…"
			else:
				_mg_hint.text = "Te pasaste… suelta antes"
	_hold_value = 0.0
	if click_area and _clicks_done < _clicks_needed:
		click_area.text = LocaleSystem.t("work.hold_action", "MANTÉN… y suelta en la zona") if LocaleSystem else "MANTÉN… y suelta en la zona"
		click_area.modulate = Color.WHITE
	if _hold_canvas:
		_hold_canvas.queue_redraw()

func _process_hold(delta: float) -> void:
	if not _hold_active:
		if _hold_canvas:
			_hold_canvas.queue_redraw()
		return
	_hold_value = minf(1.0, _hold_value + delta * 0.38)
	if click_area:
		var zone_txt := ""
		if _hold_value >= _hold_safe_min and _hold_value <= _hold_safe_max:
			zone_txt = " ★ ZONA"
			click_area.modulate = Color(0.55, 1.0, 0.55)
		elif _hold_value > _hold_safe_max:
			zone_txt = " ✕ TARDE"
			click_area.modulate = Color(1.0, 0.4, 0.4)
		else:
			click_area.modulate = Color.WHITE
		click_area.text = "Cargando %.0f%%%s" % [_hold_value * 100.0, zone_txt]
	if _mg_progress:
		_mg_progress.max_value = 1.0
		_mg_progress.value = _hold_value
	if _hold_canvas:
		_hold_canvas.queue_redraw()

# --- RAPID ---
func _try_rapid_hit() -> void:
	if not _is_working or _clicks_done >= _clicks_needed:
		return
	var now := Time.get_ticks_msec()
	if _last_click_ms > 0 and (now - _last_click_ms) > int(_rapid_window * 1000):
		_combo = 0
	_last_click_ms = now
	_register_hit()
	# ventana se estrecha un poco con el combo
	_rapid_window = maxf(0.55, 1.0 - float(_combo) * 0.012)
	if click_area and _clicks_done < _clicks_needed:
		click_area.text = (LocaleSystem.t("work.spam_n", "¡SPAM!  %d/%d  x%d") if LocaleSystem else "¡SPAM!  %d/%d  x%d") % [_clicks_done, _clicks_needed, _combo]

func _process_rapid(_delta: float) -> void:
	if _last_click_ms <= 0 or _clicks_done >= _clicks_needed:
		return
	var now := Time.get_ticks_msec()
	if (now - _last_click_ms) > int(_rapid_window * 1000 + 200):
		if _combo > 0:
			_combo = 0
			_update_mg_status()
			if _mg_hint:
				_mg_hint.text = (LocaleSystem.t("work.combo_broken", "Combo roto — ¡sigue clicando!") if LocaleSystem else "Combo roto — ¡sigue clicando!")

# --- CLASSIFY ---
func _build_classify_area(parent: VBoxContainer) -> void:
	var prompt := Label.new()
	prompt.name = "ClassifyPrompt"
	prompt.add_theme_font_size_override("font_size", 30)
	prompt.add_theme_color_override("font_color", Color(0.95, 0.95, 0.7))
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(prompt)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	parent.add_child(row)

	var left := Button.new()
	left.custom_minimum_size = Vector2(120, 48)
	left.add_theme_font_size_override("font_size", 30)
	var ls := StyleBoxFlat.new()
	ls.bg_color = Color(0.25, 0.4, 0.7)
	ls.set_corner_radius_all(6)
	left.add_theme_stylebox_override("normal", ls)
	left.add_theme_color_override("font_color", Color.WHITE)
	left.pressed.connect(func(): _on_classify(0))
	row.add_child(left)

	var right := Button.new()
	right.custom_minimum_size = Vector2(120, 48)
	right.add_theme_font_size_override("font_size", 30)
	var rs := StyleBoxFlat.new()
	rs.bg_color = Color(0.7, 0.35, 0.25)
	rs.set_corner_radius_all(6)
	right.add_theme_stylebox_override("normal", rs)
	right.add_theme_color_override("font_color", Color.WHITE)
	right.pressed.connect(func(): _on_classify(1))
	row.add_child(right)

	_mg_buttons.append(prompt)
	_mg_buttons.append(left)
	_mg_buttons.append(right)

func _next_classify_item() -> void:
	var sets: Array = [
		{"prompt": "Foto: rostro borroso en un pasillo", "left": "Real", "right": "Fake", "answer": 0},
		{"prompt": "Imagen: logo de WorkGrid distorsionado", "left": "Seguro", "right": "Sospechoso", "answer": 1},
		{"prompt": "Captura: mensaje de 'mamá'", "left": (LocaleSystem.t("work.legitimate", "Legítimo") if LocaleSystem else "Legítimo"), "right": (LocaleSystem.t("work.hallucination", "Alucinación") if LocaleSystem else "Alucinación"), "answer": 1},
		{"prompt": "Archivo: recibo HOTEL MERIDIAN", "left": "Evidencia", "right": "Basura", "answer": 0},
		{"prompt": "Audio: respiración + «no mires atrás»", "left": "Pista", "right": "Ruido", "answer": 0},
		{"prompt": "Mail: «la cena está lista»", "left": "Real", "right": "Falso", "answer": 1},
		{"prompt": "Log: BOOT… mismo checksum", "left": "Sistema", "right": "Paranoia", "answer": 1},
		{"prompt": "Foto: mano que coincide con la tuya", "left": "Clave", "right": "Irrelevante", "answer": 0},
		{"prompt": "Transacción: UNKNOWN RELAY +$450", "left": "Sospechosa", "right": "Normal", "answer": 0},
		{"prompt": "Video: silueta cruzando la puerta", "left": "Evidencia", "right": "Glitch", "answer": 0},
		{"prompt": "Nota: «No confíes en todos los correos»", "left": "Tuya", "right": "Ajena", "answer": 0},
		{"prompt": "Contrato: «El sujeto no recordará…»", "left": "Importante", "right": "Basura", "answer": 0},
		{"prompt": "Mail policial sin sello oficial", "left": "Oficial", "right": "Falso", "answer": 1},
		{"prompt": "Mapa marcado hasta la frontera", "left": "Ruta real", "right": "Invención", "answer": 0},
		{"prompt": "Archivo: YA ESTÁS DENTRO", "left": "Disco real", "right": (LocaleSystem.t("work.hallucination", "Alucinación") if LocaleSystem else "Alucinación"), "answer": 1},
		{"prompt": "Lista con tu apellido tachado", "left": "Amenaza", "right": "Coincidencia", "answer": 0},
	]
	var pick: Dictionary = sets[randi() % sets.size()]
	_classify_prompt = str(pick["prompt"])
	_classify_left_label = str(pick["left"])
	_classify_right_label = str(pick["right"])
	_classify_answer = int(pick["answer"])
	if _mg_buttons.size() >= 3:
		var prompt_lbl: Label = _mg_buttons[0]
		var left_btn: Button = _mg_buttons[1]
		var right_btn: Button = _mg_buttons[2]
		if is_instance_valid(prompt_lbl):
			prompt_lbl.text = _classify_prompt
		if is_instance_valid(left_btn):
			left_btn.text = "← " + _classify_left_label
		if is_instance_valid(right_btn):
			right_btn.text = _classify_right_label + " →"
	if _mg_hint:
		_mg_hint.text = (LocaleSystem.t("work.pick_category", "Elige la categoría correcta") if LocaleSystem else "Elige la categoría correcta")

func _on_classify(side: int) -> void:
	if not _is_working or _clicks_done >= _clicks_needed:
		return
	if side == _classify_answer:
		_register_hit()
		if _mg_hint:
			_mg_hint.text = (LocaleSystem.t("work.correct", "Correcto") if LocaleSystem else "Correcto")
	else:
		_register_miss()
		if _mg_hint:
			_mg_hint.text = (LocaleSystem.t("work.incorrect", "Incorrecto…") if LocaleSystem else "Incorrecto…")
	if _clicks_done < _clicks_needed:
		_next_classify_item()

# --- TYPE ---
func _build_type_area(parent: VBoxContainer) -> void:
	var target_lbl := Label.new()
	target_lbl.name = "TypeTarget"
	target_lbl.add_theme_font_size_override("font_size", 38)
	target_lbl.add_theme_color_override("font_color", Color(0.95, 0.9, 0.4))
	target_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(target_lbl)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)

	for k in _type_keys:
		var b := Button.new()
		b.text = str(k)
		b.custom_minimum_size = Vector2(40, 40)
		b.add_theme_font_size_override("font_size", 30)
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0.22, 0.28, 0.38)
		st.set_corner_radius_all(5)
		b.add_theme_stylebox_override("normal", st)
		b.add_theme_color_override("font_color", Color.WHITE)
		var key := str(k)
		b.pressed.connect(func(): _on_type_key(key))
		row.add_child(b)
		_mg_buttons.append(b)

	_mg_buttons.insert(0, target_lbl)  # [0] = label

func _generate_type_target() -> void:
	var length: int = mini(4, 2 + int(_clicks_done / 2))
	_type_target = ""
	for i in range(length):
		_type_target += str(_type_keys[randi() % _type_keys.size()])
	_type_progress = 0
	_refresh_type_display()

func _refresh_type_display() -> void:
	if _mg_buttons.is_empty():
		return
	var lbl = _mg_buttons[0]
	if not is_instance_valid(lbl):
		return
	var done_part: String = _type_target.substr(0, _type_progress)
	var rest: String = _type_target.substr(_type_progress)
	lbl.text = "[%s]%s" % [done_part, rest]

func _on_type_key(key: String) -> void:
	if not _is_working or _clicks_done >= _clicks_needed:
		return
	if _type_progress >= _type_target.length():
		return
	var expected: String = _type_target[_type_progress]
	if key == expected:
		_type_progress += 1
		_refresh_type_display()
		if SoundSystem:
			SoundSystem.play_click(true)
		if _type_progress >= _type_target.length():
			_register_hit(1, _type_target.length() >= 5)
			if _clicks_done < _clicks_needed:
				_generate_type_target()
	else:
		_register_miss()
		_type_progress = 0
		_refresh_type_display()
		if _mg_hint:
			_mg_hint.text = "Tecla incorrecta — reiniciado"

# --- DECRYPT ---
func _build_decrypt_area(parent: VBoxContainer) -> void:
	var code_lbl := Label.new()
	code_lbl.name = "DecryptCode"
	code_lbl.add_theme_font_size_override("font_size", 35)
	code_lbl.add_theme_color_override("font_color", Color(0.4, 0.95, 0.7))
	code_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(code_lbl)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	for i in range(4):
		var b := Button.new()
		b.custom_minimum_size = Vector2(52, 44)
		b.add_theme_font_size_override("font_size", 27)
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0.18, 0.28, 0.22)
		st.set_corner_radius_all(6)
		st.border_width_left = 1
		st.border_width_top = 1
		st.border_width_right = 1
		st.border_width_bottom = 1
		st.border_color = Color(0.3, 0.7, 0.45, 0.6)
		b.add_theme_stylebox_override("normal", st)
		b.add_theme_color_override("font_color", Color(0.85, 1.0, 0.9))
		var idx := i
		b.pressed.connect(func(): _on_decrypt_choice(idx))
		row.add_child(b)
		_mg_buttons.append(b)

	_mg_buttons.insert(0, code_lbl)

func _generate_decrypt() -> void:
	_decrypt_code.clear()
	var length: int = mini(4, 2 + int(_clicks_done / 2))
	for i in range(length):
		_decrypt_code.append(randi() % 10)
	_decrypt_idx = 0
	_refresh_decrypt_options()

func _refresh_decrypt_options() -> void:
	if _mg_buttons.is_empty():
		return
	var lbl = _mg_buttons[0]
	if is_instance_valid(lbl):
		var shown := ""
		for i in range(_decrypt_code.size()):
			if i < _decrypt_idx:
				shown += str(_decrypt_code[i]) + " "
			elif i == _decrypt_idx:
				shown += "? "
			else:
				shown += "· "
		lbl.text = shown.strip_edges()

	if _decrypt_idx >= _decrypt_code.size():
		return
	var correct: int = int(_decrypt_code[_decrypt_idx])
	_decrypt_options = [correct]
	while _decrypt_options.size() < 4:
		var d := randi() % 10
		if d not in _decrypt_options:
			_decrypt_options.append(d)
	# shuffle
	for i in range(_decrypt_options.size() - 1, 0, -1):
		var j := randi() % (i + 1)
		var tmp = _decrypt_options[i]
		_decrypt_options[i] = _decrypt_options[j]
		_decrypt_options[j] = tmp

	for i in range(4):
		if i + 1 >= _mg_buttons.size():
			break
		var b: Button = _mg_buttons[i + 1]
		if is_instance_valid(b):
			b.text = str(_decrypt_options[i])
			b.disabled = false

func _on_decrypt_choice(opt_idx: int) -> void:
	if not _is_working or _clicks_done >= _clicks_needed:
		return
	if _decrypt_idx >= _decrypt_code.size():
		return
	if opt_idx < 0 or opt_idx >= _decrypt_options.size():
		return
	var chosen: int = int(_decrypt_options[opt_idx])
	var expected: int = int(_decrypt_code[_decrypt_idx])
	if chosen == expected:
		_decrypt_idx += 1
		if SoundSystem:
			SoundSystem.play_click(true)
		if _decrypt_idx >= _decrypt_code.size():
			_register_hit(1, _decrypt_code.size() >= 5)
			if _clicks_done < _clicks_needed:
				_generate_decrypt()
			else:
				_refresh_decrypt_options()
		else:
			_refresh_decrypt_options()
			if _mg_hint:
				_mg_hint.text = (LocaleSystem.t("work.digit_next", "Correcto… siguiente dígito") if LocaleSystem else "Correcto… siguiente dígito")
	else:
		_register_miss()
		_decrypt_idx = 0
		_refresh_decrypt_options()
		if _mg_hint:
			_mg_hint.text = (LocaleSystem.t("work.digit_wrong", "Dígito incorrecto — código reiniciado") if LocaleSystem else "Dígito incorrecto — código reiniciado")

# --- TECLADO ---
func _unhandled_input(event: InputEvent) -> void:
	if not _is_working or not _process_mg:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key := event as InputEventKey
	var code := key.keycode

	match _minigame_type:
		"sequence":
			if _seq_showing:
				return
			var map := {
				KEY_1: 0, KEY_2: 1, KEY_3: 2, KEY_4: 3,
				KEY_KP_1: 0, KEY_KP_2: 1, KEY_KP_3: 2, KEY_KP_4: 3
			}
			if map.has(code):
				_on_sequence_press(int(map[code]))
				get_viewport().set_input_as_handled()
		"type":
			var ch := String.chr(key.unicode).to_upper() if key.unicode > 0 else ""
			if ch in _type_keys:
				_on_type_key(ch)
				get_viewport().set_input_as_handled()
		"timing":
			if code in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
				_try_timing_hit()
				get_viewport().set_input_as_handled()
		"decrypt":
			if code >= KEY_0 and code <= KEY_9:
				var digit := code - KEY_0
				for i in range(_decrypt_options.size()):
					if int(_decrypt_options[i]) == digit:
						_on_decrypt_choice(i)
						get_viewport().set_input_as_handled()
						break
			elif code >= KEY_KP_0 and code <= KEY_KP_9:
				var digit2 := code - KEY_KP_0
				for i in range(_decrypt_options.size()):
					if int(_decrypt_options[i]) == digit2:
						_on_decrypt_choice(i)
						get_viewport().set_input_as_handled()
						break
		"classify":
			if code in [KEY_LEFT, KEY_A]:
				_on_classify(0)
				get_viewport().set_input_as_handled()
			elif code in [KEY_RIGHT, KEY_D]:
				_on_classify(1)
				get_viewport().set_input_as_handled()
		"rapid", "click":
			if code == KEY_SPACE:
				_on_work_click()
				get_viewport().set_input_as_handled()
