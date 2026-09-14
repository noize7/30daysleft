extends Control
## =============================================================================
## OptionsMenu — Menú de opciones (escena separada)
## Persiste ajustes en user://settings.json y los aplica de verdad.
## Los controles guardan estado al cambiar (no hace falta solo "Aplicar").
## =============================================================================

signal closed
signal settings_changed

const SETTINGS_PATH := "user://settings.json"

@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var volume_slider: HSlider = $Panel/VBox/VolumeRow/VolumeSlider
@onready var volume_value: Label = $Panel/VBox/VolumeRow/VolumeValue
@onready var sfx_slider: HSlider = $Panel/VBox/SfxRow/SfxSlider
@onready var sfx_value: Label = $Panel/VBox/SfxRow/SfxValue
@onready var speed_option: OptionButton = $Panel/VBox/SpeedRow/SpeedOption
@onready var difficulty_option: OptionButton = $Panel/VBox/DiffRow/DiffOption
@onready var battery_drain_option: OptionButton = $Panel/VBox/DrainRow/DrainOption
@onready var fullscreen_check: CheckBox = $Panel/VBox/FullscreenCheck
@onready var show_fps_check: CheckBox = $Panel/VBox/ShowFpsCheck
@onready var auto_save_check: CheckBox = $Panel/VBox/AutoSaveCheck
@onready var language_option: OptionButton = $Panel/VBox/LangRow/LangOption
@onready var btn_apply: Button = $Panel/VBox/Buttons/BtnApply
@onready var btn_back: Button = $Panel/VBox/Buttons/BtnBack
@onready var btn_defaults: Button = $Panel/VBox/Buttons/BtnDefaults

var _settings := {
	"master_volume": 80.0,
	"sfx_volume": 70.0,
	"game_speed": 1,
	"difficulty": 1,
	"battery_drain": 1,
	"fullscreen": false,
	"show_fps": false,
	"auto_save": true,
	"language": 0
}

var _fps_label: Label = null
var _settings_loaded: bool = false
var _ui_ready: bool = false
var _applying_ui: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	_apply_xp_style()
	_populate_options()
	_load_into_ui()
	_connect_autosave()
	btn_apply.pressed.connect(_on_apply)
	btn_back.pressed.connect(func(): closed.emit())
	btn_defaults.pressed.connect(_on_defaults)
	volume_slider.value_changed.connect(_on_vol_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	_ui_ready = true
	_apply_runtime_settings(false)
	# Si se abre como app de escritorio, al mostrar de nuevo recargar UI
	visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed() -> void:
	if visible and _ui_ready:
		_load_settings()
		_load_into_ui()
		_apply_runtime_settings(false)

func _connect_autosave() -> void:
	# Guardar y aplicar al cambiar cualquier control (persiste el estado de botones)
	if speed_option and not speed_option.item_selected.is_connected(_on_any_changed):
		speed_option.item_selected.connect(_on_any_changed)
	if difficulty_option and not difficulty_option.item_selected.is_connected(_on_any_changed):
		difficulty_option.item_selected.connect(_on_any_changed)
	if battery_drain_option and not battery_drain_option.item_selected.is_connected(_on_any_changed):
		battery_drain_option.item_selected.connect(_on_any_changed)
	if fullscreen_check and not fullscreen_check.toggled.is_connected(_on_toggle_changed):
		fullscreen_check.toggled.connect(_on_toggle_changed)
	if show_fps_check and not show_fps_check.toggled.is_connected(_on_toggle_changed):
		show_fps_check.toggled.connect(_on_toggle_changed)
	if auto_save_check and not auto_save_check.toggled.is_connected(_on_toggle_changed):
		auto_save_check.toggled.connect(_on_toggle_changed)
	if language_option and not language_option.item_selected.is_connected(_on_any_changed):
		language_option.item_selected.connect(_on_any_changed)
	if volume_slider and not volume_slider.drag_ended.is_connected(_on_slider_ended):
		volume_slider.drag_ended.connect(_on_slider_ended)
	if sfx_slider and not sfx_slider.drag_ended.is_connected(_on_slider_ended):
		sfx_slider.drag_ended.connect(_on_slider_ended)

func _on_any_changed(_idx: int = 0) -> void:
	if _applying_ui or not _ui_ready:
		return
	_capture_from_ui()
	_save_settings()
	_apply_runtime_settings(false)
	settings_changed.emit()

func _on_toggle_changed(_pressed: bool = false) -> void:
	_on_any_changed()

func _on_slider_ended(_changed: bool = true) -> void:
	_on_any_changed()

func _process(_delta: float) -> void:
	if not bool(_settings.get("show_fps", false)):
		if _fps_label and is_instance_valid(_fps_label):
			_fps_label.visible = false
		return
	_ensure_fps_label()
	if _fps_label:
		_fps_label.visible = true
		_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()

func _ensure_fps_label() -> void:
	if _fps_label and is_instance_valid(_fps_label):
		return
	var tree := get_tree()
	if tree == null or tree.root == null:
		return
	var existing = tree.root.get_node_or_null("FPSOverlay")
	if existing:
		_fps_label = existing
		return
	_fps_label = Label.new()
	_fps_label.name = "FPSOverlay"
	_fps_label.z_index = 100
	_fps_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_fps_label.offset_left = -120
	_fps_label.offset_top = 8
	_fps_label.offset_right = -8
	_fps_label.offset_bottom = 32
	_fps_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))
	_fps_label.add_theme_font_size_override("font_size", 16)
	_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tree.root.add_child(_fps_label)

