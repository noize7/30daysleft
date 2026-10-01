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
##   mirror    — secuencia INVERTIDA (deep web, difícil)
##   signal    — aislar señal real entre ruido con ventana que se estrecha (deep web, difícil)

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
var _type_keys: Array = ["W", "A", "S", "D", "E", "R", "F", "G","X","B","M","N","L"]

# Decrypt
var _decrypt_code: Array = []
var _decrypt_idx: int = 0
var _decrypt_options: Array = []

# Mirror (secuencia invertida — deep web)
var _mirror_pattern: Array = []
var _mirror_player_idx: int = 0
var _mirror_showing: bool = false
var _mirror_expected: Array = []  # patrón invertido que debe introducir el jugador

# Signal (aislar señal real entre ruido — deep web)
var _signal_options: Array = []  # textos de cada botón
var _signal_correct: int = 0
var _signal_time_left: float = 0.0
var _signal_window: float = 2.4  # se estrecha con cada acierto
var _signal_timer_bar: ProgressBar = null

# Quiz — encuesta (elige la respuesta correcta)
var _quiz_answer: int = 0
var _quiz_prompt: String = ""

# Tag — clasificar imágenes (elige categoría)
var _tag_answer: int = 0
var _tag_prompt: String = ""

# Swipe — filtrar contenido (aprobar/rechazar con timer)
var _swipe_answer: int = 0  # 0=reject 1=approve
var _swipe_prompt: String = ""
var _swipe_time: float = 0.0
var _swipe_window: float = 1.8
var _swipe_timer_bar: ProgressBar = null

# Cleanse — limpieza de datos (marcar celdas corruptas en rejilla)
var _cleanse_cells: Array = []  # true = corrupta
var _cleanse_found: int = 0
var _cleanse_needed: int = 0
var _cleanse_grid: GridContainer = null

# Scrape — scraping gris (clicar solo paquetes válidos)
var _scrape_is_valid: Array = []
var _scrape_labels: Array = []

# Proxy — enrutar saltos correctos (secuencia de nodos)
var _proxy_path: Array = []
var _proxy_player_idx: int = 0
var _proxy_options: Array = []

# Mine — minería (mantén y suelta SOLO en el pico)
var _mine_active: bool = false
var _mine_value: float = 0.0
var _mine_spike_min: float = 0.55
var _mine_spike_max: float = 0.72
var _mine_canvas: Control = null

# Shadow — contacto sombra (clica solo en zona oscura)
var _shadow_pos: float = 0.0
var _shadow_dir: float = 1.0
var _shadow_speed: float = 1.1
var _shadow_dark_min: float = 0.35
var _shadow_dark_max: float = 0.55
var _shadow_canvas: Control = null

# Zeroday — encontrar la celda vulnerable en rejilla con timer
var _zeroday_grid_size: int = 4
var _zeroday_vuln: int = 0
var _zeroday_time: float = 0.0
var _zeroday_window: float = 3.2
var _zeroday_timer_bar: ProgressBar = null
var _zeroday_cells: Array = []

