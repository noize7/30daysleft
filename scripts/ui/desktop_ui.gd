extends Control
class_name DesktopUI
## =============================================================================
## DesktopUI — Escritorio estilo Windows XP (ventanas por escena AppWindow)
##
## Qué hace:
##   - Wallpaper, barra de tareas, reloj, batería, día, dinero
##   - Ventanas de programas (Trabajo / Correo / Archivos) arrastrables
##   - Sistema de trabajo Fase 2: lista de jobs, timer, clicks, pago, niveles
##
## EXPORTS (Inspector del nodo DesktopUI):
##   - taskbar_font_size / window_title_font_size / app_font_size
##     → sube estos valores para textos más legibles
##
## Iconos del escritorio:
##   Se crean desde Main (exports icon_trabajo, icon_correo, icon_archivos,
##   icon_scale). Aquí solo vive el contenedor $Icons.
## =============================================================================

signal icon_activated(app_name: String)
signal start_pressed
signal shutdown_requested

const APP_WINDOW_SCENE := preload("res://scenes/ui/app_window.tscn")
const WORK_APP_SCENE := preload("res://scenes/apps/work_app.tscn")
const SHOP_APP_SCENE := preload("res://scenes/apps/shop_app.tscn")
const EMAIL_APP_SCENE := preload("res://scenes/apps/email_app.tscn")
const FILES_APP_SCENE := preload("res://scenes/apps/files_app.tscn")
const OPTIONS_MENU_SCENE := preload("res://scenes/menus/options_menu.tscn")
const BANK_APP_SCENE := preload("res://scenes/apps/bank_app.tscn")
const MUSIC_APP_SCENE := preload("res://scenes/apps/music_app.tscn")

# --- Nodos de la escena ------------------------------------------------------
@onready var wallpaper: ColorRect = $Wallpaper
@onready var taskbar: Panel = $Taskbar
@onready var start_button: Button = $Taskbar/StartButton
@onready var clock_label: Label = $Taskbar/ClockLabel
@onready var battery_bar: ProgressBar = $Taskbar/BatteryBar
@onready var battery_label: Label = $Taskbar/BatteryLabel
@onready var day_label: Label = $Taskbar/DayLabel
@onready var money_label: Label = $Taskbar/MoneyLabel
@onready var icons_container: Control = $Icons

# --- EXPORTS: tamaños de fuente (ajusta en Inspector) ------------------------
@export_group("Fuentes UI")
## Tamaño de fuente de la barra de tareas (día, dinero, reloj, batería)
@export var taskbar_font_size: int = 27
## Tamaño de fuente del título de las ventanas
@export var window_title_font_size: int = 25
## Tamaño de fuente del contenido de los programas
@export var app_font_size: int = 22

# Ventanas abiertas: nombre_app → Panel
var _windows: Dictionary = {}
# StyleBox de relleno de la barra de batería (para cambiar color)
var _battery_fill_style: StyleBoxFlat

## Al cargar: aplica estilo XP, conecta señales, oculta escritorio.
func _ready() -> void:
	_apply_xp_style()
	_connect_signals()
	_update_all_labels()
	visible = false

## Aplica colores y estilos estilo Windows XP a taskbar, botón Inicio y batería.
func _apply_xp_style() -> void:
	if wallpaper:
		wallpaper.color = Color(0.227, 0.431, 0.647)  # Azul XP clásico

	if taskbar:
		var tb_style := StyleBoxFlat.new()
		tb_style.bg_color = Color(0.141, 0.369, 0.863)
		tb_style.set_corner_radius_all(0)
		tb_style.border_width_top = 2
		tb_style.border_color = Color(0.235, 0.506, 0.953)
		taskbar.add_theme_stylebox_override("panel", tb_style)

	if start_button:
		var start_style := StyleBoxFlat.new()
		start_style.bg_color = Color(0.235, 0.545, 0.235)
		start_style.set_corner_radius_all(4)
		start_style.content_margin_left = 14
		start_style.content_margin_right = 14
		start_style.content_margin_top = 6
		start_style.content_margin_bottom = 6
		start_button.add_theme_stylebox_override("normal", start_style)
		var start_hover := start_style.duplicate()
		start_hover.bg_color = Color(0.298, 0.686, 0.314)
		start_button.add_theme_stylebox_override("hover", start_hover)
		var start_pressed_style := start_style.duplicate()
		start_pressed_style.bg_color = Color(0.180, 0.490, 0.196)
		start_button.add_theme_stylebox_override("pressed", start_pressed_style)
		start_button.add_theme_color_override("font_color", Color.WHITE)
		start_button.add_theme_color_override("font_hover_color", Color.WHITE)
		start_button.add_theme_font_size_override("font_size", taskbar_font_size)

	# Labels de la taskbar con fuente grande
	for lbl in [clock_label, battery_label, day_label, money_label]:
		if lbl:
			lbl.add_theme_color_override("font_color", Color.WHITE)
			lbl.add_theme_font_size_override("font_size", taskbar_font_size)

	if battery_bar:
		_battery_fill_style = StyleBoxFlat.new()
		_battery_fill_style.bg_color = Color(0.361, 0.722, 0.361)
		_battery_fill_style.set_corner_radius_all(3)
		battery_bar.add_theme_stylebox_override("fill", _battery_fill_style)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.102, 0.102, 0.102)
		bg.set_corner_radius_all(3)
		battery_bar.add_theme_stylebox_override("background", bg)

