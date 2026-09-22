extends Control
## WorkApp — UI de Trabajo (escena separada)  [TANDA 8: pago dual]

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

func _ready() -> void:
	_style()
	_ensure_payment_ui()
	if job_list and not job_list.item_selected.is_connected(_on_job_selected):
		job_list.item_selected.connect(_on_job_selected)
	if start_job_button and not start_job_button.pressed.is_connected(_on_start_job):
		start_job_button.pressed.connect(_on_start_job)
	if click_area and not click_area.pressed.is_connected(_on_work_click):
		click_area.pressed.connect(_on_work_click)
	# Sonidos de UI se añaden en los handlers
	if click_area:
		click_area.visible = false
	GameManager.job_level_changed.connect(func(_l): refresh())
	GameManager.jobs_completed_changed.connect(func(_c): refresh())
	TimeManager.work_hours_changed.connect(func(_w): refresh())
	if GameManager.has_signal("payment_method_changed"):
		GameManager.payment_method_changed.connect(func(_m): _sync_payment_ui())
	refresh()

func _ensure_payment_ui() -> void:
	if _payment_option != null and is_instance_valid(_payment_option):
		return
	var row := HBoxContainer.new()
	row.name = "PaymentRow"
	var lbl := Label.new()
	lbl.text = "Cobro: "
	lbl.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15))
	lbl.add_theme_font_size_override("font_size", 16)
	row.add_child(lbl)
	_payment_option = OptionButton.new()
	_payment_option.add_item("Online (rápido, +sospecha)", 0)
	_payment_option.add_item("Efectivo (sin sospecha)", 1)
	_payment_option.custom_minimum_size = Vector2(220, 28)
	_payment_option.item_selected.connect(_on_payment_selected)
	row.add_child(_payment_option)
	# Insertar cerca del fondo
	var root_node = $Root
	if root_node:
		root_node.add_child(row)
		# Mover antes del BottomRow si existe
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
			lbl.add_theme_font_size_override("font_size", 20)
	if header:
		header.add_theme_color_override("font_color", Color(0.0, 0.0, 0.5))
		header.add_theme_font_size_override("font_size", 26)
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
		header.text = "Centro de Trabajo  |  Nivel %d" % GameManager.job_level
	if level_progress:
		var next_req: int = WorkSystem.get_next_level_requirement()
		if next_req < 0:
			level_progress.text = "Nivel máximo  •  Trabajos: %d" % GameManager.jobs_completed
		else:
			level_progress.text = "Progreso: %d / %d para Nivel %d" % [
				GameManager.jobs_completed, next_req, GameManager.job_level + 1
			]
	if work_status:
		if TimeManager.is_work_time:
			work_status.text = "HORARIO LABORAL (01:00–05:00) — Trabaja ahora"
			work_status.add_theme_color_override("font_color", Color(0.0, 0.45, 0.05))
		else:
			work_status.text = "Fuera de horario — apaga el PC para avanzar al día siguiente"
			work_status.add_theme_color_override("font_color", Color(0.7, 0.15, 0.05))
	if job_list:
		job_list.clear()
		var available: Array = WorkSystem.get_available_jobs()
		for job in available:
			var suffix: String = ""
			if float(job.get("sanity_cost", 0)) > 0:
				suffix = " ⚠"
			job_list.add_item("Lv%d  %s  ($%d-$%d)%s" % [
				int(job["level"]), str(job["name"]), int(job["min_pay"]), int(job["max_pay"]), suffix
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
			job_details.text = "Selecciona un trabajo"
		return
	var job: Dictionary = available[idx]
	if job_details:
		var extra: String = ""
		var sc: float = float(job.get("sanity_cost", 0))
		if sc > 0:
			extra = "\n⚠ Coste de cordura: ~%.1f" % sc
		if bool(job.get("can_generate_clue", false)):
			extra += "\n🔍 Puede generar pista"
		job_details.text = "%s\n\n%s\n\nPago: $%d - $%d\nDuración: ~%ds\nClicks: %d%s" % [
			str(job["name"]), str(job.get("description", "")),
			int(job["min_pay"]), int(job["max_pay"]),
			int(job.get("duration", 10)), int(job.get("clicks_required", 5)),
			extra
		]

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
	if start_job_button:
		start_job_button.disabled = true
		start_job_button.text = "Trabajando..."
	if click_area:
		click_area.visible = true
		click_area.disabled = false
		click_area.text = "CLICK 0/%d" % _clicks_needed
	if reward_label:
		reward_label.text = ""
	if job_list:
		job_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var duration: float = float(_current_job.get("duration", 10))
	# Optimizador de tareas reduce duración
	if UpgradeSystem and UpgradeSystem.has_method("get_cooldown_mult"):
		duration *= UpgradeSystem.get_cooldown_mult()
	var elapsed: float = 0.0
	if timer_bar:
		timer_bar.value = 0
		timer_bar.max_value = duration
	while elapsed < duration and _is_working and GameManager.is_pc_on:
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1
		if timer_bar:
			timer_bar.value = elapsed
		if timer_label:
			timer_label.text = "Tiempo: %.1fs" % maxf(0.0, duration - elapsed)
		GameManager.spend_battery(0.015)
	_finish_job()

func _on_work_click() -> void:
	if not _is_working:
		return
	if SoundSystem:
		SoundSystem.play_click()
	_clicks_done += 1
	if click_area:
		click_area.text = "CLICK %d/%d" % [_clicks_done, _clicks_needed]
		click_area.pivot_offset = click_area.size * 0.5
		var tw := create_tween()
		tw.tween_property(click_area, "scale", Vector2(0.94, 0.94), 0.04)
		tw.tween_property(click_area, "scale", Vector2.ONE, 0.08)
		if is_instance_valid(VFXSystem):
			VFXSystem.spawn_sparkles(click_area.global_position + click_area.size * 0.5, 3)
		if _clicks_done >= _clicks_needed:
			click_area.text = "¡Listo!"
			click_area.disabled = true
			if is_instance_valid(VFXSystem):
				VFXSystem.spawn_sparkles(click_area.global_position + click_area.size * 0.5, 10)

func _finish_job() -> void:
	if _current_job.is_empty():
		_is_working = false
		return
	var click_ratio: float = clampf(float(_clicks_done) / float(maxi(1, _clicks_needed)), 0.4, 1.0)
	var base_pay: float = randf_range(float(_current_job["min_pay"]), float(_current_job["max_pay"]))
	var final_pay: float = base_pay * click_ratio
	GameManager.complete_job(final_pay, _current_job)
	if reward_label:
		var cpu_mult: float = UpgradeSystem.get_pay_multiplier()
		var method_txt: String = "Online" if GameManager.payment_method == "online" else "Efectivo"
		reward_label.text = "+$%.0f  (clicks x%.0f%%, CPU x%.2f) [%s]" % [
			final_pay * cpu_mult, click_ratio * 100.0, cpu_mult, method_txt
		]
		reward_label.add_theme_color_override("font_color", Color(0.05, 0.55, 0.15))
		reward_label.pivot_offset = reward_label.size * 0.5
		var tw := create_tween()
		tw.tween_property(reward_label, "scale", Vector2(1.12, 1.12), 0.1)
		tw.tween_property(reward_label, "scale", Vector2.ONE, 0.15)
	_is_working = false
	_current_job = {}
	if start_job_button:
		start_job_button.text = ">  Empezar trabajo"
		start_job_button.disabled = not TimeManager.is_work_time
	if click_area:
		click_area.visible = false
	if timer_label:
		timer_label.text = ""
	if job_list:
		job_list.mouse_filter = Control.MOUSE_FILTER_STOP
	refresh()