func _populate_options() -> void:
	speed_option.clear()
	speed_option.add_item("Lenta (x0.75)", 0)
	speed_option.add_item("Normal (x1)", 1)
	speed_option.add_item("Rápida (x1.5)", 2)

	difficulty_option.clear()
	difficulty_option.add_item("Fácil (más batería / menos sospecha)", 0)
	difficulty_option.add_item("Normal", 1)
	difficulty_option.add_item("Difícil (drenaje alto / sospecha rápida)", 2)

	battery_drain_option.clear()
	battery_drain_option.add_item("Bajo", 0)
	battery_drain_option.add_item("Normal", 1)
	battery_drain_option.add_item("Alto", 2)

	language_option.clear()
	language_option.add_item("Español", 0)
	language_option.add_item("English (próximamente)", 1)
	language_option.set_item_disabled(1, true)

func _load_into_ui() -> void:
	_applying_ui = true
	volume_slider.value = float(_settings.master_volume)
	sfx_slider.value = float(_settings.sfx_volume)
	speed_option.selected = clampi(int(_settings.game_speed), 0, 2)
	difficulty_option.selected = clampi(int(_settings.difficulty), 0, 2)
	battery_drain_option.selected = clampi(int(_settings.battery_drain), 0, 2)
	fullscreen_check.button_pressed = bool(_settings.fullscreen)
	show_fps_check.button_pressed = bool(_settings.show_fps)
	auto_save_check.button_pressed = bool(_settings.auto_save)
	language_option.selected = clampi(int(_settings.language), 0, 0)
	_on_vol_changed(float(_settings.master_volume))
	_on_sfx_changed(float(_settings.sfx_volume))
	_applying_ui = false

func _capture_from_ui() -> void:
	_settings.master_volume = volume_slider.value
	_settings.sfx_volume = sfx_slider.value
	_settings.game_speed = speed_option.selected
	_settings.difficulty = difficulty_option.selected
	_settings.battery_drain = battery_drain_option.selected
	_settings.fullscreen = fullscreen_check.button_pressed
	_settings.show_fps = show_fps_check.button_pressed
	_settings.auto_save = auto_save_check.button_pressed
	_settings.language = language_option.selected

func _on_vol_changed(v: float) -> void:
	volume_value.text = "%d%%" % int(v)

func _on_sfx_changed(v: float) -> void:
	sfx_value.text = "%d%%" % int(v)

func _on_apply() -> void:
	_capture_from_ui()
	_save_settings()
	_apply_runtime_settings(true)
	settings_changed.emit()
	closed.emit()