## Conecta señales del GameManager y TimeManager a la UI.
func _connect_signals() -> void:
	if start_button:
		start_button.pressed.connect(_on_start_pressed)
	GameManager.day_changed.connect(_on_day_changed)
	GameManager.money_changed.connect(_on_money_changed)
	GameManager.battery_changed.connect(_on_battery_changed)
	GameManager.job_level_changed.connect(_on_job_level_changed)
	GameManager.jobs_completed_changed.connect(_on_jobs_completed_changed)
	TimeManager.time_updated.connect(_on_time_updated)
	TimeManager.work_hours_changed.connect(_on_work_hours_changed)
	GameManager.upgrade_changed.connect(_on_upgrade_changed)
	GameManager.sanity_changed.connect(_on_sanity_changed)
	GameManager.suspicion_changed.connect(_on_suspicion_changed)

## Muestra el escritorio y refresca labels.
func show_desktop() -> void:
	visible = true
	_update_all_labels()

## Oculta el escritorio y cierra todas las ventanas abiertas.
func hide_desktop() -> void:
	visible = false
	_close_all_windows()

## Actualiza día, dinero, batería y reloj.
func _update_all_labels() -> void:
	if day_label:
		day_label.text = "Dia %d" % GameManager.day
	if money_label:
		# Dinero + cordura compactos en la taskbar
		money_label.text = "$%s  |  C:%d%%" % [_format_money(GameManager.money), int(GameManager.sanity)]
	_on_battery_changed(GameManager.battery)
	if clock_label:
		clock_label.text = TimeManager.get_time_string()

## Formatea dinero: 1200 → 1.2K, 1500000 → 1.50M
func _format_money(value: float) -> String:
	if value >= 1000000.0:
		return "%.2fM" % (value / 1000000.0)
	elif value >= 1000.0:
		return "%.1fK" % (value / 1000.0)
	return "%.0f" % value

func _on_day_changed(_d: int) -> void:
	if day_label:
		day_label.text = "Dia %d" % GameManager.day

func _on_money_changed(m: float) -> void:
	if money_label:
		var passive: float = UpgradeSystem.get_passive_income_per_sec()
		if passive > 0.0:
			money_label.text = "$%s  (+$%.1f/s)" % [_format_money(m), passive]
		else:
			money_label.text = "$%s" % _format_money(m)
	_refresh_open_shop_window()

## Actualiza barra y color de batería (verde / amarillo / rojo).
func _on_battery_changed(_b: float) -> void:
	var pct := GameManager.get_battery_percent()
	if battery_bar:
		battery_bar.value = pct
	if battery_label:
		battery_label.text = "%d%%" % int(pct)
	if _battery_fill_style:
		if pct > 50.0:
			_battery_fill_style.bg_color = Color(0.361, 0.722, 0.361)
		elif pct > 20.0:
			_battery_fill_style.bg_color = Color(0.941, 0.678, 0.306)
		else:
			_battery_fill_style.bg_color = Color(0.851, 0.325, 0.310)

func _on_time_updated(_h: int, _m: int, _s: int) -> void:
	if clock_label:
		clock_label.text = TimeManager.get_time_string()


func _on_sanity_changed(_s: float) -> void:
	if money_label:
		money_label.text = "$%s  |  C:%d%%" % [_format_money(GameManager.money), int(GameManager.sanity)]
	# Refrescar correo si está abierto (header muestra cordura)
	if _windows.has("Correo") and is_instance_valid(_windows["Correo"]):
		var content = _windows["Correo"].get_node_or_null("Content")
		if content:
			_refresh_email_ui(content)

func _on_suspicion_changed(_s: float) -> void:
	# La sospecha se refleja en eventos; si llega a 100 GameManager dispara final
	pass

func _on_start_pressed() -> void:
	start_pressed.emit()

func _on_job_level_changed(_lvl: int) -> void:
	_refresh_open_work_window()

func _on_jobs_completed_changed(_count: int) -> void:
	_refresh_open_work_window()

func _on_work_hours_changed(_is_work: bool) -> void:
	_refresh_open_work_window()

## Si la ventana Trabajo está abierta, refresca su UI interna.
func _refresh_open_work_window() -> void:
	if not _windows.has("Trabajo"):
		return
	var win = _windows["Trabajo"]
	if not is_instance_valid(win):
		return
	var content = win.get_node_or_null("Content")
	if content and content.get_child_count() > 0:
		var app = content.get_child(0)
		if app and app.has_method("refresh"):
			app.refresh()

## Abre una app (o trae al frente si ya estaba abierta).
func open_app(app_name: String) -> void:
	if app_name.is_empty():
		return
	if _windows.has(app_name) and is_instance_valid(_windows[app_name]):
		_windows[app_name].visible = true
		_windows[app_name].move_to_front()
		return
	var win := _create_window(app_name)
	if win == null:
		push_error("DesktopUI: no se pudo crear ventana para '%s'" % app_name)
		return
	_windows[app_name] = win