var MINIGAME_DESC := {
	"click": (LocaleSystem.t("work.desc_click", "Ritmo + combo. Clica con buen tempo para multiplicar.") if LocaleSystem else "Ritmo + combo. Clica con buen tempo para multiplicar."),
	"timing": (LocaleSystem.t("work.mg_timing", "Barra móvil: zona verde = ok, zona dorada = PERFECTO.") if LocaleSystem else "Barra móvil: zona verde = ok, zona dorada = PERFECTO."),
	"sequence": (LocaleSystem.t("work.desc_sequence", "Memoriza y repite la secuencia (botones o teclas 1-4).") if LocaleSystem else "Memoriza y repite la secuencia (botones o teclas 1-4)."),
	"hold": (LocaleSystem.t("work.mg_hold", "Mantén pulsado y suelta dentro de la zona segura.") if LocaleSystem else "Mantén pulsado y suelta dentro de la zona segura."),
	"rapid": (LocaleSystem.t("work.mg_spam", "Clics rápidos. Mantén el ritmo o pierdes el combo.") if LocaleSystem else "Clics rápidos. Mantén el ritmo o pierdes el combo."),
	"classify": (LocaleSystem.t("work.mg_classify", "Clasifica cada ítem a izquierda o derecha.") if LocaleSystem else "Clasifica cada ítem a izquierda o derecha."),
	"type": "Pulsa las teclas en el orden indicado (teclado o botones).",
	"decrypt": (LocaleSystem.t("work.mg_code", "Descifra el código eligiendo el dígito correcto.") if LocaleSystem else "Descifra el código eligiendo el dígito correcto."),
	"mirror": "Invierte la traza: memoriza y repite AL REVÉS. Un fallo y dejan rastro de ti.",
	"signal": "Separa el recuerdo real del ruido. Solo UNA señal es verdadera.",
	"quiz": "Encuesta anónima del programa. Responde… aunque la pregunta te suene rara.",
	"tag": "Etiqueta fotos que no deberías estar viendo. Algunas se parecen a esa noche.",
	"swipe": "Filtra contenido antes de que el tiempo se acabe. Dudar también cuesta.",
	"cleanse": "Borra las celdas 'corruptas'. A veces borras más de lo que quieres recordar.",
	"scrape": "Extrae solo lo válido. El cebo está hecho para gente que huye.",
	"proxy": "Enruta tu rastro por saltos anónimos. Mal hop = huella para la policía.",
	"mine": "Minería oculta: suelta SOLO en el pico. El ruido tapa… ¿o no?",
	"shadow": "Contacta solo en la oscuridad. Si te ven, no es el programa quien paga.",
	"zeroday": "Encuentra el fallo antes de que se cierre la ventana. Como tus 30 días."
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
		"signal":
			_process_signal(delta)
		"swipe":
			_process_swipe(delta)
		"mine":
			_process_mine(delta)
		"shadow":
			_process_shadow(delta)
		"zeroday":
			_process_zeroday(delta)

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
		job_details.add_theme_font_size_override("font_size", 24)
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
		job_list.add_theme_color_override("font_color", Color(0.12, 0.12, 0.12))
		job_list.add_theme_font_size_override("font_size", 24)
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
				"decrypt": "🔓", "mirror": "↻", "signal": "📡",
				"quiz": "❓", "tag": "🏷", "swipe": "↔",
				"cleanse": "🧹", "scrape": "⛏", "proxy": "🔀",
				"mine": "💎", "shadow": "🌑", "zeroday": "💀"
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
	GameManager.is_job_running = true
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
	GameManager.is_job_running = false
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
	var job_result: Dictionary = _current_job.duplicate()
	job_result["quality"] = quality
	GameManager.complete_job(final_pay, job_result)

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
		if LoopSystem and LoopSystem.streak > 1:
			reward_label.text += "  RACHA×%d" % LoopSystem.streak
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
		"mirror":
			_build_mirror_area(vbox)
		"classify":
			_build_classify_area(vbox)
		"type":
			_build_type_area(vbox)
		"decrypt":
			_build_decrypt_area(vbox)
		"signal":
			_build_signal_area(vbox)
		"quiz":
			_build_quiz_area(vbox)
		"tag":
			_build_tag_area(vbox)
		"swipe":
			_build_swipe_area(vbox)
		"cleanse":
			_build_cleanse_area(vbox)
		"scrape":
			_build_scrape_area(vbox)
		"proxy":
			_build_proxy_area(vbox)
		"mine":
			_build_mine_area(vbox)
			if click_area:
				click_area.visible = true
				click_area.disabled = false
				click_area.text = "MANTÉN EL RITMO…"
		"shadow":
			_build_shadow_area(vbox)
			if click_area:
				click_area.visible = true
				click_area.disabled = false
				click_area.text = "CONTACTAR (solo si nadie mira)"
		"zeroday":
			_build_zeroday_area(vbox)
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
	_signal_timer_bar = null
	_swipe_timer_bar = null
	_cleanse_grid = null
	_mine_canvas = null
	_shadow_canvas = null
	_zeroday_timer_bar = null
	_zeroday_cells.clear()
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
		"mirror":
			_mirror_pattern.clear()
			_mirror_expected.clear()
			_mirror_player_idx = 0
			_mirror_showing = false
			_add_mirror_step()
			if _mg_hint:
				_mg_hint.text = "⚠ Programa oscuro — observa la traza… luego INVIÉRTELA (1-4)"
			call_deferred("_show_mirror")
		"signal":
			_signal_window = 2.55 - float(GameManager.job_level) * 0.08
			_next_signal_round()
			if _mg_hint:
				_mg_hint.text = "⚠ Separa el recuerdo real del ruido. Solo UNA señal es verdadera."
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
		"quiz":
			_next_quiz()
		"tag":
			_next_tag()
		"swipe":
			_swipe_window = 2.0 - float(GameManager.job_level) * 0.05
			_next_swipe()
		"cleanse":
			_next_cleanse()
		"scrape":
			_next_scrape()
		"proxy":
			_next_proxy()
		"mine":
			_mine_active = false
			_mine_value = 0.0
			_mine_spike_min = 0.50 + randf() * 0.12
			_mine_spike_max = minf(0.92, _mine_spike_min + 0.14)
			if click_area:
				click_area.text = "MANTÉN EL RITMO…"
			if _mg_hint:
				_mg_hint.text = "💎 Suelta SOLO en el pico. El ruido del ventilador no tapa todo."
		"shadow":
			_shadow_pos = 0.0
			_shadow_dir = 1.0
			_shadow_speed = 0.95 + float(GameManager.job_level) * 0.08
			_shadow_dark_min = 0.28 + randf() * 0.15
			_shadow_dark_max = minf(0.75, _shadow_dark_min + 0.18)
			if click_area:
				click_area.text = "CONTACTAR (solo si nadie mira)"
			if _mg_hint:
				_mg_hint.text = "🌑 Solo en la oscuridad. Si te ven, no es el programa quien paga."
		"zeroday":
			_zeroday_window = 3.6 - float(GameManager.job_level) * 0.15
			_next_zeroday()
		_:
			if click_area:
				click_area.text = "CLICK  0/%d" % _clicks_needed
			if _mg_hint:
				_mg_hint.text = (LocaleSystem.t("work.rhythm_hint", "Clica con ritmo. Los combos aumentan la paga.") if LocaleSystem else "Clica con ritmo. Los combos aumentan la paga.")

# --- CLICK (ritmo) ---
func _on_work_click() -> void:
	if not _is_working:
		return
	if _minigame_type in ["sequence", "classify", "type", "mirror", "signal", "decrypt",
			"quiz", "tag", "swipe", "cleanse", "scrape", "proxy", "zeroday"]:
		return  # usan sus propios botones
	if _minigame_type == "hold":
		return  # se gestiona con button_down/up
	if _minigame_type == "mine":
		return  # button_down/up
	if _minigame_type == "timing":
		_try_timing_hit()
		return
	if _minigame_type == "shadow":
		_try_shadow_hit()
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
	if not _is_working:
		return
	if _clicks_done >= _clicks_needed:
		return
	if _minigame_type == "hold":
		_hold_active = true
		_hold_value = 0.0
	elif _minigame_type == "mine":
		_mine_active = true
		_mine_value = 0.0

func _on_hold_up() -> void:
	if not _is_working:
		return
	if _minigame_type == "hold":
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
	elif _minigame_type == "mine":
		if not _mine_active:
			return
		_mine_active = false
		var mid := (_mine_spike_min + _mine_spike_max) * 0.5
		var is_perfect := absf(_mine_value - mid) < 0.03
		if _mine_value >= _mine_spike_min and _mine_value <= _mine_spike_max:
			_register_hit(1, is_perfect)
			if _mg_hint:
				_mg_hint.text = "💎 ★ HASH PERFECTO" if is_perfect else "💎 Pico capturado"
			_mine_spike_min = 0.45 + randf() * 0.20
			_mine_spike_max = minf(0.92, _mine_spike_min + 0.10 + randf() * 0.04)
		else:
			_register_miss()
			if _mg_hint:
				_mg_hint.text = "🔥 Te pasaste del pico — rastros en el log"
		_mine_value = 0.0
		if click_area and _clicks_done < _clicks_needed:
			click_area.text = "MANTÉN EL RITMO…"
			click_area.modulate = Color.WHITE
		if _mine_canvas:
			_mine_canvas.queue_redraw()

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
	# Clasificar: real vs alucinación / evidencia vs ruido — núcleo de la historia
	var sets: Array = [
		{"prompt": "Foto: rostro borroso en un pasillo", "left": "Real", "right": "Fake", "answer": 0},
		{"prompt": "Captura: mensaje de alguien que ya no está", "left": "Legítimo", "right": "Alucinación", "answer": 1},
		{"prompt": "Archivo: recibo de un hotel de una sola noche", "left": "Evidencia", "right": "Basura", "answer": 0},
		{"prompt": "Audio: respiración + «no mires atrás»", "left": "Pista", "right": "Ruido", "answer": 0},
		{"prompt": "Mail: «la cena está lista»", "left": "Real", "right": "Falso", "answer": 1},
		{"prompt": "Log: mismo checksum cada arranque", "left": "Sistema", "right": "Paranoia", "answer": 1},
		{"prompt": "Foto: una mano que coincide con la tuya", "left": "Clave", "right": "Irrelevante", "answer": 0},
		{"prompt": "Transacción: relay desconocido +$450", "left": "Sospechosa", "right": "Normal", "answer": 0},
		{"prompt": "Video: silueta cruzando la puerta", "left": "Evidencia", "right": "Glitch", "answer": 0},
		{"prompt": "Nota: «No confíes en todos los correos»", "left": "Tuya", "right": "Ajena", "answer": 0},
		{"prompt": "Mail sin sello oficial que habla de 'el caso'", "left": "Oficial", "right": "Falso", "answer": 1},
		{"prompt": "Mapa marcado hasta la frontera", "left": "Ruta real", "right": "Invención", "answer": 0},
		{"prompt": "Archivo: YA ESTÁS DENTRO", "left": "Disco real", "right": "Alucinación", "answer": 1},
		{"prompt": "Lista con un apellido tachado — el tuyo", "left": "Amenaza", "right": "Coincidencia", "answer": 0},
		{"prompt": "Foto de una botella rota en el suelo", "left": "Recuerdo", "right": "Ruido", "answer": 0},
		{"prompt": "Notificación: 'alguien vio tu conexión'", "left": "Real", "right": "Paranoia", "answer": 1},
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

# --- MIRROR (secuencia invertida — deep web, difícil) ---
func _build_mirror_area(parent: VBoxContainer) -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	parent.add_child(grid)
	for i in range(4):
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.text = _seq_labels[i]
		b.add_theme_font_size_override("font_size", 28)
		var bs := StyleBoxFlat.new()
		bs.bg_color = _seq_colors[i].darkened(0.35)
		bs.set_corner_radius_all(6)
		bs.border_width_left = 2
		bs.border_width_top = 2
		bs.border_width_right = 2
		bs.border_width_bottom = 2
		bs.border_color = _seq_colors[i]
		b.add_theme_stylebox_override("normal", bs)
		b.add_theme_color_override("font_color", Color.WHITE)
		var idx := i
		b.pressed.connect(func(): _on_mirror_press(idx))
		grid.add_child(b)
		_mg_buttons.append(b)

func _add_mirror_step() -> void:
	# Más pasos y más rápido que sequence normal → más difícil
	var base_len := 3 + int(_clicks_done)
	while _mirror_pattern.size() < base_len:
		_mirror_pattern.append(randi() % 4)
	_mirror_expected = _mirror_pattern.duplicate()
	_mirror_expected.reverse()
	_mirror_player_idx = 0

func _show_mirror() -> void:
	if not _is_working:
		return
	_mirror_showing = true
	for b in _mg_buttons:
		if is_instance_valid(b):
			b.disabled = true
	if _mg_hint:
		_mg_hint.text = "Observa la traza… (después AL REVÉS)"
	for step in _mirror_pattern:
		if not _is_working:
			return
		await get_tree().create_timer(0.28).timeout
		_flash_mirror_btn(int(step), true)
		await get_tree().create_timer(0.38).timeout
		_flash_mirror_btn(int(step), false)
	await get_tree().create_timer(0.2).timeout
	_mirror_showing = false
	for b in _mg_buttons:
		if is_instance_valid(b):
			b.disabled = false
	if _mg_hint:
		_mg_hint.text = "↻ Ahora INVIERTE la secuencia (1-4)"

func _flash_mirror_btn(idx: int, on: bool) -> void:
	if idx < 0 or idx >= _mg_buttons.size():
		return
	var b: Button = _mg_buttons[idx]
	if not is_instance_valid(b):
		return
	var bs := StyleBoxFlat.new()
	if on:
		bs.bg_color = _seq_colors[idx]
		bs.set_corner_radius_all(6)
		b.modulate = Color(1.4, 1.4, 1.4)
	else:
		bs.bg_color = _seq_colors[idx].darkened(0.35)
		bs.set_corner_radius_all(6)
		bs.border_width_left = 2
		bs.border_width_top = 2
		bs.border_width_right = 2
		bs.border_width_bottom = 2
		bs.border_color = _seq_colors[idx]
		b.modulate = Color.WHITE
	b.add_theme_stylebox_override("normal", bs)

func _on_mirror_press(idx: int) -> void:
	if not _is_working or _mirror_showing or _clicks_done >= _clicks_needed:
		return
	if _mirror_player_idx >= _mirror_expected.size():
		return
	var expected: int = int(_mirror_expected[_mirror_player_idx])
	if idx == expected:
		_mirror_player_idx += 1
		_flash_mirror_btn(idx, true)
		if SoundSystem:
			SoundSystem.play_click(true)
		if _mirror_player_idx >= _mirror_expected.size():
			# Secuencia completa al revés → hit (perfecto si era larga)
			_register_hit(1, _mirror_expected.size() >= 5)
			if _clicks_done < _clicks_needed:
				_add_mirror_step()
				call_deferred("_show_mirror")
			if _mg_hint:
				_mg_hint.text = "✓ Traza invertida OK"
		else:
			if _mg_hint:
				_mg_hint.text = "↻ %d/%d … sigue al revés" % [_mirror_player_idx, _mirror_expected.size()]
	else:
		_register_miss()
		_mirror_player_idx = 0
		if _mg_hint:
			_mg_hint.text = "✕ Fallo — traza reiniciada. Observa de nuevo."
		call_deferred("_show_mirror")

# --- SIGNAL (aislar señal real entre ruido — deep web, difícil) ---
func _build_signal_area(parent: VBoxContainer) -> void:
	_signal_timer_bar = ProgressBar.new()
	_signal_timer_bar.custom_minimum_size = Vector2(0, 14)
	_signal_timer_bar.max_value = 1.0
	_signal_timer_bar.value = 1.0
	var sfill := StyleBoxFlat.new()
	sfill.bg_color = Color(0.85, 0.25, 0.2)
	sfill.set_corner_radius_all(3)
	_signal_timer_bar.add_theme_stylebox_override("fill", sfill)
	var sbg := StyleBoxFlat.new()
	sbg.bg_color = Color(0.12, 0.14, 0.18)
	sbg.set_corner_radius_all(3)
	_signal_timer_bar.add_theme_stylebox_override("background", sbg)
	parent.add_child(_signal_timer_bar)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	parent.add_child(grid)
	for i in range(4):
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 48)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 22)
		var bs := StyleBoxFlat.new()
		bs.bg_color = Color(0.15, 0.18, 0.24)
		bs.set_corner_radius_all(6)
		bs.border_width_left = 1
		bs.border_width_top = 1
		bs.border_width_right = 1
		bs.border_width_bottom = 1
		bs.border_color = Color(0.4, 0.55, 0.7)
		b.add_theme_stylebox_override("normal", bs)
		b.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
		var idx := i
		b.pressed.connect(func(): _on_signal_choice(idx))
		grid.add_child(b)
		_mg_buttons.append(b)

