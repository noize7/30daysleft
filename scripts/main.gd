extends Control
## =============================================================================
## Main — Escena raíz (30 DAYS LEFT) — Tanda 6: boot UI, archivos, icono ajustes
## =============================================================================

const MAIN_MENU_SCENE := preload("res://scenes/menus/main_menu.tscn")
const OPTIONS_SCENE := preload("res://scenes/menus/options_menu.tscn")
const CREDITS_SCENE := preload("res://scenes/menus/credits_menu.tscn")
const PAUSE_SCENE := preload("res://scenes/menus/pause_menu.tscn")
const DESKTOP_ICON_SCENE := preload("res://scenes/ui/desktop_icon.tscn")
const START_POPUP_SCENE := preload("res://scenes/menus/start_popup.tscn")

@onready var boot_screen: ColorRect = $BootScreen
@onready var boot_label: Label = $BootScreen/BootLabel
@onready var desktop: Control = $DesktopUI
@onready var power_button: Button = $PowerButton
@onready var ending_screen: ColorRect = $EndingScreen
@onready var ending_label: Label = $EndingScreen/EndingLabel
@onready var restart_button: Button = $EndingScreen/RestartButton

@export_group("Iconos del escritorio")
@export var icon_trabajo: Texture2D
@export var icon_correo: Texture2D
@export var icon_archivos: Texture2D
@export var icon_mejoras: Texture2D
## Icono de Opciones / Ajustes. Vacío = color gris.
## Textura del icono "Opciones" / Ajustes.
@export var icon_opciones: Texture2D
## Textura del icono Banco.
@export var icon_banco: Texture2D
## Textura del icono MusicPlayer (Tanda 8).
@export var icon_musica: Texture2D
@export_range(0.5, 3.0, 0.1) var icon_scale: float = 1.8

@export_group("Tienda de mejoras")
## Escala de los iconos dentro de la lista de Mejoras (Inspector del nodo Main).
@export_range(0.5, 3.0, 0.1) var shop_icon_scale: float = 1.2

## Nombre de app -> nodo DesktopIcon (para reubicarlos tras cargar partida)
var _desktop_icons: Dictionary = {}
const _ICON_NAMES: Array = ["Trabajo", "Correo", "Archivos", "Mejoras", "Opciones", "Banco", "Música"]

var _main_menu: Control = null
var _options_menu: Control = null
var _credits_menu: Control = null
var _pause_menu: Control = null
var _from_pause_options: bool = false
var _shutting_down: bool = false
var _start_popup: Control = null
var _booting: bool = false

const OptionsMenuScript = preload("res://scripts/menus/options_menu.gd")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	OptionsMenuScript.apply_saved_settings_boot()
	
	boot_screen.visible = false
	desktop.visible = false
	ending_screen.visible = false
	power_button.visible = false

	_style_boot()
	_style_power_button()
	_style_ending()

	power_button.pressed.connect(_on_power_pressed)
	restart_button.pressed.connect(_on_restart)
	if desktop.has_signal("start_pressed"):
		desktop.start_pressed.connect(_on_start_menu)
	GameManager.game_over.connect(_on_game_over)
	GameManager.pc_powered_changed.connect(_on_pc_power)

	_create_desktop_icons()
	# Aplicar opciones guardadas (FPS, velocidad, drenaje, dificultad…) al arrancar
	_boot_apply_settings()
	_show_main_menu()

