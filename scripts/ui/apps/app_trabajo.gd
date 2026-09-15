extends Control
## App Trabajo — escena separada  [TANDA 8: pago dual + más trabajos]

var _payment_option: OptionButton = null

func _ready() -> void:
	_style()
	_ensure_payment_ui()
	$JobList.item_selected.connect(_on_job_selected)
	$StartJobButton.pressed.connect(_on_start)
	$ClickArea.pressed.connect(_on_click)
	set_meta("selected_job_idx", 0)
	set_meta("is_working", false)
	set_meta("clicks_done", 0)
	set_meta("clicks_needed", 0)
	_refresh()
	if not GameManager.job_level_changed.is_connected(_on_lvl):
		GameManager.job_level_changed.connect(_on_lvl)
	if not GameManager.jobs_completed_changed.is_connected(_on_jobs):
		GameManager.jobs_completed_changed.connect(_on_jobs)
	if not TimeManager.work_hours_changed.is_connected(_on_hours):
		TimeManager.work_hours_changed.connect(_on_hours)
	if GameManager.has_signal("payment_method_changed") and not GameManager.payment_method_changed.is_connected(_on_payment_changed):
		GameManager.payment_method_changed.connect(_on_payment_changed)

func _ensure_payment_ui() -> void:
	if _payment_option != null and is_instance_valid(_payment_option):
		return
	var label := Label.new()
	label.name = "PaymentLabel"
	label.text = "Cobro:"
	label.position = Vector2(8, 350)
	label.size = Vector2(60, 24)
	label.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15))
	add_child(label)

	_payment_option = OptionButton.new()
	_payment_option.name = "PaymentMethod"
	_payment_option.position = Vector2(70, 348)
	_payment_option.size = Vector2(200, 28)
	_payment_option.add_item("Online (rápido, +sospecha)", 0)
	_payment_option.add_item("Efectivo (sin sospecha)", 1)
	_payment_option.item_selected.connect(_on_payment_selected)
	add_child(_payment_option)
	_sync_payment_ui()

func _sync_payment_ui() -> void:
	if _payment_option == null:
		return
	var idx: int = 0 if GameManager.payment_method == "online" else 1
	_payment_option.select(idx)

func _on_payment_selected(idx: int) -> void:
	var method: String = "online" if idx == 0 else "cash"
	GameManager.set_payment_method(method)

func _on_payment_changed(_m: String) -> void:
	_sync_payment_ui()

func _style() -> void:
	$Header.add_theme_color_override("font_color", Color(0, 0, 0.5))
	$Header.add_theme_font_size_override("font_size", 18)
	$LevelProgress.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
	$JobDetails.add_theme_color_override("font_color", Color(0.13, 0.13, 0.13))
	$RewardLabel.add_theme_color_override("font_color", Color(0, 0.4, 0))
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.141, 0.369, 0.863)
	bs.set_corner_radius_all(5)
	$StartJobButton.add_theme_stylebox_override("normal", bs)
	$StartJobButton.add_theme_color_override("font_color", Color.WHITE)
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0.902, 0.494, 0.133)
	cs.set_corner_radius_all(5)
	$ClickArea.add_theme_stylebox_override("normal", cs)
	$ClickArea.add_theme_color_override("font_color", Color.WHITE)

func _on_lvl(_l: int) -> void: _refresh()
func _on_jobs(_c: int) -> void: _refresh()
func _on_hours(_w: bool) -> void: _refresh()

func _refresh() -> void:
	if get_meta("is_working", false):
		return
	$Header.text = "Centro de Trabajo  |  Nivel %d" % GameManager.job_level
	var next_req: int = WorkSystem.get_next_level_requirement()
	if next_req < 0:
		$LevelProgress.text = "Nivel máximo  •  Completados: %d" % GameManager.jobs_completed
	else:
		$LevelProgress.text = "Progreso: %d / %d para Nivel %d" % [
			GameManager.jobs_completed, next_req, GameManager.job_level + 1
		]
	if TimeManager.is_work_time:
		$WorkStatus.text = "HORARIO LABORAL (01:00 - 05:00)  —  Puedes trabajar"
		$WorkStatus.add_theme_color_override("font_color", Color(0, 0.4, 0))
	else:
		$WorkStatus.text = "Fuera de horario — solo 01:00-05:00"
		$WorkStatus.add_theme_color_override("font_color", Color(0.55, 0, 0))
	var list: ItemList = $JobList
	list.clear()
	var available: Array = WorkSystem.get_available_jobs()
	for job in available:
		var suffix: String = ""
		if float(job.get("sanity_cost", 0)) > 0:
			suffix = " ⚠"
		list.add_item("Lv%d  %s  ($%d-$%d)%s" % [
			int(job["level"]), str(job["name"]), int(job["min_pay"]), int(job["max_pay"]), suffix
		])
	if available.size() > 0:
		var sel: int = clampi(int(get_meta("selected_job_idx", 0)), 0, available.size() - 1)
		list.select(sel)
		_on_job_selected(sel)
	$StartJobButton.disabled = not TimeManager.is_work_time
	$StartJobButton.text = ">  Empezar trabajo"
	$ClickArea.visible = false
	_sync_payment_ui()