## Crea una ventana desde la escena AppWindow.
## Orden seguro: instantiate → add_child → setup → construir contenido.
func _create_window(app_name: String) -> Panel:
	if APP_WINDOW_SCENE == null:
		push_error("DesktopUI: APP_WINDOW_SCENE es null")
		return null

	var win = APP_WINDOW_SCENE.instantiate()
	if win == null:
		push_error("DesktopUI: instantiate de AppWindow falló")
		return null

	win.name = "Window_" + app_name

	var win_size := Vector2(700, 550)
	if app_name == "Trabajo":
		win_size = Vector2(740, 590)
	elif app_name == "Mejoras":
		win_size = Vector2(720, 610)
	elif app_name == "Correo" or app_name == "Archivos":
		win_size = Vector2(660, 500)
	elif app_name == "Banco":
		win_size = Vector2(620, 520)
	elif app_name == "Opciones":
		win_size = Vector2(700, 560)
	elif app_name == "Música":
		win_size = Vector2(620, 480)

	# La ventana nunca debe ser más grande que la pantalla disponible
	# (deja margen para bordes y la barra de tareas)
	var vp: Vector2 = get_viewport_rect().size
	win_size.x = minf(win_size.x, maxf(320.0, vp.x - 40.0))
	win_size.y = minf(win_size.y, maxf(240.0, vp.y - 96.0))

	# Posición inicial siempre dentro de los límites visibles de la pantalla
	var max_x: float = maxf(20.0, vp.x - win_size.x - 20.0)
	var max_y: float = maxf(20.0, vp.y - win_size.y - 78.0)
	win.position = Vector2(clampf(160 + randi() % 80, 20.0, max_x), clampf(40 + randi() % 50, 20.0, max_y))

	# Añadir al árbol PRIMERO para que @onready y _ready funcionen
	add_child(win)

	if win.has_method("setup"):
		win.setup(app_name, win_size)
	else:
		win.size = win_size

	var content: Control = win.get_node_or_null("Content")
	if content == null:
		content = Control.new()
		content.name = "Content"
		content.position = Vector2(10, 40)
		content.size = Vector2(win_size.x - 20, win_size.y - 54)
		win.add_child(content)

	# Contenido = escenas separadas (.tscn) para poder ajustarlas en el editor
	var app_scene: PackedScene = null
	match app_name:
		"Trabajo":
			app_scene = WORK_APP_SCENE
		"Mejoras":
			app_scene = SHOP_APP_SCENE
		"Correo":
			app_scene = EMAIL_APP_SCENE
		"Archivos":
			app_scene = FILES_APP_SCENE
		"Opciones":
			app_scene = OPTIONS_MENU_SCENE
		"Banco":
			app_scene = BANK_APP_SCENE
		"Música":
			app_scene = MUSIC_APP_SCENE
		_:
			pass

	if app_scene:
		var app_ui = app_scene.instantiate()
		app_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		# Escala de iconos de la tienda (export shop_icon_scale en Main)
		if app_name == "Mejoras" and app_ui.has_method("set_icon_scale"):
			var main_node = get_tree().current_scene
			var sc: float = 1.2
			if main_node != null and main_node.get("shop_icon_scale") != null:
				sc = float(main_node.shop_icon_scale)
			app_ui.call("set_icon_scale", sc)
		# Si es el menú de opciones, quitar wallpaper a pantalla completa
		if app_name == "Opciones":
			# ALWAYS para que FPS / settings sigan activos aunque se pause el árbol
			app_ui.process_mode = Node.PROCESS_MODE_ALWAYS
			if app_ui.has_node("Wallpaper"):
				app_ui.get_node("Wallpaper").visible = false
			if app_ui.has_node("Panel"):
				var p: Control = app_ui.get_node("Panel")
				p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				p.offset_left = 4
				p.offset_top = 4
				p.offset_right = -4
				p.offset_bottom = -4
			if app_ui.has_signal("closed"):
				app_ui.closed.connect(func():
					win.visible = false
				)
		content.add_child(app_ui)
	else:
		var lbl := Label.new()
		lbl.text = "Aplicacion: " + app_name
		lbl.position = Vector2(20, 20)
		lbl.add_theme_color_override("font_color", Color(0.133, 0.133, 0.133))
		lbl.add_theme_font_size_override("font_size", app_font_size)
		content.add_child(lbl)

	return win as Panel


# =============================================================================
# FASE 2 — SISTEMA DE TRABAJO
# JobSelector + Timer + ClickArea + PaymentSystem + RewardDisplay
# =============================================================================

