extends Control
## =============================================================================
## MainMenu — Menú principal (oscuro, pulido, atmósfera)
## =============================================================================

signal play_pressed
signal continue_pressed
signal options_pressed
signal credits_pressed
signal quit_pressed

@onready var title_label: Label = $CenterPanel/VBox/TitleLabel
@onready var subtitle_label: Label = $CenterPanel/VBox/SubtitleLabel
@onready var btn_play: Button = $CenterPanel/VBox/BtnPlay
@onready var btn_continue: Button = $CenterPanel/VBox/BtnContinue
@onready var btn_options: Button = $CenterPanel/VBox/BtnOptions
@onready var btn_credits: Button = $CenterPanel/VBox/BtnCredits
@onready var btn_quit: Button = $CenterPanel/VBox/BtnQuit
@onready var version_label: Label = $VersionLabel

var _ambient_timer: float = 0.0
var _title_pulse: float = 0.0

func _ready() -> void:
	_apply_style()
	_decorate()
	_connect_buttons()
	_refresh_continue()
	_play_intro()
	set_process(true)

func _process(delta: float) -> void:
	_title_pulse += delta
	if title_label:
		var a: float = 0.92 + sin(_title_pulse * 1.4) * 0.08
		title_label.modulate.a = a
	_ambient_timer -= delta
	if _ambient_timer <= 0.0:
		_ambient_timer = randf_range(1.2, 2.8)
		_spawn_ambient_speck()

func _connect_buttons() -> void:
	btn_play.pressed.connect(func(): play_pressed.emit())
	btn_continue.pressed.connect(func(): continue_pressed.emit())
	btn_options.pressed.connect(func(): options_pressed.emit())
	btn_credits.pressed.connect(func(): credits_pressed.emit())
	btn_quit.pressed.connect(func(): quit_pressed.emit())
	for btn in [btn_play, btn_continue, btn_options, btn_credits, btn_quit]:
		if btn:
			btn.mouse_entered.connect(_on_btn_hover.bind(btn))
			btn.mouse_exited.connect(_on_btn_unhover.bind(btn))

func _on_btn_hover(btn: Button) -> void:
	var tw := create_tween()
	tw.tween_property(btn, "scale", Vector2(1.04, 1.04), 0.1).set_ease(Tween.EASE_OUT)

func _on_btn_unhover(btn: Button) -> void:
	var tw := create_tween()
	tw.tween_property(btn, "scale", Vector2.ONE, 0.1)

func _refresh_continue() -> void:
	var has_save := false
	if SaveManager and SaveManager.has_method("has_save"):
		has_save = SaveManager.has_save()
	elif FileAccess.file_exists("user://save/game_save.json"):
		has_save = true
	btn_continue.visible = has_save
	btn_continue.disabled = not has_save