## Carga user://settings.json y aplica velocidad / drenaje / dificultad / fullscreen.
func _boot_apply_settings() -> void:
	var path := "user://settings.json"
	var settings := {
		"master_volume": 80.0,
		"game_speed": 1,
		"difficulty": 1,
		"battery_drain": 1,
		"fullscreen": false,
		"show_fps": false,
	}
	if FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.READ)
		if file:
			var parsed = JSON.parse_string(file.get_as_text())
			file.close()
			if typeof(parsed) == TYPE_DICTIONARY:
				for k in settings.keys():
					if parsed.has(k):
						settings[k] = parsed[k]
	if bool(settings.fullscreen):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	if TimeManager:
		match int(settings.game_speed):
			0:
				TimeManager.GAME_SECONDS_PER_REAL_SECOND = 20.0
			1:
				TimeManager.GAME_SECONDS_PER_REAL_SECOND = 28.0
			2:
				TimeManager.GAME_SECONDS_PER_REAL_SECOND = 45.0
		var base_drain: float = 0.28
		match int(settings.battery_drain):
			0:
				base_drain = 0.18
			1:
				base_drain = 0.28
			2:
				base_drain = 0.42
		match int(settings.difficulty):
			0:
				base_drain *= 0.75
			2:
				base_drain *= 1.35
		TimeManager.BATTERY_DRAIN_PER_REAL_SECOND = base_drain
	if GameManager:
		match int(settings.difficulty):
			0:
				GameManager.set_meta("suspicion_mult", 0.7)
			1:
				GameManager.set_meta("suspicion_mult", 1.0)
			2:
				GameManager.set_meta("suspicion_mult", 1.4)
	if bool(settings.show_fps):
		var existing = get_tree().root.get_node_or_null("FPSOverlay")
		if existing == null:
			var lbl := Label.new()
			lbl.name = "FPSOverlay"
			lbl.z_index = 100
			lbl.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			lbl.offset_left = -120.0
			lbl.offset_top = 8.0
			lbl.offset_right = -8.0
			lbl.offset_bottom = 32.0
			lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))
			lbl.add_theme_font_size_override("font_size", 16)
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			get_tree().root.add_child(lbl)
		set_process(true)

func _process(_delta: float) -> void:
	var fps_node = get_tree().root.get_node_or_null("FPSOverlay")
	if fps_node and fps_node.visible:
		fps_node.text = "FPS: %d" % Engine.get_frames_per_second()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if GameManager.is_pc_on and not GameManager.is_game_over and desktop.visible:
			_toggle_pause()

func _show_main_menu() -> void:
	if _main_menu and is_instance_valid(_main_menu):
		_main_menu.visible = true
		_main_menu._refresh_continue()
		return
	_main_menu = MAIN_MENU_SCENE.instantiate()
	add_child(_main_menu)
	_main_menu.play_pressed.connect(_on_menu_new_game)
	_main_menu.continue_pressed.connect(_on_menu_continue)
	_main_menu.options_pressed.connect(_on_menu_options)
	_main_menu.credits_pressed.connect(_on_menu_credits)
	_main_menu.quit_pressed.connect(func(): get_tree().quit())

func _hide_main_menu() -> void:
	if _main_menu and is_instance_valid(_main_menu):
		_main_menu.visible = false

func _on_menu_new_game() -> void:
	# Ocultar cualquier pantalla de apagado ANTES del reset para no ver un frame.
	boot_screen.visible = false
	boot_label.visible = false
	power_button.visible = false
	ending_screen.visible = false
	if desktop.has_method("hide_desktop"):
		desktop.hide_desktop()
	else:
		desktop.visible = false
	if SaveManager.has_save():
		SaveManager.delete_save()
	GameManager.reset_game()
	_reset_icon_layout()
	_hide_main_menu()
	_start_boot_sequence(false)

func _on_menu_continue() -> void:
	_hide_main_menu()
	_start_boot_sequence(true)

func _on_menu_options() -> void:
	_from_pause_options = false
	_open_options()

func _on_menu_credits() -> void:
	if _credits_menu and is_instance_valid(_credits_menu):
		_credits_menu.visible = true
		return
	_credits_menu = CREDITS_SCENE.instantiate()
	add_child(_credits_menu)
	_credits_menu.closed.connect(func():
		_credits_menu.visible = false
	)

func _open_options() -> void:
	if _options_menu and is_instance_valid(_options_menu):
		_options_menu.visible = true
		return
	_options_menu = OPTIONS_SCENE.instantiate()
	add_child(_options_menu)
	_options_menu.closed.connect(func():
		_options_menu.visible = false
		if _from_pause_options and _pause_menu:
			_pause_menu.visible = true
	)

func _start_boot_sequence(_load_save: bool) -> void:
	boot_screen.visible = true
	# Mientras se espera a que el jugador pulse encender, solo se ve el botón
	boot_label.visible = false
	power_button.visible = true
	power_button.text = "ENCENDER"
	_center_power_button()


func _style_boot() -> void:
	boot_screen.color = Color(0.015, 0.03, 0.06)
	boot_label.text = "30 DAYS LEFT"
	boot_label.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	boot_label.add_theme_font_size_override("font_size", 52)
	boot_label.add_theme_color_override("font_shadow_color", Color(0.15, 0.4, 0.85, 0.45))
	boot_label.add_theme_constant_override("shadow_offset_x", 0)
	boot_label.add_theme_constant_override("shadow_offset_y", 3)
	boot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	boot_label.offset_top = -40.0
	boot_label.offset_bottom = -40.0