func _next_signal_round() -> void:
	# Genera 4 etiquetas; solo una es la señal real
	var real_pool := [
		"FREQ-7A3", "NODE-Ω", "PKT_REAL", "HANDSHAKE", "TOR-EXIT",
		"AUTH_OK", "CORE-SIG", "LIVE_CH", "TRUE_BIT", "ROOT_KEY"
	]
	var noise_pool := [
		"noise…", "static", "NULL", "????", "echo",
		"ghost", "spoof", "DEAD", "0x00", "jitter",
		"fake_ch", "drift", "…", "corrupt", "timeout"
	]
	_signal_correct = randi() % 4
	_signal_options.clear()
	var used_noise: Array = []
	for i in range(4):
		if i == _signal_correct:
			_signal_options.append(real_pool[randi() % real_pool.size()])
		else:
			var n: String = noise_pool[randi() % noise_pool.size()]
			while n in used_noise:
				n = noise_pool[randi() % noise_pool.size()]
			used_noise.append(n)
			_signal_options.append(n)
	_signal_time_left = maxf(0.85, _signal_window)
	for i in range(mini(4, _mg_buttons.size())):
		var b: Button = _mg_buttons[i]
		if is_instance_valid(b):
			b.text = str(_signal_options[i])
			b.disabled = false
			b.modulate = Color.WHITE
	if _signal_timer_bar:
		_signal_timer_bar.max_value = _signal_time_left
		_signal_timer_bar.value = _signal_time_left
	if _mg_hint:
		_mg_hint.text = "📡 Aísla la señal real  ·  %.1fs" % _signal_time_left