## Construye toda la UI del programa Trabajo.
func _build_work_content(parent: Control) -> void:
	# Cabecera con nivel actual
	var header := Label.new()
	header.name = "Header"
	header.text = "Centro de Trabajo  |  Nivel %d" % GameManager.job_level
	header.position = Vector2(8, 4)
	header.size = Vector2(560, 28)
	header.add_theme_color_override("font_color", Color(0.0, 0.0, 0.502))
	header.add_theme_font_size_override("font_size", app_font_size + 3)
	parent.add_child(header)

	# Progreso hacia el siguiente nivel
	var progress_lbl := Label.new()
	progress_lbl.name = "LevelProgress"
	progress_lbl.position = Vector2(8, 32)
	progress_lbl.size = Vector2(560, 24)
	progress_lbl.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
	progress_lbl.add_theme_font_size_override("font_size", app_font_size)
	parent.add_child(progress_lbl)

	# Estado de horario laboral
	var status := Label.new()
	status.name = "WorkStatus"
	status.position = Vector2(8, 56)
	status.size = Vector2(560, 24)
	status.add_theme_font_size_override("font_size", app_font_size)
	parent.add_child(status)

	# Lista de trabajos disponibles (JobSelector)
	var list := ItemList.new()
	list.name = "JobList"
	list.position = Vector2(8, 86)
	list.size = Vector2(320, 180)
	list.add_theme_font_size_override("font_size", app_font_size)
	list.item_selected.connect(_on_job_selected.bind(parent))
	parent.add_child(list)

	# Detalles del trabajo seleccionado
	var details := Label.new()
	details.name = "JobDetails"
	details.position = Vector2(340, 86)
	details.size = Vector2(230, 180)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_theme_color_override("font_color", Color(0.133, 0.133, 0.133))
	details.add_theme_font_size_override("font_size", app_font_size)
	details.text = "Selecciona un\ntrabajo de la lista"
	parent.add_child(details)

	# Barra de progreso del timer del trabajo
	var timer_bar := ProgressBar.new()
	timer_bar.name = "TimerBar"
	timer_bar.position = Vector2(8, 280)
	timer_bar.size = Vector2(560, 24)
	timer_bar.value = 0
	timer_bar.show_percentage = false
	var tfill := StyleBoxFlat.new()
	tfill.bg_color = Color(0.141, 0.369, 0.863)
	tfill.set_corner_radius_all(3)
	timer_bar.add_theme_stylebox_override("fill", tfill)
	var tbg := StyleBoxFlat.new()
	tbg.bg_color = Color(0.8, 0.8, 0.8)
	tbg.set_corner_radius_all(3)
	timer_bar.add_theme_stylebox_override("background", tbg)
	parent.add_child(timer_bar)

	# Texto del timer
	var timer_lbl := Label.new()
	timer_lbl.name = "TimerLabel"
	timer_lbl.position = Vector2(8, 308)
	timer_lbl.size = Vector2(250, 22)
	timer_lbl.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
	timer_lbl.add_theme_font_size_override("font_size", app_font_size)
	timer_lbl.text = ""
	parent.add_child(timer_lbl)

	# ClickArea: botón para hacer clicks durante el trabajo
	var click_btn := Button.new()
	click_btn.name = "ClickArea"
	click_btn.position = Vector2(280, 306)
	click_btn.size = Vector2(248, 32)
	click_btn.text = "CLICK para trabajar"
	click_btn.visible = false
	var cstyle := StyleBoxFlat.new()
	cstyle.bg_color = Color(0.902, 0.494, 0.133)
	cstyle.set_corner_radius_all(5)
	click_btn.add_theme_stylebox_override("normal", cstyle)
	var chover := cstyle.duplicate()
	chover.bg_color = Color(0.953, 0.612, 0.071)
	click_btn.add_theme_stylebox_override("hover", chover)
	click_btn.add_theme_color_override("font_color", Color.WHITE)
	click_btn.add_theme_font_size_override("font_size", app_font_size)
	click_btn.pressed.connect(_on_work_click.bind(parent))
	parent.add_child(click_btn)

	# Botón empezar trabajo
	var start_btn := Button.new()
	start_btn.name = "StartJobButton"
	start_btn.position = Vector2(8, 348)
	start_btn.size = Vector2(220, 36)
	start_btn.text = ">  Empezar trabajo"
	var bstyle := StyleBoxFlat.new()
	bstyle.bg_color = Color(0.141, 0.369, 0.863)
	bstyle.set_corner_radius_all(5)
	start_btn.add_theme_stylebox_override("normal", bstyle)
	var bhover := bstyle.duplicate()
	bhover.bg_color = Color(0.235, 0.506, 0.953)
	start_btn.add_theme_stylebox_override("hover", bhover)
	start_btn.add_theme_color_override("font_color", Color.WHITE)
	start_btn.add_theme_font_size_override("font_size", app_font_size + 1)
	start_btn.pressed.connect(_on_start_job.bind(parent))
	parent.add_child(start_btn)

	# RewardDisplay: muestra el pago al terminar
	var reward_lbl := Label.new()
	reward_lbl.name = "RewardLabel"
	reward_lbl.position = Vector2(240, 352)
	reward_lbl.size = Vector2(280, 32)
	reward_lbl.add_theme_color_override("font_color", Color(0.0, 0.392, 0.0))
	reward_lbl.add_theme_font_size_override("font_size", app_font_size + 2)
	reward_lbl.text = ""
	parent.add_child(reward_lbl)

	# Estado del trabajo en metadatos del panel
	parent.set_meta("selected_job_idx", 0)
	parent.set_meta("is_working", false)
	parent.set_meta("clicks_done", 0)
	parent.set_meta("clicks_needed", 0)

	_refresh_work_ui(parent)

## Actualiza lista, progreso, estado y botón según horario y nivel.
func _refresh_work_ui(parent: Control) -> void:
	if not is_instance_valid(parent):
		return

	var header: Label = parent.get_node_or_null("Header")
	var progress_lbl: Label = parent.get_node_or_null("LevelProgress")
	var status: Label = parent.get_node_or_null("WorkStatus")
	var list: ItemList = parent.get_node_or_null("JobList")
	var start_btn: Button = parent.get_node_or_null("StartJobButton")

	if header:
		header.text = "Centro de Trabajo  |  Nivel %d" % GameManager.job_level

	if progress_lbl:
		var next_req: int = WorkSystem.get_next_level_requirement()
		if next_req < 0:
			progress_lbl.text = "Nivel maximo  •  Trabajos completados: %d" % GameManager.jobs_completed
		else:
			progress_lbl.text = "Progreso: %d / %d para Nivel %d" % [
				GameManager.jobs_completed, next_req, GameManager.job_level + 1
			]

	if status:
		if TimeManager.is_work_time:
			status.text = "HORARIO LABORAL (01:00 - 05:00)  —  Puedes trabajar"
			status.add_theme_color_override("font_color", Color(0.0, 0.392, 0.0))
		else:
			status.text = "Fuera de horario — trabajo bloqueado (solo 01:00-05:00)"
			status.add_theme_color_override("font_color", Color(0.545, 0.0, 0.0))

	if list:
		list.clear()
		var available: Array = WorkSystem.get_available_jobs()
		for job in available:
			var min_p: int = int(job["min_pay"])
			var max_p: int = int(job["max_pay"])
			var lvl: int = int(job["level"])
			var jname: String = str(job["name"])
			list.add_item("Lv%d  %s  ($%d-$%d)" % [lvl, jname, min_p, max_p])
		if available.size() > 0:
			var sel: int = clampi(int(parent.get_meta("selected_job_idx", 0)), 0, available.size() - 1)
			list.select(sel)
			_on_job_selected(sel, parent)

	if start_btn:
		var working: bool = parent.get_meta("is_working", false)
		start_btn.disabled = working or not TimeManager.is_work_time