func _style_power_button() -> void:
	power_button.text = "ENCENDER"
	power_button.custom_minimum_size = Vector2(240, 58)
	_center_power_button()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.58, 0.32)
	style.set_corner_radius_all(29)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	style.border_width_bottom = 3
	style.border_color = Color(0.07, 0.32, 0.16)
	power_button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = Color(0.20, 0.70, 0.40)
	power_button.add_theme_stylebox_override("hover", hover)
	var pressed := style.duplicate()
	pressed.bg_color = Color(0.10, 0.42, 0.22)
	power_button.add_theme_stylebox_override("pressed", pressed)
	power_button.add_theme_color_override("font_color", Color.WHITE)
	power_button.add_theme_color_override("font_hover_color", Color.WHITE)
	power_button.add_theme_font_size_override("font_size", 22)



func _center_power_button() -> void:
	## Centra el botón con anclas (estable en fullscreen / resize).
	power_button.anchor_left = 0.5
	power_button.anchor_right = 0.5
	power_button.anchor_top = 0.62
	power_button.anchor_bottom = 0.62
	power_button.offset_left = -120.0
	power_button.offset_right = 120.0
	power_button.offset_top = -29.0
	power_button.offset_bottom = 29.0
	power_button.grow_horizontal = Control.GROW_DIRECTION_BOTH
	power_button.grow_vertical = Control.GROW_DIRECTION_BOTH

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED or what == NOTIFICATION_RESIZED:
		if power_button and power_button.visible:
			_center_power_button()

func _style_ending() -> void:
	## UI de finales: imagen a pantalla completa; texto y botón abajo a la izquierda
	## para que se aprecien las ilustraciones cuando se añadan.
	ending_screen.color = Color(0.039, 0.039, 0.039)
	# Texto abajo a la izquierda (esquina)
	ending_label.anchor_left = 0.0
	ending_label.anchor_right = 0.55
	ending_label.anchor_top = 1.0
	ending_label.anchor_bottom = 1.0
	ending_label.offset_left = 24.0
	ending_label.offset_right = -12.0
	ending_label.offset_top = -160.0
	ending_label.offset_bottom = -72.0
	ending_label.grow_horizontal = Control.GROW_DIRECTION_END
	ending_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ending_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.97))
	ending_label.add_theme_font_size_override("font_size", 22)
	ending_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	ending_label.add_theme_constant_override("shadow_offset_x", 1)
	ending_label.add_theme_constant_override("shadow_offset_y", 1)
	ending_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	ending_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	ending_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Botón abajo a la izquierda, junto al texto
	restart_button.anchor_left = 0.0
	restart_button.anchor_right = 0.0
	restart_button.anchor_top = 1.0
	restart_button.anchor_bottom = 1.0
	restart_button.offset_left = 24.0
	restart_button.offset_right = 200.0
	restart_button.offset_top = -56.0
	restart_button.offset_bottom = -16.0
	restart_button.grow_horizontal = Control.GROW_DIRECTION_END
	restart_button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var rs := StyleBoxFlat.new()
	rs.bg_color = Color(0.141, 0.369, 0.863)
	rs.set_corner_radius_all(8)
	rs.content_margin_left = 16
	rs.content_margin_right = 16
	rs.content_margin_top = 8
	rs.content_margin_bottom = 8
	restart_button.add_theme_stylebox_override("normal", rs)
	var rh := rs.duplicate()
	rh.bg_color = Color(0.22, 0.48, 0.95)
	restart_button.add_theme_stylebox_override("hover", rh)
	restart_button.add_theme_color_override("font_color", Color.WHITE)
	restart_button.add_theme_font_size_override("font_size", 18)
	restart_button.text = "Menú principal"

