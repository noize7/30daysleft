extends Control
## Ajustes como app del escritorio (no bloquea el juego)

@onready var volume_slider: HSlider = $Scroll/VBox/VolumeSlider
@onready var sfx_slider: HSlider = $Scroll/VBox/SfxSlider
@onready var speed_option: OptionButton = $Scroll/VBox/SpeedOption
@onready var difficulty_option: OptionButton = $Scroll/VBox/DiffOption
@onready var battery_drain_option: OptionButton = $Scroll/VBox/DrainOption
@onready var fullscreen_check: CheckBox = $Scroll/VBox/FullscreenCheck
@onready var show_fps_check: CheckBox = $Scroll/VBox/ShowFpsCheck
@onready var auto_save_check: CheckBox = $Scroll/VBox/AutoSaveCheck
@onready var btn_apply: Button = $Scroll/VBox/BtnApply

func _ready() -> void:
	_style_black_text()
	_populate()
	btn_apply.pressed.connect(_on_apply)

func _style_black_text() -> void:
	$Title.add_theme_color_override("font_color", Color(0.05, 0.05, 0.1))
	$Title.add_theme_font_size_override("font_size", 18)
	for child in $Scroll/VBox.get_children():
		if child is Label or child is CheckBox:
			child.add_theme_color_override("font_color", Color(0.08, 0.08, 0.12))
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.141, 0.369, 0.863)
	s.set_corner_radius_all(4)
	btn_apply.add_theme_stylebox_override("normal", s)
	btn_apply.add_theme_color_override("font_color", Color.WHITE)

func _populate() -> void:
	speed_option.clear()
	speed_option.add_item("Lenta (x0.75)", 0)
	speed_option.add_item("Normal (x1)", 1)
	speed_option.add_item("Rápida (x1.5)", 2)
	speed_option.selected = 1
	difficulty_option.clear()
	difficulty_option.add_item("Fácil", 0)
	difficulty_option.add_item("Normal", 1)
	difficulty_option.add_item("Difícil", 2)
	difficulty_option.selected = 1
	battery_drain_option.clear()
	battery_drain_option.add_item("Bajo", 0)
	battery_drain_option.add_item("Normal", 1)
	battery_drain_option.add_item("Alto", 2)
	battery_drain_option.selected = 1

func _on_apply() -> void:
	if fullscreen_check.button_pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	if TimeManager:
		match battery_drain_option.selected:
			0: TimeManager.BATTERY_DRAIN_PER_REAL_SECOND = 0.20
			1: TimeManager.BATTERY_DRAIN_PER_REAL_SECOND = 0.28
			2: TimeManager.BATTERY_DRAIN_PER_REAL_SECOND = 0.45
		match speed_option.selected:
			0: TimeManager.GAME_SECONDS_PER_REAL_SECOND = 20.0
			1: TimeManager.GAME_SECONDS_PER_REAL_SECOND = 28.0
			2: TimeManager.GAME_SECONDS_PER_REAL_SECOND = 45.0
	$Title.text = "Ajustes aplicados ✓"