func _play_intro() -> void:
	modulate.a = 0.0
	if has_node("CenterPanel"):
		$CenterPanel.scale = Vector2(0.94, 0.94)
		$CenterPanel.pivot_offset = $CenterPanel.size * 0.5
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.45)
	if has_node("CenterPanel"):
		tw.tween_property($CenterPanel, "scale", Vector2.ONE, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _decorate() -> void:
	# Línea decorativa bajo el título
	if has_node("CenterPanel/VBox") and title_label:
		var line := ColorRect.new()
		line.name = "TitleLine"
		line.custom_minimum_size = Vector2(0, 2)
		line.color = Color(0.35, 0.55, 0.95, 0.7)
		var vbox: VBoxContainer = $CenterPanel/VBox
		var idx := title_label.get_index()
		vbox.add_child(line)
		vbox.move_child(line, idx + 1)
	# Sombra de panel
	if has_node("CenterPanel"):
		var shadow := ColorRect.new()
		shadow.name = "PanelShadow"
		shadow.color = Color(0, 0, 0, 0.35)
		shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shadow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shadow.offset_left = 8
		shadow.offset_top = 10
		shadow.offset_right = 8
		shadow.offset_bottom = 10
		$CenterPanel.add_child(shadow)
		$CenterPanel.move_child(shadow, 0)

func _spawn_ambient_speck() -> void:
	var vp := get_viewport_rect().size
	var p := _soft_dot(Color(0.7, 0.85, 1.0, 0.35), randf_range(2.0, 4.5))
	p.position = Vector2(randf() * vp.x, vp.y + 4)
	add_child(p)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(p, "position:y", -10.0, randf_range(4.0, 7.0))
	tw.tween_property(p, "position:x", p.position.x + randf_range(-40, 40), randf_range(4.0, 7.0))
	tw.tween_property(p, "modulate:a", 0.0, randf_range(3.5, 6.5))
	tw.chain().tween_callback(p.queue_free)

func _soft_dot(color: Color, r: float) -> Panel:
	var p := Panel.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size = Vector2(r * 2, r * 2)
	var st := StyleBoxFlat.new()
	st.bg_color = color
	st.set_corner_radius_all(int(r * 2))
	p.add_theme_stylebox_override("panel", st)
	return p

func _apply_style() -> void:
	# Fondo profundo
	if has_node("Wallpaper"):
		$Wallpaper.color = Color(0.06, 0.09, 0.16)

	# Viñeta superior/inferior
	_add_vignette()

	if has_node("CenterPanel"):
		var ps := StyleBoxFlat.new()
		ps.bg_color = Color(0.12, 0.14, 0.20, 0.94)
		ps.border_width_left = 1
		ps.border_width_top = 1
		ps.border_width_right = 1
		ps.border_width_bottom = 1
		ps.border_color = Color(0.35, 0.5, 0.85, 0.55)
		ps.set_corner_radius_all(12)
		ps.shadow_color = Color(0, 0, 0, 0.45)
		ps.shadow_size = 16
		ps.content_margin_left = 8
		ps.content_margin_right = 8
		$CenterPanel.add_theme_stylebox_override("panel", ps)

	if title_label:
		title_label.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
		title_label.add_theme_font_size_override("font_size", 44)
		title_label.add_theme_color_override("font_outline_color", Color(0.15, 0.35, 0.8, 0.6))
		title_label.add_theme_constant_override("outline_size", 3)
	if subtitle_label:
		subtitle_label.add_theme_color_override("font_color", Color(0.55, 0.65, 0.8))
		subtitle_label.add_theme_font_size_override("font_size", 17)
		subtitle_label.text = "Treinta días. Una deuda. Ninguna segunda oportunidad."

	for btn in [btn_play, btn_continue, btn_options, btn_credits, btn_quit]:
		if btn:
			_style_button(btn)
			btn.pivot_offset = Vector2(150, 27)

	if version_label:
		version_label.add_theme_color_override("font_color", Color(0.45, 0.55, 0.7))
		version_label.add_theme_font_size_override("font_size", 13)
		version_label.text = "30 DAYS LEFT  ·  v0.8"

func _add_vignette() -> void:
	if has_node("VignetteTop"):
		return
	var top := ColorRect.new()
	top.name = "VignetteTop"
	top.color = Color(0, 0, 0, 0.45)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 90
	add_child(top)
	move_child(top, 1 if has_node("Wallpaper") else 0)
	var bot := ColorRect.new()
	bot.name = "VignetteBot"
	bot.color = Color(0, 0, 0, 0.5)
	bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bot.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bot.offset_top = -100
	add_child(bot)

func _style_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.18, 0.28, 0.48)
	normal.set_corner_radius_all(8)
	normal.content_margin_left = 18
	normal.content_margin_right = 18
	normal.content_margin_top = 12
	normal.content_margin_bottom = 12
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.border_color = Color(0.4, 0.55, 0.85, 0.45)

	var hover := normal.duplicate()
	hover.bg_color = Color(0.28, 0.42, 0.72)
	hover.border_color = Color(0.55, 0.75, 1.0, 0.7)

	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.12, 0.2, 0.38)

	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.15, 0.16, 0.2)
	disabled.border_color = Color(0.25, 0.25, 0.3, 0.4)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", Color(0.45, 0.48, 0.55))
	btn.add_theme_font_size_override("font_size", 20)
	btn.custom_minimum_size = Vector2(300, 50)