## Al seleccionar un trabajo en la lista, muestra sus detalles.
func _on_job_selected(idx: int, parent: Control) -> void:
	parent.set_meta("selected_job_idx", idx)
	var details: Label = parent.get_node_or_null("JobDetails")
	var available: Array = WorkSystem.get_available_jobs()
	if idx < 0 or idx >= available.size():
		if details:
			details.text = "Selecciona un\ntrabajo de la lista"
		return
	var job: Dictionary = available[idx]
	if details:
		details.text = "%s\n\n%s\n\nPago: $%d - $%d\nDuracion: ~%ds\nClicks: %d" % [
			str(job["name"]),
			str(job.get("description", "")),
			int(job["min_pay"]), int(job["max_pay"]),
			int(job.get("duration", 10)),
			int(job.get("clicks_required", 5))
		]

## Inicia el trabajo seleccionado: timer + click area.
func _on_start_job(parent: Control) -> void:
	if parent.get_meta("is_working", false):
		return
	if not TimeManager.is_work_time:
		_refresh_work_ui(parent)
		return

	var idx: int = int(parent.get_meta("selected_job_idx", -1))
	var available: Array = WorkSystem.get_available_jobs()
	if idx < 0 or idx >= available.size():
		return

	var job: Dictionary = available[idx]
	parent.set_meta("is_working", true)
	parent.set_meta("clicks_done", 0)
	parent.set_meta("clicks_needed", int(job.get("clicks_required", 5)))
	parent.set_meta("current_job", job)

	var start_btn: Button = parent.get_node_or_null("StartJobButton")
	var click_btn: Button = parent.get_node_or_null("ClickArea")
	var timer_bar: ProgressBar = parent.get_node_or_null("TimerBar")
	var timer_lbl: Label = parent.get_node_or_null("TimerLabel")
	var reward_lbl: Label = parent.get_node_or_null("RewardLabel")
	var list: ItemList = parent.get_node_or_null("JobList")

	if start_btn:
		start_btn.disabled = true
		start_btn.text = "Trabajando..."
	if click_btn:
		click_btn.visible = true
		click_btn.disabled = false
		click_btn.text = "CLICK 0/%d" % int(parent.get_meta("clicks_needed"))
	if reward_lbl:
		reward_lbl.text = ""
	if list:
		list.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Timer del trabajo (PaymentSystem se aplica al terminar)
	var duration: float = float(job.get("duration", 10))
	var elapsed: float = 0.0
	if timer_bar:
		timer_bar.value = 0
		timer_bar.max_value = duration

	while elapsed < duration and parent.get_meta("is_working", false) and GameManager.is_pc_on:
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1
		if timer_bar:
			timer_bar.value = elapsed
		if timer_lbl:
			var remaining: float = maxf(0.0, duration - elapsed)
			timer_lbl.text = "Tiempo: %.1fs" % remaining
		# Pequeño drenaje extra de batería mientras trabajas
		GameManager.spend_battery(0.015)

	_finish_job(parent)

## Cada click durante el trabajo aumenta el multiplicador de pago.
func _on_work_click(parent: Control) -> void:
	if not parent.get_meta("is_working", false):
		return
	var done: int = int(parent.get_meta("clicks_done", 0)) + 1
	var needed: int = int(parent.get_meta("clicks_needed", 5))
	parent.set_meta("clicks_done", done)
	var click_btn: Button = parent.get_node_or_null("ClickArea")
	if click_btn:
		click_btn.text = "CLICK %d/%d" % [done, needed]
		if done >= needed:
			click_btn.text = "Completado!"
			click_btn.disabled = true

## Calcula pago según clicks y lo entrega al GameManager (PaymentSystem).
func _finish_job(parent: Control) -> void:
	var job: Dictionary = parent.get_meta("current_job", {})
	if job.is_empty():
		parent.set_meta("is_working", false)
		return

	var clicks_done: int = int(parent.get_meta("clicks_done", 0))
	var clicks_needed: int = int(parent.get_meta("clicks_needed", 5))
	# Mínimo 40% del pago aunque no hagas clicks; 100% si completas todos
	var click_ratio: float = clampf(float(clicks_done) / float(maxi(1, clicks_needed)), 0.4, 1.0)
	var base_pay: float = randf_range(float(job["min_pay"]), float(job["max_pay"]))
	var final_pay: float = base_pay * click_ratio

	# Registra el trabajo (sube jobs_completed y puede subir de nivel)
	GameManager.complete_job(final_pay)

	var reward_lbl: Label = parent.get_node_or_null("RewardLabel")
	var start_btn: Button = parent.get_node_or_null("StartJobButton")
	var click_btn: Button = parent.get_node_or_null("ClickArea")
	var timer_lbl: Label = parent.get_node_or_null("TimerLabel")
	var list: ItemList = parent.get_node_or_null("JobList")

	if reward_lbl:
		var cpu_mult: float = UpgradeSystem.get_pay_multiplier()
		var shown: float = final_pay * cpu_mult
		reward_lbl.text = "+$%.0f  (clicks x%.0f%%, CPU x%.2f)" % [shown, click_ratio * 100.0, cpu_mult]
	if start_btn:
		start_btn.text = ">  Empezar trabajo"
		start_btn.disabled = not TimeManager.is_work_time
	if click_btn:
		click_btn.visible = false
		click_btn.disabled = false
	if timer_lbl:
		timer_lbl.text = "Trabajo terminado"
	if list:
		list.mouse_filter = Control.MOUSE_FILTER_STOP

	parent.set_meta("is_working", false)
	_refresh_work_ui(parent)