func _process_signal(delta: float) -> void:
	if _signal_time_left <= 0.0:
		return
	_signal_time_left -= delta
	if _signal_timer_bar:
		_signal_timer_bar.value = maxf(0.0, _signal_time_left)
		# Pasa a rojo cuando queda poco
		var ratio := _signal_time_left / maxf(0.01, _signal_window)
		var sfill := StyleBoxFlat.new()
		sfill.set_corner_radius_all(3)
		if ratio < 0.35:
			sfill.bg_color = Color(1.0, 0.15, 0.12)
		elif ratio < 0.6:
			sfill.bg_color = Color(0.95, 0.55, 0.1)
		else:
			sfill.bg_color = Color(0.85, 0.25, 0.2)
		_signal_timer_bar.add_theme_stylebox_override("fill", sfill)
	if _signal_time_left <= 0.0:
		_signal_time_left = 0.0
		_register_miss()
		if _mg_hint:
			_mg_hint.text = "⏱ Tiempo agotado — señal perdida"
		# Penaliza y abre otra ronda más estrecha
		_signal_window = maxf(0.9, _signal_window - 0.12)
		if _clicks_done < _clicks_needed:
			_next_signal_round()

func _on_signal_choice(idx: int) -> void:
	if not _is_working or _clicks_done >= _clicks_needed:
		return
	if _signal_time_left <= 0.0:
		return
	if idx == _signal_correct:
		var was_fast := _signal_time_left > _signal_window * 0.45
		_register_hit(1, was_fast)
		# Cada acierto estrecha la ventana
		_signal_window = maxf(0.85, _signal_window - 0.15)
		if _mg_hint:
			_mg_hint.text = "✓ Señal aislada" + (" ★" if was_fast else "")
		if _clicks_done < _clicks_needed:
			_next_signal_round()
	else:
		_register_miss()
		if _mg_hint:
			_mg_hint.text = "✕ Era ruido — señal contaminada"
		_signal_window = maxf(0.9, _signal_window - 0.08)
		if _clicks_done < _clicks_needed:
			_next_signal_round()

# =============================================================================
# MINIJUEGOS NUEVOS — quiz / tag / swipe / cleanse / scrape / proxy / mine / shadow / zeroday
# =============================================================================

func _build_quiz_area(parent: VBoxContainer) -> void:
	var prompt := Label.new()
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt.add_theme_font_size_override("font_size", 22)
	prompt.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(prompt)
	_mg_buttons.append(prompt)
	for i in range(4):
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 36)
		b.add_theme_font_size_override("font_size", 20)
		var idx := i
		b.pressed.connect(func(): _on_quiz_choice(idx))
		parent.add_child(b)
		_mg_buttons.append(b)

func _next_quiz() -> void:
	# Encuestas del programa anónimo — a veces inocentes, a veces tocan la herida
	var qs: Array = [
		{"q": "¿Cuántas horas dormiste anoche?", "opts": ["2", "4", "7", "No recuerdo"], "a": 3},
		{"q": "¿Vives solo?", "opts": ["Sí", "No", "Antes no", "Prefiero no decir"], "a": 0},
		{"q": "¿Has oído golpes en la puerta esta semana?", "opts": ["No", "Sí", "Fue el viento", "No abrí"], "a": 0},
		{"q": "El captcha: 3 + 4 = ?", "opts": ["5", "7", "12", "sangre"], "a": 1},
		{"q": "¿Aceptas trabajar sin conocer al cliente?", "opts": ["Acepto", "Rechazo", "¿Qué cliente?", "Ya no importa"], "a": 0},
		{"q": "¿Piensas salir del país pronto?", "opts": ["No", "Sí", "Si junto el dinero", "No es asunto suyo"], "a": 2},
		{"q": "¿Recuerdas lo que hiciste anoche?", "opts": ["Sí", "No", "A medias", "No quiero"], "a": 2},
		{"q": "Marca lo que NO es un sistema operativo", "opts": ["Windows", "Linux", "ToasterOS", "macOS"], "a": 2},
		{"q": "¿Usas tu nombre real en este programa?", "opts": ["Sí", "Nunca", "A veces", "Ya no tengo nombre"], "a": 1},
		{"q": "Si alguien toca a tu puerta a las 3 AM…", "opts": ["Abro", "No abro", "Apago la luz", "No estoy"], "a": 1},
	]
	var pick: Dictionary = qs[randi() % qs.size()]
	_quiz_prompt = str(pick["q"])
	_quiz_answer = int(pick["a"])
	var opts: Array = pick["opts"]
	if _mg_buttons.size() >= 5:
		(_mg_buttons[0] as Label).text = _quiz_prompt
		for i in range(4):
			var b: Button = _mg_buttons[i + 1]
			if is_instance_valid(b):
				b.text = "%d) %s" % [i + 1, opts[i]]
				b.disabled = false
	if _mg_hint:
		_mg_hint.text = "❓ Encuesta del programa — responde (1-4)"

func _on_quiz_choice(idx: int) -> void:
	if not _is_working or _clicks_done >= _clicks_needed:
		return
	if idx == _quiz_answer:
		_register_hit(1, true)
		if _mg_hint:
			_mg_hint.text = "✓ Respuesta correcta"
		if _clicks_done < _clicks_needed:
			_next_quiz()
	else:
		_register_miss()
		if _mg_hint:
			_mg_hint.text = "✕ Incorrecto"
		if _clicks_done < _clicks_needed:
			_next_quiz()

func _build_tag_area(parent: VBoxContainer) -> void:
	var prompt := Label.new()
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt.add_theme_font_size_override("font_size", 22)
	prompt.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(prompt)
	_mg_buttons.append(prompt)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	for i in range(3):
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 40)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 20)
		var idx := i
		b.pressed.connect(func(): _on_tag_choice(idx))
		row.add_child(b)
		_mg_buttons.append(b)