## Calcula la posición en rejilla del icono "index" sin solapes,
## usando el mismo cálculo de tamaño que DesktopIcon._rebuild().
## Con 7 iconos usamos 3 columnas para que ninguno quede fuera de pantalla.
func _grid_icon_position(index: int) -> Vector2:
	var icon_sz: float = 56.0 * icon_scale
	var cell_w: float = maxf(icon_sz + 24.0, 96.0 * icon_scale) + 20.0
	var cell_h: float = icon_sz + 36.0 * icon_scale + 16.0
	var margin: float = 24.0
	var cols: int = 3
	var col: int = index % cols
	@warning_ignore("integer_division")
	var row: int = index / cols
	var pos := Vector2(margin + col * cell_w, margin + row * cell_h)
	# Clamp para no salir del área visible (deja margen para la taskbar ~48px)
	var vp := get_viewport_rect().size
	var max_x: float = maxf(margin, vp.x - cell_w - 8.0)
	var max_y: float = maxf(margin, vp.y - cell_h - 56.0)
	pos.x = clampf(pos.x, margin, max_x)
	pos.y = clampf(pos.y, margin, max_y)
	return pos

## Reordena todos los iconos en la rejilla por defecto (nueva partida / sin guardado).
func _reset_icon_layout() -> void:
	for i in range(_ICON_NAMES.size()):
		var key: String = _ICON_NAMES[i]
		if _desktop_icons.has(key) and is_instance_valid(_desktop_icons[key]):
			_desktop_icons[key].position = _grid_icon_position(i)

## Aplica las posiciones de icono guardadas en GameManager.icon_positions (tras cargar partida).
func _apply_saved_icon_positions() -> void:
	var vp := get_viewport_rect().size
	for key in GameManager.icon_positions.keys():
		if not _desktop_icons.has(key):
			continue
		var icon = _desktop_icons[key]
		if not is_instance_valid(icon):
			continue
		var arr = GameManager.icon_positions[key]
		if arr is Array and arr.size() >= 2:
			var p := Vector2(float(arr[0]), float(arr[1]))
			# Evitar iconos fuera de pantalla (p.ej. tras cambiar resolución o añadir iconos)
			p.x = clampf(p.x, 8.0, maxf(8.0, vp.x - 80.0))
			p.y = clampf(p.y, 8.0, maxf(8.0, vp.y - 100.0))
			icon.position = p

func _create_desktop_icons() -> void:
	var container: Control = desktop.get_node_or_null("Icons")
	if container == null:
		push_warning("Main: no se encontró Icons en DesktopUI")
		return
	var icons_data: Array = [
		{"name": "Trabajo", "color": Color(0.141, 0.369, 0.863), "tex": icon_trabajo},
		{"name": "Correo", "color": Color(0.902, 0.494, 0.133), "tex": icon_correo},
		{"name": "Archivos", "color": Color(0.557, 0.267, 0.678), "tex": icon_archivos},
		{"name": "Mejoras", "color": Color(0.0, 0.55, 0.55), "tex": icon_mejoras},
		{"name": "Opciones", "color": Color(0.35, 0.35, 0.4), "tex": icon_opciones},
		{"name": "Banco", "color": Color(0.15, 0.55, 0.30), "tex": icon_banco},
		{"name": "Música", "color": Color(0.6, 0.2, 0.45), "tex": icon_musica},
	]
	for i in range(icons_data.size()):
		var data: Dictionary = icons_data[i]
		var icon: Control = null
		if DESKTOP_ICON_SCENE:
			icon = DESKTOP_ICON_SCENE.instantiate()
		else:
			icon = DesktopIcon.new()
		if icon.has_method("setup"):
			icon.call("setup", str(data["name"]), data["color"] as Color, data["tex"] as Texture2D, icon_scale)
		icon.position = _grid_icon_position(i)
		container.add_child(icon)
		_desktop_icons[str(data["name"])] = icon
		if icon.has_signal("activated"):
			icon.connect("activated", _on_icon)

func _on_icon(app_name: String) -> void:
	if app_name.is_empty():
		return
	if desktop == null:
		return
	if desktop.has_method("open_app"):
		desktop.open_app(app_name)
	else:
		push_error("DesktopUI no tiene open_app")

func _on_power_pressed() -> void:
	if _booting:
		return
	_booting = true
	power_button.visible = false
	boot_label.visible = true
	await _play_boot_animation()
	_try_load_or_new()
	await get_tree().create_timer(0.2).timeout
	boot_screen.visible = false
	_clear_boot_fx()
	GameManager.power_on_pc()
	if desktop.has_method("show_desktop"):
		desktop.show_desktop()
	else:
		desktop.visible = true
	await _desktop_flash()
	_booting = false