func _apply_runtime_settings(_from_apply: bool) -> void:
	# Pantalla completa
	if bool(_settings.fullscreen):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	# Volumen
	var master_db: float = linear_to_db(clampf(float(_settings.master_volume) / 100.0, 0.001, 1.0))
	var sfx_db: float = linear_to_db(clampf(float(_settings.sfx_volume) / 100.0, 0.001, 1.0))
	if AudioServer.get_bus_index("Master") >= 0:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), master_db)
	if AudioServer.get_bus_index("SFX") >= 0:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), sfx_db)

	# Velocidad de juego (TimeManager usa vars, no const)
	if TimeManager:
		match int(_settings.game_speed):
			0:
				TimeManager.GAME_SECONDS_PER_REAL_SECOND = 20.0
			1:
				TimeManager.GAME_SECONDS_PER_REAL_SECOND = 28.0
			2:
				TimeManager.GAME_SECONDS_PER_REAL_SECOND = 45.0

	# Drenaje de batería × dificultad
	if TimeManager:
		var base_drain: float = 0.28
		match int(_settings.battery_drain):
			0:
				base_drain = 0.18
			1:
				base_drain = 0.28
			2:
				base_drain = 0.42
		match int(_settings.difficulty):
			0:
				base_drain *= 0.75
			2:
				base_drain *= 1.35
		TimeManager.BATTERY_DRAIN_PER_REAL_SECOND = base_drain

	if GameManager:
		match int(_settings.difficulty):
			0:
				GameManager.set_meta("suspicion_mult", 0.7)
			1:
				GameManager.set_meta("suspicion_mult", 1.0)
			2:
				GameManager.set_meta("suspicion_mult", 1.4)

	# FPS
	set_process(bool(_settings.show_fps))
	if bool(_settings.show_fps):
		_ensure_fps_label()
		if _fps_label:
			_fps_label.visible = true
	elif _fps_label and is_instance_valid(_fps_label):
		_fps_label.visible = false

func _on_defaults() -> void:
	_settings = {
		"master_volume": 80.0,
		"sfx_volume": 70.0,
		"game_speed": 1,
		"difficulty": 1,
		"battery_drain": 1,
		"fullscreen": false,
		"show_fps": false,
		"auto_save": true,
		"language": 0
	}
	_load_into_ui()
	_save_settings()
	_apply_runtime_settings(false)
	settings_changed.emit()

func _save_settings() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("OptionsMenu: no se pudo guardar settings")
		return
	file.store_string(JSON.stringify(_settings, "\t"))
	file.close()

func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for k in _settings.keys():
		if parsed.has(k):
			_settings[k] = parsed[k]
	_settings_loaded = true

## Aplica settings guardados sin UI (llamar desde Main al arrancar).
static func apply_saved_settings_boot() -> void:
	var path := SETTINGS_PATH
	var settings := {
		"master_volume": 80.0,
		"sfx_volume": 70.0,
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
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var master_db: float = linear_to_db(clampf(float(settings.master_volume) / 100.0, 0.001, 1.0))
	if AudioServer.get_bus_index("Master") >= 0:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), master_db)
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
	# FPS overlay sin menú abierto
	if bool(settings.show_fps):
		var tree := Engine.get_main_loop() as SceneTree
		if tree and tree.root and tree.root.get_node_or_null("FPSOverlay") == null:
			var lbl := Label.new()
			lbl.name = "FPSOverlay"
			lbl.z_index = 100
			lbl.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			lbl.offset_left = -120
			lbl.offset_top = 8
			lbl.offset_right = -8
			lbl.offset_bottom = 32
			lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))
			lbl.add_theme_font_size_override("font_size", 16)
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tree.root.add_child(lbl)
			# Pequeño script inline no posible: actualizará cuando se abra opciones
			# o Main puede refrescar en _process. Se actualiza al abrir opciones.

func _force_black_text(node: Node) -> void:
	if node is Label or node is CheckBox or node is Button or node is OptionButton:
		if node is Button and node.name in ["BtnApply", "BtnBack", "BtnDefaults"]:
			return
		node.add_theme_color_override("font_color", Color(0.08, 0.08, 0.12))
	for c in node.get_children():
		_force_black_text(c)

func _apply_xp_style() -> void:
	if has_node("Panel"):
		var ps := StyleBoxFlat.new()
		ps.bg_color = Color(0.925, 0.914, 0.847)
		ps.border_width_left = 3
		ps.border_width_top = 3
		ps.border_width_right = 3
		ps.border_width_bottom = 3
		ps.border_color = Color(0.0, 0.329, 0.890)
		ps.set_corner_radius_all(0)
		$Panel.add_theme_stylebox_override("panel", ps)
	if has_node("Wallpaper"):
		$Wallpaper.color = Color(0.18, 0.32, 0.52)
	title_label.add_theme_color_override("font_color", Color(0.05, 0.05, 0.12))
	_force_black_text($Panel)
	title_label.add_theme_font_size_override("font_size", 26)
	for btn in [btn_apply, btn_back, btn_defaults]:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.141, 0.369, 0.863)
		s.set_corner_radius_all(5)
		s.content_margin_left = 12
		s.content_margin_right = 12
		s.content_margin_top = 8
		s.content_margin_bottom = 8
		btn.add_theme_stylebox_override("normal", s)
		var h := s.duplicate()
		h.bg_color = Color(0.235, 0.506, 0.953)
		btn.add_theme_stylebox_override("hover", h)
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_font_size_override("font_size", 16)