func _next_tag() -> void:
	# Fotos del programa — algunas empujan el recuerdo de esa noche
	var items: Array = [
		{"img": "📷 Pasillo vacío, luz parpadeante", "tags": ["Interior", "Exterior", "Error"], "a": 0},
		{"img": "📷 Mano en el cristal empañado", "tags": ["Persona", "Objeto", "Fake"], "a": 0},
		{"img": "📷 Mapa con ruta hacia la frontera", "tags": ["Mapa", "Contrato", "Ruido"], "a": 0},
		{"img": "📷 Silueta junto a una puerta entreabierta", "tags": ["Persona", "Animal", "Error"], "a": 0},
		{"img": "📷 Recibo de un hotel de una sola noche", "tags": ["Documento", "Meme", "Código"], "a": 0},
		{"img": "📷 Pantalla con texto cortado a la mitad", "tags": ["Error", "Paisaje", "Retrato"], "a": 0},
		{"img": "📷 Foto borrosa de una pareja en un sofá", "tags": ["Persona", "Spam", "Arte"], "a": 0},
		{"img": "📷 Botella vacía sobre una mesa manchada", "tags": ["Objeto", "Persona", "Fake"], "a": 0},
	]
	var pick: Dictionary = items[randi() % items.size()]
	_tag_prompt = str(pick["img"])
	var tags: Array = pick["tags"].duplicate()
	var correct_label: String = str(tags[int(pick["a"])])
	for i in range(tags.size() - 1, 0, -1):
		var j := randi() % (i + 1)
		var tmp = tags[i]
		tags[i] = tags[j]
		tags[j] = tmp
	_tag_answer = tags.find(correct_label)
	if _mg_buttons.size() >= 4:
		(_mg_buttons[0] as Label).text = _tag_prompt
		for i in range(3):
			var b: Button = _mg_buttons[i + 1]
			if is_instance_valid(b):
				b.text = str(tags[i])
				b.disabled = false
	if _mg_hint:
		_mg_hint.text = "🏷 Elige la etiqueta correcta"

func _on_tag_choice(idx: int) -> void:
	if not _is_working or _clicks_done >= _clicks_needed:
		return
	if idx == _tag_answer:
		_register_hit(1, true)
		if _mg_hint:
			_mg_hint.text = "✓ Etiquetado OK"
		if _clicks_done < _clicks_needed:
			_next_tag()
	else:
		_register_miss()
		if _mg_hint:
			_mg_hint.text = "✕ Categoría incorrecta"
		if _clicks_done < _clicks_needed:
			_next_tag()

func _build_swipe_area(parent: VBoxContainer) -> void:
	_swipe_timer_bar = ProgressBar.new()
	_swipe_timer_bar.custom_minimum_size = Vector2(0, 12)
	_swipe_timer_bar.max_value = 1.0
	_swipe_timer_bar.value = 1.0
	var sf := StyleBoxFlat.new()
	sf.bg_color = Color(0.3, 0.7, 0.9)
	sf.set_corner_radius_all(3)
	_swipe_timer_bar.add_theme_stylebox_override("fill", sf)
	parent.add_child(_swipe_timer_bar)
	var prompt := Label.new()
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt.add_theme_font_size_override("font_size", 22)
	prompt.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(prompt)
	_mg_buttons.append(prompt)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var rej := Button.new()
	rej.text = "✕ RECHAZAR"
	rej.custom_minimum_size = Vector2(0, 44)
	rej.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rej.add_theme_font_size_override("font_size", 22)
	var rs := StyleBoxFlat.new()
	rs.bg_color = Color(0.7, 0.2, 0.2)
	rs.set_corner_radius_all(6)
	rej.add_theme_stylebox_override("normal", rs)
	rej.add_theme_color_override("font_color", Color.WHITE)
	rej.pressed.connect(func(): _on_swipe(0))
	row.add_child(rej)
	_mg_buttons.append(rej)
	var okb := Button.new()
	okb.text = "✓ APROBAR"
	okb.custom_minimum_size = Vector2(0, 44)
	okb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	okb.add_theme_font_size_override("font_size", 22)
	var os := StyleBoxFlat.new()
	os.bg_color = Color(0.2, 0.65, 0.3)
	os.set_corner_radius_all(6)
	okb.add_theme_stylebox_override("normal", os)
	okb.add_theme_color_override("font_color", Color.WHITE)
	okb.pressed.connect(func(): _on_swipe(1))
	row.add_child(okb)
	_mg_buttons.append(okb)

func _next_swipe() -> void:
	# Moderación del programa — contenido real vs basura / trampas
	var items: Array = [
		{"t": "Post: 'necesito dinero rápido sin papeles'", "a": 0},
		{"t": "Captura de un bug report legítimo", "a": 1},
		{"t": "Mensaje: 'ya sabemos dónde estás'", "a": 0},
		{"t": "Tutorial oficial del foro anónimo", "a": 1},
		{"t": "Enlace a 'prueba de vida' con foto borrosa", "a": 0},
		{"t": "Pregunta técnica bien formulada", "a": 1},
		{"t": "Spam: 'la policía no revisa esto'", "a": 0},
		{"t": "Reseña verificada del cliente 7A", "a": 1},
		{"t": "Foto de una puerta con sangre… o es óxido", "a": 0},
		{"t": "Log de sesión con horario válido", "a": 1},
	]
	var pick: Dictionary = items[randi() % items.size()]
	_swipe_prompt = str(pick["t"])
	_swipe_answer = int(pick["a"])
	_swipe_time = maxf(0.9, _swipe_window)
	if _mg_buttons.size() >= 1 and is_instance_valid(_mg_buttons[0]):
		(_mg_buttons[0] as Label).text = _swipe_prompt
	if _swipe_timer_bar:
		_swipe_timer_bar.max_value = _swipe_time
		_swipe_timer_bar.value = _swipe_time
	if _mg_hint:
		_mg_hint.text = "↔ Aprueba o rechaza  ·  %.1fs" % _swipe_time

func _process_swipe(delta: float) -> void:
	if _swipe_time <= 0.0:
		return
	_swipe_time -= delta
	if _swipe_timer_bar:
		_swipe_timer_bar.value = maxf(0.0, _swipe_time)
	if _swipe_time <= 0.0:
		_register_miss()
		if _mg_hint:
			_mg_hint.text = "⏱ Tiempo agotado"
		_swipe_window = maxf(0.95, _swipe_window - 0.08)
		if _clicks_done < _clicks_needed:
			_next_swipe()

