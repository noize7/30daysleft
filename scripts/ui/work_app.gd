extends Control
## WorkApp — Contenido de Trabajo (escena separada)

@onready var header: Label = $Header
@onready var level_progress: Label = $LevelProgress
@onready var work_status: Label = $WorkStatus
@onready var job_list: ItemList = $JobList
@onready var job_details: Label = $JobDetails
@onready var timer_bar: ProgressBar = $TimerBar
@onready var timer_label: Label = $TimerLabel
@onready var click_area: Button = $ClickArea
@onready var start_job_button: Button = $StartJobButton
@onready var reward_label: Label = $RewardLabel

var _selected_idx: int = 0
var _is_working: bool = false
var _clicks_done: int = 0
var _clicks_needed: int = 0
var _current_job: Dictionary = {}

func _ready() -> void:
	job_list.item_selected.connect(_on_job_selected)
	start_job_button.pressed.connect(_on_start_job)
	click_area.pressed.connect(_on_work_click)
	click_area.visible = false
	_style()
	refresh()
	if not GameManager.job_level_changed.is_connected(_on_refresh_sig):
		GameManager.job_level_changed.connect(_on_refresh_sig)
	if not GameManager.jobs_completed_changed.is_connected(_on_refresh_sig):
		GameManager.jobs_completed_changed.connect(_on_refresh_sig)
	if not TimeManager.work_hours_changed.is_connected(_on_work_hours):
		TimeManager.work_hours_changed.connect(_on_work_hours)

func _style() -> void:
	header.add_theme_color_override("font_color", Color(0.0, 0.0, 0.5))
	header.add_theme_font_size_override("font_size", 20)
	level_progress.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
	level_progress.add_theme_font_size_override("font_size", 15)
	work_status.add_theme_font_size_override("font_size", 15)
	job_details.add_theme_color_override("font_color", Color(0.13, 0.13, 0.13))
	job_details.add_theme_font_size_override("font_size", 15)
	reward_label.add_theme_color_override("font_color", Color(0.0, 0.39, 0.0))
	reward_label.add_theme_font_size_override("font_size", 16)
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.141, 0.369, 0.863)
	bs.set_corner_radius_all(5)
	start_job_button.add_theme_stylebox_override("normal", bs)
	start_job_button.add_theme_color_override("font_color", Color.WHITE)
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0.902, 0.494, 0.133)
	cs.set_corner_radius_all(5)
	click_area.add_theme_stylebox_override("normal", cs)
	click_area.add_theme_color_override("font_color", Color.WHITE)
	var tfill := StyleBoxFlat.new()
	tfill.bg_color = Color(0.141, 0.369, 0.863)
	tfill.set_corner_radius_all(3)
	timer_bar.add_theme_stylebox_override("fill", tfill)

func _on_refresh_sig(_v = null) -> void:
	refresh()

func _on_work_hours(_is_work: bool) -> void:
	refresh()

func refresh() -> void:
	header.text = "Centro de Trabajo  |  Nivel %d" % GameManager.job_level
	var next_req: int = WorkSystem.get_next_level_requirement()
	if next_req < 0:
		level_progress.text = "Nivel maximo  •  Trabajos: %d" % GameManager.jobs_completed
	else:
		level_progress.text = "Progreso: %d / %d para Nivel %d" % [
			GameManager.jobs_completed, next_req, GameManager.job_level + 1
		]
	if TimeManager.is_work_time:
		work_status.text = "HORARIO LABORAL (01:00 - 05:00)  —  Puedes trabajar"
		work_status.add_theme_color_override("font_color", Color(0.0, 0.39, 0.0))
	else:
		work_status.text = "Fuera de horario — solo 01:00-05:00"
		work_status.add_theme_color_override("font_color", Color(0.55, 0.0, 0.0))
	job_list.clear()
	var available: Array = WorkSystem.get_available_jobs()
	for job in available:
		job_list.add_item("Lv%d  %s  ($%d-$%d)" % [
			int(job["level"]), str(job["name"]), int(job["min_pay"]), int(job["max_pay"])
		])
	if available.size() > 0:
		_selected_idx = clampi(_selected_idx, 0, available.size() - 1)
		job_list.select(_selected_idx)
		_on_job_selected(_selected_idx)
	start_job_button.disabled = _is_working or not TimeManager.is_work_time

func _on_job_selected(idx: int) -> void:
	_selected_idx = idx
	var available: Array = WorkSystem.get_available_jobs()
	if idx < 0 or idx >= available.size():
		job_details.text = "Selecciona un trabajo"
		return
	var job: Dictionary = available[idx]
	job_details.text = "%s\n\n%s\n\nPago: $%d - $%d\nDuracion: ~%ds\nClicks: %d" % [
		str(job["name"]), str(job.get("description", "")),
		int(job["min_pay"]), int(job["max_pay"]),
		int(job.get("duration", 10)), int(job.get("clicks_required", 5))
	]

func _on_start_job() -> void:
	if _is_working or not TimeManager.is_work_time:
		return
	var available: Array = WorkSystem.get_available_jobs()
	if _selected_idx < 0 or _selected_idx >= available.size():
		return
	_current_job = available[_selected_idx]
	_is_working = true
	_clicks_done = 0
	_clicks_needed = int(_current_job.get("clicks_required", 5))
	start_job_button.disabled = true
	start_job_button.text = "Trabajando..."
	click_area.visible = true
	click_area.disabled = false
	click_area.text = "CLICK 0/%d" % _clicks_needed
	reward_label.text = ""
	job_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var duration: float = float(_current_job.get("duration", 10))
	var elapsed: float = 0.0
	timer_bar.max_value = duration
	timer_bar.value = 0
	while elapsed < duration and _is_working and GameManager.is_pc_on:
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1
		timer_bar.value = elapsed
		timer_label.text = "Tiempo: %.1fs" % maxf(0.0, duration - elapsed)
		GameManager.spend_battery(0.015)
	_finish_job()

func _on_work_click() -> void:
	if not _is_working:
		return
	_clicks_done += 1
	click_area.text = "CLICK %d/%d" % [_clicks_done, _clicks_needed]
	if _clicks_done >= _clicks_needed:
		click_area.text = "Completado!"
		click_area.disabled = true

func _finish_job() -> void:
	if _current_job.is_empty():
		_is_working = false
		return
	var ratio: float = clampf(float(_clicks_done) / float(maxi(1, _clicks_needed)), 0.4, 1.0)
	var base_pay: float = randf_range(float(_current_job["min_pay"]), float(_current_job["max_pay"]))
	var final_pay: float = base_pay * ratio
	GameManager.complete_job(final_pay)
	var cpu_mult: float = UpgradeSystem.get_pay_multiplier()
	reward_label.text = "+$%.0f  (clicks x%.0f%%, CPU x%.2f)" % [final_pay * cpu_mult, ratio * 100.0, cpu_mult]
	_is_working = false
	_current_job = {}
	start_job_button.text = ">  Empezar trabajo"
	start_job_button.disabled = not TimeManager.is_work_time
	click_area.visible = false
	job_list.mouse_filter = Control.MOUSE_FILTER_STOP
	timer_label.text = ""
	refresh()