func _on_job_selected(idx: int) -> void:
	set_meta("selected_job_idx", idx)
	var available: Array = WorkSystem.get_available_jobs()
	if idx < 0 or idx >= available.size():
		$JobDetails.text = "Selecciona un trabajo"
		return
	var job: Dictionary = available[idx]
	var extra: String = ""
	var sc: float = float(job.get("sanity_cost", 0))
	if sc > 0:
		extra = "\n⚠ Coste de cordura: ~%.1f" % sc
	if bool(job.get("can_generate_clue", false)):
		extra += "\n🔍 Puede generar pista"
	$JobDetails.text = "%s\n\n%s\n\nPago: $%d - $%d\nDuración: ~%ds\nClicks: %d%s" % [
		str(job["name"]), str(job.get("description", "")),
		int(job["min_pay"]), int(job["max_pay"]),
		int(job.get("duration", 10)), int(job.get("clicks_required", 5)),
		extra
	]

func _on_start() -> void:
	if get_meta("is_working", false) or not TimeManager.is_work_time:
		return
	var idx: int = int(get_meta("selected_job_idx", -1))
	var available: Array = WorkSystem.get_available_jobs()
	if idx < 0 or idx >= available.size():
		return
	var job: Dictionary = available[idx]
	# Respetar requires_internet
	if job.has("requires_internet"):
		var need: int = int(job["requires_internet"])
		if UpgradeSystem.get_level("internet") < need:
			$RewardLabel.text = "Necesitas Internet nivel %d" % need
			return
	set_meta("is_working", true)
	set_meta("clicks_done", 0)
	set_meta("clicks_needed", int(job.get("clicks_required", 5)))
	set_meta("current_job", job)
	$StartJobButton.disabled = true
	$StartJobButton.text = "Trabajando..."
	$ClickArea.visible = true
	$ClickArea.disabled = false
	$ClickArea.text = "CLICK 0/%d" % int(get_meta("clicks_needed"))
	$RewardLabel.text = ""
	$JobList.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var duration: float = float(job.get("duration", 10))
	# Optimizador reduce el tiempo efectivo
	if UpgradeSystem and UpgradeSystem.has_method("get_cooldown_mult"):
		duration *= UpgradeSystem.get_cooldown_mult()
	var elapsed: float = 0.0
	$TimerBar.max_value = duration
	$TimerBar.value = 0
	while elapsed < duration and get_meta("is_working", false) and GameManager.is_pc_on:
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1
		$TimerBar.value = elapsed
		$TimerLabel.text = "Tiempo: %.1fs" % maxf(0.0, duration - elapsed)
		GameManager.spend_battery(0.015)
	_finish()

func _on_click() -> void:
	if not get_meta("is_working", false):
		return
	var done: int = int(get_meta("clicks_done", 0)) + 1
	var needed: int = int(get_meta("clicks_needed", 5))
	set_meta("clicks_done", done)
	$ClickArea.text = "CLICK %d/%d" % [done, needed]
	if done >= needed:
		$ClickArea.text = "Completado!"
		$ClickArea.disabled = true

func _finish() -> void:
	var job: Dictionary = get_meta("current_job", {})
	if job.is_empty():
		set_meta("is_working", false)
		return
	var clicks_done: int = int(get_meta("clicks_done", 0))
	var clicks_needed: int = int(get_meta("clicks_needed", 5))
	var click_ratio: float = clampf(float(clicks_done) / float(maxi(1, clicks_needed)), 0.4, 1.0)
	var base_pay: float = randf_range(float(job["min_pay"]), float(job["max_pay"]))
	var final_pay: float = base_pay * click_ratio
	GameManager.complete_job(final_pay, job)
	var cpu_mult: float = UpgradeSystem.get_pay_multiplier()
	var method_txt: String = "Online" if GameManager.payment_method == "online" else "Efectivo"
	$RewardLabel.text = "+$%.0f  (clicks x%.0f%%, CPU x%.2f) [%s]" % [
		final_pay * cpu_mult, click_ratio * 100.0, cpu_mult, method_txt
	]
	set_meta("is_working", false)
	$JobList.mouse_filter = Control.MOUSE_FILTER_STOP
	_refresh()