func _on_swipe(side: int) -> void:
	if not _is_working or _clicks_done >= _clicks_needed or _swipe_time <= 0.0:
		return
	if side == _swipe_answer:
		var fast := _swipe_time > _swipe_window * 0.5
		_register_hit(1, fast)
		_swipe_window = maxf(0.95, _swipe_window - 0.05)
		if _mg_hint:
			_mg_hint.text = "✓ Filtrado OK" + (" ★" if fast else "")
		if _clicks_done < _clicks_needed:
			_next_swipe()
	else:
		_register_miss()
		if _mg_hint:
			_mg_hint.text = "✕ Decisión incorrecta"
		if _clicks_done < _clicks_needed:
			_next_swipe()

func _build_cleanse_area(parent: VBoxContainer) -> void:
	_cleanse_grid = GridContainer.new()
	_cleanse_grid.columns = 4
	_cleanse_grid.add_theme_constant_override("h_separation", 4)
	_cleanse_grid.add_theme_constant_override("v_separation", 4)
	parent.add_child(_cleanse_grid)

func _next_cleanse() -> void:
	_cleanse_cells.clear()
	_cleanse_found = 0
	_cleanse_needed = 3 + int(_clicks_done / 2)
	var total := 12
	for i in range(total):
		_cleanse_cells.append(false)
	var placed := 0
	while placed < _cleanse_needed:
		var idx := randi() % total
		if not _cleanse_cells[idx]:
			_cleanse_cells[idx] = true
			placed += 1
	if _cleanse_grid:
		for c in _cleanse_grid.get_children():
			c.queue_free()
		_mg_buttons.clear()
		for i in range(total):
			var b := Button.new()
			b.custom_minimum_size = Vector2(48, 40)
			b.add_theme_font_size_override("font_size", 16)
			if _cleanse_cells[i]:
				b.text = "██"
				var bs := StyleBoxFlat.new()
				bs.bg_color = Color(0.55, 0.15, 0.15)
				bs.set_corner_radius_all(4)
				b.add_theme_stylebox_override("normal", bs)
				b.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
			else:
				b.text = "OK"
				var bs2 := StyleBoxFlat.new()
				bs2.bg_color = Color(0.15, 0.25, 0.18)
				bs2.set_corner_radius_all(4)
				b.add_theme_stylebox_override("normal", bs2)
				b.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
			var idx2 := i
			b.pressed.connect(func(): _on_cleanse_cell(idx2))
			_cleanse_grid.add_child(b)
			_mg_buttons.append(b)
	if _mg_hint:
		_mg_hint.text = "🧹 Borra lo 'corrupto'… sin borrar lo que aún necesitas (%d)" % _cleanse_needed

func _on_cleanse_cell(idx: int) -> void:
	if not _is_working or _clicks_done >= _clicks_needed:
		return
	if idx < 0 or idx >= _cleanse_cells.size():
		return
	if _cleanse_cells[idx]:
		_cleanse_cells[idx] = false
		_cleanse_found += 1
		if idx < _mg_buttons.size() and is_instance_valid(_mg_buttons[idx]):
			var b: Button = _mg_buttons[idx]
			b.text = "✓"
			b.disabled = true
			b.modulate = Color(0.5, 1.0, 0.5)
		if _cleanse_found >= _cleanse_needed:
			_register_hit(1, _cleanse_needed >= 4)
			if _mg_hint:
				_mg_hint.text = "🧹 Datos limpios… o eso dice el programa"
			if _clicks_done < _clicks_needed:
				_next_cleanse()
		else:
			if _mg_hint:
				_mg_hint.text = "🧹 %d/%d corruptas" % [_cleanse_found, _cleanse_needed]
	else:
		_register_miss()
		if _mg_hint:
			_mg_hint.text = "✕ Esa celda estaba sana"
		if idx < _mg_buttons.size() and is_instance_valid(_mg_buttons[idx]):
			_mg_buttons[idx].modulate = Color(1, 0.5, 0.5)

func _build_scrape_area(parent: VBoxContainer) -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	parent.add_child(grid)
	for i in range(6):
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 36)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 18)
		var idx := i
		b.pressed.connect(func(): _on_scrape_pick(idx))
		grid.add_child(b)
		_mg_buttons.append(b)

func _next_scrape() -> void:
	var valid_pool := ["PKT_OK", "DATA_7A", "ROW_VALID", "JSON_OK", "CSV_CLEAN", "XML_OK"]
	var bait_pool := ["BAIT_99", "HONEYPOT", "TRAP", "FAKE_ROW", "SPOOF", "NULL_BOMB"]
	_scrape_is_valid.clear()
	_scrape_labels.clear()
	var valid_count := 2 + (randi() % 2)
	var indices := [0, 1, 2, 3, 4, 5]
	for i in range(indices.size() - 1, 0, -1):
		var j := randi() % (i + 1)
		var tmp = indices[i]
		indices[i] = indices[j]
		indices[j] = tmp
	for i in range(6):
		_scrape_is_valid.append(false)
		_scrape_labels.append("")
	for k in range(valid_count):
		_scrape_is_valid[indices[k]] = true
	for i in range(6):
		if _scrape_is_valid[i]:
			_scrape_labels[i] = valid_pool[randi() % valid_pool.size()]
		else:
			_scrape_labels[i] = bait_pool[randi() % bait_pool.size()]
	for i in range(mini(6, _mg_buttons.size())):
		var b: Button = _mg_buttons[i]
		if is_instance_valid(b):
			b.text = str(_scrape_labels[i])
			b.disabled = false
			b.modulate = Color.WHITE
	if _mg_hint:
		_mg_hint.text = "⛏ Solo lo válido. El cebo atrapa a quien huye (%d)" % valid_count

func _on_scrape_pick(idx: int) -> void:
	if not _is_working or _clicks_done >= _clicks_needed:
		return
	if idx < 0 or idx >= _scrape_is_valid.size():
		return
	if _scrape_is_valid[idx]:
		_scrape_is_valid[idx] = false
		if idx < _mg_buttons.size() and is_instance_valid(_mg_buttons[idx]):
			_mg_buttons[idx].disabled = true
			_mg_buttons[idx].text = "✓"
			_mg_buttons[idx].modulate = Color(0.5, 1, 0.5)
		var left := 0
		for v in _scrape_is_valid:
			if v:
				left += 1
		if left == 0:
			_register_hit(1, true)
			if _mg_hint:
				_mg_hint.text = "⛏ Lote extraído"
			if _clicks_done < _clicks_needed:
				_next_scrape()
		else:
			if _mg_hint:
				_mg_hint.text = "⛏ %d válidos restantes" % left
	else:
		_register_miss()
		if _mg_hint:
			_mg_hint.text = "✕ Cebo — alguien diseñó esto para gente como tú"
		if idx < _mg_buttons.size() and is_instance_valid(_mg_buttons[idx]):
			_mg_buttons[idx].modulate = Color(1, 0.3, 0.3)

func _build_proxy_area(parent: VBoxContainer) -> void:
	var prompt := Label.new()
	prompt.add_theme_font_size_override("font_size", 20)
	prompt.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(prompt)
	_mg_buttons.append(prompt)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	for i in range(4):
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 42)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 18)
		var idx := i
		b.pressed.connect(func(): _on_proxy_hop(idx))
		row.add_child(b)
		_mg_buttons.append(b)