func _play_boot_animation() -> void:
	boot_label.text = "30 DAYS LEFT"
	boot_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	boot_label.add_theme_font_size_override("font_size", 42)
	var vp := get_viewport_rect().size

	var status := Label.new()
	status.name = "BootStatus"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_color_override("font_color", Color(0.55, 0.9, 0.7))
	status.add_theme_font_size_override("font_size", 20)
	status.size = Vector2(420, 32)
	status.position = Vector2((vp.x - 420.0) * 0.5, vp.y * 0.48)
	boot_screen.add_child(status)

	var bar := ProgressBar.new()
	bar.name = "BootBar"
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 0.0
	bar.show_percentage = false
	bar.size = Vector2(320, 14)
	bar.position = Vector2((vp.x - 320.0) * 0.5, vp.y * 0.55)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.2, 0.7, 0.95)
	fill.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.12, 0.18)
	bg.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("background", bg)
	boot_screen.add_child(bar)

	var dots_row := HBoxContainer.new()
	dots_row.name = "BootDots"
	dots_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dots_row.add_theme_constant_override("separation", 14)
	dots_row.position = Vector2((vp.x - 60.0) * 0.5, vp.y * 0.55 + 28.0)
	boot_screen.add_child(dots_row)
	var balls: Array = []
	for i in range(3):
		var ball := ColorRect.new()
		ball.custom_minimum_size = Vector2(12, 12)
		ball.size = Vector2(12, 12)
		ball.color = Color(0.3, 0.75, 1.0)
		dots_row.add_child(ball)
		balls.append(ball)

	var steps: Array = [
		"Iniciando discos...",
		"Cargando RAM...",
		"Verificando batería...",
		"Montando sistema...",
		"Cargando escritorio...",
		"Listo."
	]
	var total_time := 3.5
	var step_time := total_time / float(steps.size())
	for si in range(steps.size()):
		status.text = str(steps[si])
		var t0 := 0.0
		while t0 < step_time:
			await get_tree().create_timer(0.05).timeout
			t0 += 0.05
			bar.value = ((float(si) + t0 / step_time) / float(steps.size())) * 100.0
			for bi in range(balls.size()):
				var b: ColorRect = balls[bi]
				var phase: float = Time.get_ticks_msec() / 200.0 + float(bi) * 0.9
				b.position.y = sin(phase) * 6.0
	status.text = "Sistema listo"
	bar.value = 100.0
	await get_tree().create_timer(0.25).timeout


func _clear_boot_fx() -> void:
	for n in ["BootStatus", "BootBar", "BootDots"]:
		var node = boot_screen.get_node_or_null(n)
		if node:
			node.queue_free()
	boot_label.text = "30 DAYS LEFT"
	boot_label.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	boot_label.add_theme_font_size_override("font_size", 52)


func _on_pc_power(is_on: bool) -> void:
	if not is_on and not GameManager.is_game_over:
		if _shutting_down:
			return
		# Evitar flash de apagado al pulsar "Nueva partida" / reset.
		if GameManager.suppress_shutdown:
			return
		_shutdown_pc_sequence("Batería agotada")


func _on_start_menu() -> void:
	# Ventanita de Inicio estilo Windows (no arrastrable)
	_show_start_popup()

func _show_start_popup() -> void:
	if _start_popup == null or not is_instance_valid(_start_popup):
		_start_popup = START_POPUP_SCENE.instantiate()
		add_child(_start_popup)
		_start_popup.shutdown_pressed.connect(func():
			_shutdown_pc_sequence("Apagando el PC")
		)
	if _start_popup.has_method("show_popup"):
		_start_popup.show_popup()
	else:
		_start_popup.visible = true

func _shutdown_pc_sequence(reason: String = "Batería agotada") -> void:
	if _shutting_down:
		return
	_shutting_down = true
	if desktop.has_method("hide_desktop"):
		desktop.hide_desktop()
	else:
		desktop.visible = false
	if _pause_menu and is_instance_valid(_pause_menu):
		_pause_menu.hide_pause()
	# Fijar el texto de apagado ANTES de mostrar la pantalla, para que nunca
	# se vea "30 DAYS LEFT" de fondo ni por un instante.
	boot_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.35))
	boot_label.add_theme_font_size_override("font_size", 36)
	boot_label.text = "%s\n\nApagando el PC." % reason
	boot_label.visible = true
	boot_screen.visible = true
	power_button.visible = false
	# Apagar lógica primero (avanza el día si aplica)
	if GameManager.is_pc_on:
		GameManager.power_off_pc()
	for i in range(4):
		var n: int = (i % 3) + 1
		var dots: String = ""
		for _j in range(n):
			dots += "."
		boot_label.text = "%s\n\nApagando el PC%s" % [reason, dots]
		await get_tree().create_timer(0.4).timeout
	# Volver al estado de "solo botón de encender" (sin texto de fondo)
	boot_label.visible = false
	boot_label.text = "30 DAYS LEFT"
	boot_label.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	boot_label.add_theme_font_size_override("font_size", 52)
	power_button.visible = true
	power_button.text = "ENCENDER"
	_shutting_down = false