# =============================================================================
# OTRAS APPS (placeholders Fase 1 / 7)
# =============================================================================


# =============================================================================
# FASE 3-4 — TIENDA DE MEJORAS (Sistema economico + upgrades de PC)
# =============================================================================

## Refresca la ventana Mejoras si esta abierta (tras comprar o cambiar dinero).
func _on_upgrade_changed(_category: String, _level: int) -> void:
	_refresh_open_shop_window()
	_refresh_open_work_window()
	# Archivos: RAM puede desbloquear ocultos
	if _windows.has("Archivos") and is_instance_valid(_windows["Archivos"]):
		var content = _windows["Archivos"].get_node_or_null("Content")
		if content:
			_refresh_files_ui(content)

func _refresh_open_shop_window() -> void:
	if not _windows.has("Mejoras"):
		return
	var win = _windows["Mejoras"]
	if not is_instance_valid(win):
		return
	var content = win.get_node_or_null("Content")
	if content and content.get_child_count() > 0:
		var app = content.get_child(0)
		if app and app.has_method("refresh"):
			app.refresh()

## Construye la UI de la tienda de mejoras.
func _build_shop_content(parent: Control) -> void:
	var title := Label.new()
	title.name = "ShopTitle"
	title.text = "Tienda de mejoras  |  Objetivo: $%.0f" % GameManager.MONEY_GOAL
	title.position = Vector2(8, 4)
	title.size = Vector2(520, 28)
	title.add_theme_color_override("font_color", Color(0.0, 0.0, 0.45))
	title.add_theme_font_size_override("font_size", app_font_size + 3)
	parent.add_child(title)

	var money_info := Label.new()
	money_info.name = "ShopMoney"
	money_info.position = Vector2(8, 34)
	money_info.size = Vector2(520, 24)
	money_info.add_theme_color_override("font_color", Color(0.0, 0.4, 0.0))
	money_info.add_theme_font_size_override("font_size", app_font_size + 1)
	parent.add_child(money_info)

	var list := ItemList.new()
	list.name = "ShopList"
	list.position = Vector2(8, 66)
	list.size = Vector2(320, 220)
	list.add_theme_font_size_override("font_size", app_font_size)
	list.item_selected.connect(_on_shop_selected.bind(parent))
	parent.add_child(list)

	var details := Label.new()
	details.name = "ShopDetails"
	details.position = Vector2(340, 66)
	details.size = Vector2(190, 180)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15))
	details.add_theme_font_size_override("font_size", app_font_size)
	details.text = "Selecciona una mejora"
	parent.add_child(details)

	var buy_btn := Button.new()
	buy_btn.name = "BuyButton"
	buy_btn.position = Vector2(340, 260)
	buy_btn.size = Vector2(190, 36)
	buy_btn.text = "Comprar"
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.141, 0.369, 0.863)
	bs.set_corner_radius_all(4)
	buy_btn.add_theme_stylebox_override("normal", bs)
	var bh := bs.duplicate()
	bh.bg_color = Color(0.235, 0.506, 0.953)
	buy_btn.add_theme_stylebox_override("hover", bh)
	buy_btn.add_theme_color_override("font_color", Color.WHITE)
	buy_btn.add_theme_font_size_override("font_size", app_font_size + 1)
	buy_btn.pressed.connect(_on_shop_buy.bind(parent))
	parent.add_child(buy_btn)

	var feedback := Label.new()
	feedback.name = "ShopFeedback"
	feedback.position = Vector2(8, 300)
	feedback.size = Vector2(520, 28)
	feedback.add_theme_font_size_override("font_size", app_font_size)
	feedback.text = ""
	parent.add_child(feedback)

	var goal := Label.new()
	goal.name = "ShopGoal"
	goal.position = Vector2(8, 340)
	goal.size = Vector2(520, 50)
	goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goal.add_theme_color_override("font_color", Color(0.25, 0.25, 0.25))
	goal.add_theme_font_size_override("font_size", app_font_size - 1)
	goal.text = "El dinero se usa para mejoras y para el final ESCAPE.\nTransfiere $%.0f en el Banco a la cuenta del correo." % GameManager.MONEY_GOAL
	parent.add_child(goal)

	parent.set_meta("selected_shop_idx", 0)
	_refresh_shop_ui(parent)