func _next_proxy() -> void:
	var nodes := ["TOR-1", "VPN-A", "RELAY-X", "EXIT-9", "NODE-Ω", "CHAIN-3", "HOP-7", "MESH-2"]
	var length := 3 + (1 if _clicks_done > 1 else 0)
	_proxy_path.clear()
	var used: Array = []
	while _proxy_path.size() < length:
		var n: String = nodes[randi() % nodes.size()]
		if n not in used:
			used.append(n)
			_proxy_path.append(n)
	_proxy_player_idx = 0
	_proxy_options = _proxy_path.duplicate()
	while _proxy_options.size() < 4:
		var n2: String = nodes[randi() % nodes.size()]
		if n2 not in _proxy_options:
			_proxy_options.append(n2)
	for i in range(_proxy_options.size() - 1, 0, -1):
		var j := randi() % (i + 1)
		var tmp = _proxy_options[i]
		_proxy_options[i] = _proxy_options[j]
		_proxy_options[j] = tmp
	if _mg_buttons.size() >= 5:
		(_mg_buttons[0] as Label).text = "Ruta: " + " → ".join(_proxy_path)
		for i in range(4):
			var b: Button = _mg_buttons[i + 1]
			if is_instance_valid(b):
				b.text = str(_proxy_options[i])
				b.disabled = false
				b.modulate = Color.WHITE
	if _mg_hint:
		_mg_hint.text = "🔀 Enruta tu rastro EN ORDEN. Mal hop = huella (%d)" % length

func _on_proxy_hop(idx: int) -> void:
	if not _is_working or _clicks_done >= _clicks_needed:
		return
	if _proxy_player_idx >= _proxy_path.size():
		return
	if idx < 0 or idx >= _proxy_options.size():
		return
	var chosen: String = str(_proxy_options[idx])
	var expected: String = str(_proxy_path[_proxy_player_idx])
	if chosen == expected:
		_proxy_player_idx += 1
		if idx + 1 < _mg_buttons.size() and is_instance_valid(_mg_buttons[idx + 1]):
			_mg_buttons[idx + 1].modulate = Color(0.5, 1, 0.5)
			_mg_buttons[idx + 1].disabled = true
		if _proxy_player_idx >= _proxy_path.size():
			_register_hit(1, _proxy_path.size() >= 4)
			if _mg_hint:
				_mg_hint.text = "🔀 Rastro limpio… por ahora"
			if _clicks_done < _clicks_needed:
				_next_proxy()
		else:
			if _mg_hint:
				_mg_hint.text = "🔀 Hop %d/%d" % [_proxy_player_idx, _proxy_path.size()]
	else:
		_register_miss()
		_proxy_player_idx = 0
		if _mg_hint:
			_mg_hint.text = "✕ Salto incorrecto — dejaste huella. Otra vez."
		_next_proxy()

func _build_mine_area(parent: VBoxContainer) -> void:
	_mine_canvas = Control.new()
	_mine_canvas.custom_minimum_size = Vector2(0, 36)
	_mine_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mine_canvas.draw.connect(_draw_mine_bar)
	parent.add_child(_mine_canvas)

func _draw_mine_bar() -> void:
	if _mine_canvas == null:
		return
	var r := Rect2(Vector2.ZERO, _mine_canvas.size)
	if r.size.x < 4:
		return
	_mine_canvas.draw_rect(r, Color(0.10, 0.12, 0.16))
	var zx := r.size.x * _mine_spike_min
	var zw := r.size.x * (_mine_spike_max - _mine_spike_min)
	_mine_canvas.draw_rect(Rect2(zx, 3, zw, r.size.y - 6), Color(0.95, 0.2, 0.15, 0.9))
	var vx := r.size.x * _mine_value
	_mine_canvas.draw_rect(Rect2(0, 0, vx, r.size.y), Color(0.3, 0.7, 1.0, 0.4))
	_mine_canvas.draw_rect(Rect2(vx - 2, 0, 4, r.size.y), Color(1, 1, 1))

func _process_mine(delta: float) -> void:
	if not _mine_active:
		if _mine_canvas:
			_mine_canvas.queue_redraw()
		return
	_mine_value = minf(1.0, _mine_value + delta * 0.42)
	if click_area:
		if _mine_value >= _mine_spike_min and _mine_value <= _mine_spike_max:
			click_area.modulate = Color(1.0, 0.4, 0.3)
			click_area.text = "★ PICO — SUELTA YA"
		elif _mine_value > _mine_spike_max:
			click_area.modulate = Color(1.0, 0.2, 0.2)
			click_area.text = "🔥 DEMASIADO TARDE"
		else:
			click_area.modulate = Color(0.6, 0.85, 1.0)
			click_area.text = "MANTÉN EL RITMO…"
	if _mine_canvas:
		_mine_canvas.queue_redraw()

func _build_shadow_area(parent: VBoxContainer) -> void:
	_shadow_canvas = Control.new()
	_shadow_canvas.custom_minimum_size = Vector2(0, 36)
	_shadow_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shadow_canvas.draw.connect(_draw_shadow_bar)
	parent.add_child(_shadow_canvas)

func _draw_shadow_bar() -> void:
	if _shadow_canvas == null:
		return
	var r := Rect2(Vector2.ZERO, _shadow_canvas.size)
	if r.size.x < 4:
		return
	_shadow_canvas.draw_rect(r, Color(0.75, 0.78, 0.82))
	var zx := r.size.x * _shadow_dark_min
	var zw := r.size.x * (_shadow_dark_max - _shadow_dark_min)
	_shadow_canvas.draw_rect(Rect2(zx, 0, zw, r.size.y), Color(0.08, 0.08, 0.12))
	var mx := r.size.x * _shadow_pos
	_shadow_canvas.draw_rect(Rect2(mx - 4, 0, 8, r.size.y), Color(0.95, 0.85, 0.2))
	_shadow_canvas.draw_rect(Rect2(mx - 1.5, 0, 3, r.size.y), Color(1, 1, 1))

func _process_shadow(delta: float) -> void:
	_shadow_pos += _shadow_dir * _shadow_speed * delta
	if _shadow_pos >= 1.0:
		_shadow_pos = 1.0
		_shadow_dir = -1.0
	elif _shadow_pos <= 0.0:
		_shadow_pos = 0.0
		_shadow_dir = 1.0
	if click_area:
		if _shadow_pos >= _shadow_dark_min and _shadow_pos <= _shadow_dark_max:
			click_area.modulate = Color(0.6, 0.6, 0.9)
			click_area.text = "🌑 NADIE MIRA — AHORA"
		else:
			click_area.modulate = Color(1.0, 0.85, 0.5)
			click_area.text = "⚠ TE PUEDEN VER — espera"
	if _shadow_canvas:
		_shadow_canvas.queue_redraw()