func _toggle_pause() -> void:
	if _pause_menu == null or not is_instance_valid(_pause_menu):
		_pause_menu = PAUSE_SCENE.instantiate()
		add_child(_pause_menu)
		_pause_menu.resume_pressed.connect(func():
			_pause_menu.hide_pause()
		)
		_pause_menu.main_menu_pressed.connect(func():
			_pause_menu.hide_pause()
			GameManager.power_off_pc()
			if desktop.has_method("hide_desktop"):
				desktop.hide_desktop()
			boot_screen.visible = false
			power_button.visible = false
			_show_main_menu()
		)
		_pause_menu.quit_pressed.connect(func(): get_tree().quit())
	if _pause_menu.visible:
		_pause_menu.hide_pause()
	else:
		_pause_menu.show_pause()

func _on_game_over(ending: String) -> void:
	if _pause_menu and is_instance_valid(_pause_menu):
		_pause_menu.hide_pause()
	if desktop.has_method("hide_desktop"):
		desktop.hide_desktop()
	else:
		desktop.visible = false
	boot_screen.visible = false
	power_button.visible = false
	ending_screen.visible = true
	# Fondo listo para ilustraciones de final (assets/endings/*.png cuando existan).
	_apply_ending_background(ending)
	match ending:
		"locura":
			ending_label.text = "FINAL 2 de 3 — LOCURA\nHas perdido el contacto con la realidad."
		"atrapado":
			ending_label.text = "FINAL 3 de 3 — ATRAPADO\nSin transferencia completa o sin pistas.\nLa policía ha llegado."
		"escape":
			ending_label.text = "ESCAPE 1 de 3\nTransferiste el dinero y recuperaste las pistas.\nEscapaste a tiempo."
		_:
			ending_label.text = "FIN\n%s" % ending

## Intenta cargar una imagen de final si existe; si no, deja el color sólido.
func _apply_ending_background(ending: String) -> void:
	var path := "res://assets/endings/%s.png" % ending
	var img_node: TextureRect = ending_screen.get_node_or_null("EndingImage")
	if img_node == null:
		img_node = TextureRect.new()
		img_node.name = "EndingImage"
		img_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		img_node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img_node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		img_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ending_screen.add_child(img_node)
		ending_screen.move_child(img_node, 0)
	if ResourceLoader.exists(path):
		img_node.texture = load(path)
		img_node.visible = true
		ending_screen.color = Color(0, 0, 0, 1)
	else:
		img_node.texture = null
		img_node.visible = false
		ending_screen.color = Color(0.039, 0.039, 0.039, 1)

func _on_restart() -> void:
	# Ocultar pantallas antes del reset para no ver flash de apagado
	ending_screen.visible = false
	boot_screen.visible = false
	boot_label.visible = false
	power_button.visible = false
	SaveManager.delete_save()
	GameManager.reset_game()
	_show_main_menu()

func _try_load_or_new() -> void:
	if SaveManager.has_save():
		if SaveManager.load_game():
			boot_label.text = "Día %d" % GameManager.day
			_apply_saved_icon_positions()
		else:
			boot_label.text = "Nueva partida"
			EmailSystem.unlock_for_day(1)
			ClueSystem.unlock_for_day(1)
			_reset_icon_layout()
	else:
		EmailSystem.unlock_for_day(1)
		ClueSystem.unlock_for_day(1)
		_reset_icon_layout()


func _desktop_flash() -> void:
	## Destello suave al entrar al escritorio
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0.35)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	flash.move_to_front()
	var tw := create_tween()
	tw.tween_property(flash, "color:a", 0.0, 0.45)
	await tw.finished
	flash.queue_free()