## Rellena la lista y el estado de la tienda.
func _refresh_shop_ui(parent: Control) -> void:
	if not is_instance_valid(parent):
		return
	var money_info: Label = parent.get_node_or_null("ShopMoney")
	var list: ItemList = parent.get_node_or_null("ShopList")
	var buy_btn: Button = parent.get_node_or_null("BuyButton")

	if money_info:
		money_info.text = "Dinero disponible: $%.0f" % GameManager.money

	if list:
		list.clear()
		for cat in UpgradeSystem.CATEGORY_ORDER:
			list.add_item(UpgradeSystem.get_status_line(cat))
		var sel: int = clampi(int(parent.get_meta("selected_shop_idx", 0)), 0, maxi(0, UpgradeSystem.CATEGORY_ORDER.size() - 1))
		if UpgradeSystem.CATEGORY_ORDER.size() > 0:
			list.select(sel)
			_on_shop_selected(sel, parent)

	if buy_btn:
		var idx: int = int(parent.get_meta("selected_shop_idx", 0))
		if idx < 0 or idx >= UpgradeSystem.CATEGORY_ORDER.size():
			buy_btn.disabled = true
		else:
			var cat: String = UpgradeSystem.CATEGORY_ORDER[idx]
			var cost: int = UpgradeSystem.get_next_cost(cat)
			var can: bool = UpgradeSystem.can_upgrade(cat) and GameManager.money >= float(cost)
			buy_btn.disabled = not can
			if not UpgradeSystem.can_upgrade(cat):
				buy_btn.text = "Nivel maximo"
			else:
				buy_btn.text = "Comprar ($%d)" % cost

## Al seleccionar una fila de la tienda, muestra detalles.
func _on_shop_selected(idx: int, parent: Control) -> void:
	parent.set_meta("selected_shop_idx", idx)
	var details: Label = parent.get_node_or_null("ShopDetails")
	var buy_btn: Button = parent.get_node_or_null("BuyButton")
	if idx < 0 or idx >= UpgradeSystem.CATEGORY_ORDER.size():
		return
	var cat: String = UpgradeSystem.CATEGORY_ORDER[idx]
	var cur: Dictionary = UpgradeSystem.get_current(cat)
	var nxt: Dictionary = UpgradeSystem.get_next(cat)
	if details:
		var txt: String = "Actual:\n%s\n\n%s" % [str(cur.get("name", "")), str(cur.get("desc", ""))]
		if not nxt.is_empty():
			txt += "\n\nSiguiente:\n%s\n%s\nCoste: $%d" % [
				str(nxt.get("name", "")), str(nxt.get("desc", "")), int(nxt.get("cost", 0))
			]
		else:
			txt += "\n\n(Nivel maximo alcanzado)"
		details.text = txt
	if buy_btn:
		if nxt.is_empty():
			buy_btn.disabled = true
			buy_btn.text = "Nivel maximo"
		else:
			var cost: int = int(nxt.get("cost", 0))
			buy_btn.disabled = GameManager.money < float(cost)
			buy_btn.text = "Comprar ($%d)" % cost

## Intenta comprar la mejora seleccionada.
func _on_shop_buy(parent: Control) -> void:
	var idx: int = int(parent.get_meta("selected_shop_idx", 0))
	var feedback: Label = parent.get_node_or_null("ShopFeedback")
	if idx < 0 or idx >= UpgradeSystem.CATEGORY_ORDER.size():
		return
	var cat: String = UpgradeSystem.CATEGORY_ORDER[idx]
	var ok: bool = UpgradeSystem.try_buy(cat)
	if feedback:
		if ok:
			feedback.add_theme_color_override("font_color", Color(0.0, 0.45, 0.0))
			feedback.text = "Compra realizada: %s" % UpgradeSystem.CATEGORY_LABELS.get(cat, cat)
		else:
			feedback.add_theme_color_override("font_color", Color(0.6, 0.0, 0.0))
			feedback.text = "No se pudo comprar (sin dinero o nivel maximo)"
	_refresh_shop_ui(parent)

func _build_email_content(parent: Control) -> void:
	## Bandeja de correo (Tanda 4): lista + lector
	var header := Label.new()
	header.name = "EmailHeader"
	header.position = Vector2(8, 4)
	header.size = Vector2(480, 24)
	header.add_theme_color_override("font_color", Color(0.0, 0.0, 0.45))
	header.add_theme_font_size_override("font_size", app_font_size + 2)
	parent.add_child(header)

	var list := ItemList.new()
	list.name = "EmailList"
	list.position = Vector2(8, 34)
	list.size = Vector2(200, 280)
	list.add_theme_font_size_override("font_size", app_font_size)
	list.item_selected.connect(_on_email_selected.bind(parent))
	parent.add_child(list)

	var body := Label.new()
	body.name = "EmailBody"
	body.position = Vector2(220, 34)
	body.size = Vector2(280, 280)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15))
	body.add_theme_font_size_override("font_size", app_font_size)
	body.text = "Selecciona un correo"
	parent.add_child(body)

	parent.set_meta("email_ids", [])
	_refresh_email_ui(parent)
	if not EmailSystem.emails_changed.is_connected(_on_emails_signal):
		EmailSystem.emails_changed.connect(_on_emails_signal)

func _on_emails_signal() -> void:
	if _windows.has("Correo") and is_instance_valid(_windows["Correo"]):
		var content = _windows["Correo"].get_node_or_null("Content")
		if content:
			_refresh_email_ui(content)