func _try_shadow_hit() -> void:
	if not _is_working or _clicks_done >= _clicks_needed:
		return
	if _shadow_pos >= _shadow_dark_min and _shadow_pos <= _shadow_dark_max:
		var mid := (_shadow_dark_min + _shadow_dark_max) * 0.5
		var perfect := absf(_shadow_pos - mid) < 0.04
		_register_hit(1, perfect)
		if _mg_hint:
			_mg_hint.text = "🌑 Mensaje enviado. Nadie te vio." + (" ★" if perfect else "")
		_shadow_dark_min = 0.20 + randf() * 0.25
		_shadow_dark_max = minf(0.78, _shadow_dark_min + 0.14 + randf() * 0.04)
		_shadow_speed = minf(1.8, _shadow_speed + 0.06)
	else:
		_register_miss()
		if _mg_hint:
			_mg_hint.text = "✕ Alguien pudo verte. El contacto se quema."

func _build_zeroday_area(parent: VBoxContainer) -> void:
	_zeroday_timer_bar = ProgressBar.new()
	_zeroday_timer_bar.custom_minimum_size = Vector2(0, 12)
	_zeroday_timer_bar.max_value = 1.0
	_zeroday_timer_bar.value = 1.0
	var zf := StyleBoxFlat.new()
	zf.bg_color = Color(0.9, 0.15, 0.2)
	zf.set_corner_radius_all(3)
	_zeroday_timer_bar.add_theme_stylebox_override("fill", zf)
	parent.add_child(_zeroday_timer_bar)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	parent.add_child(grid)
	_zeroday_cells.clear()
	for i in range(16):
		var b := Button.new()
		b.custom_minimum_size = Vector2(42, 36)
		b.add_theme_font_size_override("font_size", 14)
		b.text = "·"
		var idx := i
		b.pressed.connect(func(): _on_zeroday_cell(idx))
		grid.add_child(b)
		_zeroday_cells.append(b)
		_mg_buttons.append(b)

func _next_zeroday() -> void:
	_zeroday_vuln = randi() % 16
	_zeroday_time = maxf(1.2, _zeroday_window)
	for i in range(_zeroday_cells.size()):
		var b: Button = _zeroday_cells[i]
		if not is_instance_valid(b):
			continue
		b.disabled = false
		b.modulate = Color.WHITE
		if i == _zeroday_vuln:
			b.text = "⚠"
			var bs := StyleBoxFlat.new()
			bs.bg_color = Color(0.35, 0.12, 0.12)
			bs.set_corner_radius_all(3)
			b.add_theme_stylebox_override("normal", bs)
			b.add_theme_color_override("font_color", Color(1.0, 0.55, 0.3))
		else:
			b.text = "·"
			var bs2 := StyleBoxFlat.new()
			bs2.bg_color = Color(0.14, 0.16, 0.20)
			bs2.set_corner_radius_all(3)
			b.add_theme_stylebox_override("normal", bs2)
			b.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
	if _zeroday_timer_bar:
		_zeroday_timer_bar.max_value = _zeroday_time
		_zeroday_timer_bar.value = _zeroday_time
	if _mg_hint:
		_mg_hint.text = "💀 Encuentra el fallo antes de que se cierre  ·  %.1fs" % _zeroday_time

func _process_zeroday(delta: float) -> void:
	if _zeroday_time <= 0.0:
		return
	_zeroday_time -= delta
	if _zeroday_timer_bar:
		_zeroday_timer_bar.value = maxf(0.0, _zeroday_time)
	if _zeroday_time <= 0.0:
		_register_miss()
		if _mg_hint:
			_mg_hint.text = "⏱ La ventana se cerró. Como tus días."
		_zeroday_window = maxf(1.4, _zeroday_window - 0.15)
		if _clicks_done < _clicks_needed:
			_next_zeroday()

func _on_zeroday_cell(idx: int) -> void:
	if not _is_working or _clicks_done >= _clicks_needed or _zeroday_time <= 0.0:
		return
	if idx == _zeroday_vuln:
		var fast := _zeroday_time > _zeroday_window * 0.4
		_register_hit(1, fast)
		_zeroday_window = maxf(1.3, _zeroday_window - 0.18)
		if _mg_hint:
			_mg_hint.text = "💀 Fallo reportado. El reloj sigue." + (" ★" if fast else "")
		if _clicks_done < _clicks_needed:
			_next_zeroday()
	else:
		_register_miss()
		if _mg_hint:
			_mg_hint.text = "✕ Celda limpia — perdiste tiempo"
		if idx < _zeroday_cells.size() and is_instance_valid(_zeroday_cells[idx]):
			_zeroday_cells[idx].modulate = Color(1, 0.4, 0.4)
			_zeroday_cells[idx].disabled = true

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
		"mirror":
			if _mirror_showing:
				return
			var mmap := {
				KEY_1: 0, KEY_2: 1, KEY_3: 2, KEY_4: 3,
				KEY_KP_1: 0, KEY_KP_2: 1, KEY_KP_3: 2, KEY_KP_4: 3
			}
			if mmap.has(code):
				_on_mirror_press(int(mmap[code]))
				get_viewport().set_input_as_handled()
		"signal":
			var smap := {
				KEY_1: 0, KEY_2: 1, KEY_3: 2, KEY_4: 3,
				KEY_KP_1: 0, KEY_KP_2: 1, KEY_KP_3: 2, KEY_KP_4: 3
			}
			if smap.has(code):
				_on_signal_choice(int(smap[code]))
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
		"quiz":
			var qmap := {
				KEY_1: 0, KEY_2: 1, KEY_3: 2, KEY_4: 3,
				KEY_KP_1: 0, KEY_KP_2: 1, KEY_KP_3: 2, KEY_KP_4: 3
			}
			if qmap.has(code):
				_on_quiz_choice(int(qmap[code]))
				get_viewport().set_input_as_handled()
		"swipe":
			if code in [KEY_LEFT, KEY_A]:
				_on_swipe(0)
				get_viewport().set_input_as_handled()
			elif code in [KEY_RIGHT, KEY_D]:
				_on_swipe(1)
				get_viewport().set_input_as_handled()
		"proxy":
			var pmap := {
				KEY_1: 0, KEY_2: 1, KEY_3: 2, KEY_4: 3,
				KEY_KP_1: 0, KEY_KP_2: 1, KEY_KP_3: 2, KEY_KP_4: 3
			}
			if pmap.has(code):
				_on_proxy_hop(int(pmap[code]))
				get_viewport().set_input_as_handled()
		"shadow":
			if code in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
				_try_shadow_hit()
				get_viewport().set_input_as_handled()
		"rapid", "click":
			if code == KEY_SPACE:
				_on_work_click()
				get_viewport().set_input_as_handled()

## [Tanda 9] Si la app se cierra a mitad de trabajo, no bloquear los eventos.
func _exit_tree() -> void:
	GameManager.is_job_running = false