func _refresh_email_ui(parent: Control) -> void:
	if not is_instance_valid(parent):
		return
	var header: Label = parent.get_node_or_null("EmailHeader")
	var list: ItemList = parent.get_node_or_null("EmailList")
	if header:
		var unread: int = EmailSystem.unread_count()
		header.text = "Bandeja  |  %d sin leer  |  Cordura: %d%%" % [unread, int(GameManager.sanity)]
	if list == null:
		return
	list.clear()
	var ids: Array = []
	var inbox: Array = EmailSystem.get_inbox()
	for mail in inbox:
		var id: String = str(mail["id"])
		ids.append(id)
		var mark: String = " " if EmailSystem.is_read(id) else "*"
		var fake_tag: String = " [?] " if bool(mail.get("is_fake", false)) else " "
		list.add_item("%s%s%s" % [mark, fake_tag, str(mail.get("subject", ""))])
	parent.set_meta("email_ids", ids)

func _on_email_selected(idx: int, parent: Control) -> void:
	var ids: Array = parent.get_meta("email_ids", [])
	if idx < 0 or idx >= ids.size():
		return
	var email_id: String = str(ids[idx])
	EmailSystem.mark_read(email_id)
	var body: Label = parent.get_node_or_null("EmailBody")
	for mail in EmailSystem.EMAILS:
		if str(mail["id"]) != email_id:
			continue
		if body:
			var fake_note: String = "\n\n---\n(Este mensaje podria ser falso.)" if bool(mail.get("is_fake", false)) else ""
			body.text = "De: %s\n\n%s%s" % [str(mail.get("from", "")), str(mail.get("body", "")), fake_note]
		break
	_refresh_email_ui(parent)

func _build_files_content(parent: Control) -> void:
	## Explorador de pistas / memorias (Tanda 4)
	var header := Label.new()
	header.name = "FilesHeader"
	header.position = Vector2(8, 4)
	header.size = Vector2(480, 24)
	header.add_theme_color_override("font_color", Color(0.0, 0.0, 0.45))
	header.add_theme_font_size_override("font_size", app_font_size + 2)
	parent.add_child(header)

	var list := ItemList.new()
	list.name = "ClueList"
	list.position = Vector2(8, 34)
	list.size = Vector2(200, 280)
	list.add_theme_font_size_override("font_size", app_font_size)
	list.item_selected.connect(_on_clue_selected.bind(parent))
	parent.add_child(list)

	var body := Label.new()
	body.name = "ClueBody"
	body.position = Vector2(220, 34)
	body.size = Vector2(280, 280)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15))
	body.add_theme_font_size_override("font_size", app_font_size)
	body.text = "Selecciona un archivo"
	parent.add_child(body)

	parent.set_meta("clue_ids", [])
	_refresh_files_ui(parent)
	if not ClueSystem.clues_changed.is_connected(_on_clues_signal):
		ClueSystem.clues_changed.connect(_on_clues_signal)

func _on_clues_signal() -> void:
	if _windows.has("Archivos") and is_instance_valid(_windows["Archivos"]):
		var content = _windows["Archivos"].get_node_or_null("Content")
		if content:
			_refresh_files_ui(content)

func _refresh_files_ui(parent: Control) -> void:
	if not is_instance_valid(parent):
		return
	var header: Label = parent.get_node_or_null("FilesHeader")
	var list: ItemList = parent.get_node_or_null("ClueList")
	var body: Label = parent.get_node_or_null("ClueBody")
	if header:
		var ram_note := "  |  RAM 8GB: OK" if UpgradeSystem.has_hidden_files_access() else "  |  RAM baja: ocultos bloqueados"
		header.text = "Archivos  |  Pistas %d leidas  |  Escape: %d%s" % [
			ClueSystem.read_count(), ClueSystem.CLUES_NEEDED_FOR_ESCAPE, ram_note
		]
	if list == null:
		return
	list.clear()
	var ids: Array = []
	var available: Array = ClueSystem.get_available()
	for clue in available:
		var id: String = str(clue["id"])
		ids.append(id)
		var mark: String = "[leido] " if ClueSystem.is_read(id) else "[nuevo] "
		var title: String = str(clue.get("title", id))
		list.add_item(mark + title)
	parent.set_meta("clue_ids", ids)
	if available.is_empty() and body:
		if ClueSystem.has_locked_hidden():
			body.text = "No hay archivos visibles.\n\n[DIR] recuerdos/\nBloqueado: mejora la RAM a 8GB\nen Mejoras para abrir archivos ocultos."
		else:
			body.text = "Sin archivos desbloqueados aun.\nLas pistas aparecen con el paso de los dias."
	elif ClueSystem.has_locked_hidden() and body and body.text == "Selecciona un archivo":
		body.text = "Hay una carpeta oculta: recuerdos/\nMejora la RAM a 8GB en Mejoras para abrirla."

func _on_clue_selected(idx: int, parent: Control) -> void:
	var ids: Array = parent.get_meta("clue_ids", [])
	if idx < 0 or idx >= ids.size():
		return
	var clue_id: String = str(ids[idx])
	ClueSystem.mark_read(clue_id)
	var body: Label = parent.get_node_or_null("ClueBody")
	for clue in ClueSystem.CLUES:
		if str(clue["id"]) != clue_id:
			continue
		if body:
			body.text = "%s\n\n%s\n\n(+5 cordura al leer)" % [str(clue.get("title", "")), str(clue.get("body", ""))]
		break
	_refresh_files_ui(parent)

## Cierra y libera todas las ventanas abiertas.
func _close_all_windows() -> void:
	for key in _windows.keys():
		var w = _windows[key]
		if is_instance_valid(w):
			w.queue_free()
	_windows.clear()
