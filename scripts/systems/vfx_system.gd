extends CanvasLayer
## VFXSystem — orbes y anillos suaves (sin cuadrados)

const LAYER := 90

func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	if GameManager:
		# Sincronizar estado actual para NO spamear carteles al cargar/encender
		_last_job_level = int(GameManager.job_level)
		_last_money = float(GameManager.money)
		_last_sanity = float(GameManager.sanity)
		_bootstrapped = true
		if not GameManager.money_changed.is_connected(_on_money_changed):
			GameManager.money_changed.connect(_on_money_changed)
		if not GameManager.sanity_changed.is_connected(_on_sanity_changed):
			GameManager.sanity_changed.connect(_on_sanity_changed)
		if not GameManager.job_level_changed.is_connected(_on_job_level):
			GameManager.job_level_changed.connect(_on_job_level)

var _last_money: float = -1.0
var _last_sanity: float = -1.0
var _bootstrapped: bool = false
var _last_job_level: int = -1

func _on_money_changed(m: float) -> void:
	if not _bootstrapped:
		_last_money = m
		_bootstrapped = true
		return
	var delta: float = m - _last_money
	_last_money = m
	if delta > 0.5:
		var vp := get_viewport().get_visible_rect().size
		spawn_floating_text("+$%.0f" % delta, Vector2(vp.x * 0.5, vp.y * 0.35), Color(0.45, 0.95, 0.55), 26)
		spawn_soft_burst(Vector2(vp.x * 0.5, vp.y * 0.4), mini(10, int(delta / 80.0) + 3), Color(0.5, 1.0, 0.55, 0.7))
		flash_screen(Color(0.35, 0.9, 0.45, 0.1), 0.18)
	elif delta < -0.5:
		var vp2 := get_viewport().get_visible_rect().size
		spawn_floating_text("-$%.0f" % absf(delta), Vector2(vp2.x * 0.5, vp2.y * 0.35), Color(0.95, 0.4, 0.35), 24)

func _on_sanity_changed(s: float) -> void:
	if _last_sanity < 0.0:
		_last_sanity = s
		return
	var d: float = s - _last_sanity
	_last_sanity = s
	if d < -2.0:
		var vp := get_viewport().get_visible_rect().size
		spawn_floating_text("Cordura %.0f" % d, Vector2(vp.x * 0.5, vp.y * 0.28), Color(0.75, 0.4, 0.9), 20)
		flash_screen(Color(0.5, 0.08, 0.18, 0.14), 0.22)

func _on_job_level(level: int) -> void:
	# Ignorar sync de carga/reset/encendido: solo subida real
	if level <= 1:
		_last_job_level = maxi(_last_job_level, level)
		return
	if level <= _last_job_level:
		return
	_last_job_level = level
	var vp := get_viewport().get_visible_rect().size
	spawn_floating_text("¡NIVEL %d!" % level, Vector2(vp.x * 0.5, vp.y * 0.32), Color(1.0, 0.88, 0.35), 32)
	flash_screen(Color(1.0, 0.9, 0.35, 0.15), 0.28)
	spawn_soft_burst(Vector2(vp.x * 0.5, vp.y * 0.38), 14, Color(1.0, 0.9, 0.4, 0.75))


func spawn_floating_text(text: String, pos: Vector2, color: Color = Color.WHITE, font_size: int = 24) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.z_index = 100
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.position = pos - Vector2(90, 0)
	lbl.size = Vector2(280, 48)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(lbl)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", pos.y - 64.0, 1.0).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.0).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(lbl.queue_free)

func flash_screen(color: Color, duration: float = 0.25) -> void:
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.z_index = 50
	add_child(rect)
	var tw := create_tween()
	tw.tween_property(rect, "color:a", 0.0, duration).set_ease(Tween.EASE_IN)
	tw.tween_callback(rect.queue_free)

func _orb(color: Color, radius: float) -> Panel:
	var p := Panel.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.z_index = 80
	p.size = Vector2(radius * 2.0, radius * 2.0)
	var st := StyleBoxFlat.new()
	st.bg_color = color
	st.set_corner_radius_all(int(ceil(radius * 2.0)))
	p.add_theme_stylebox_override("panel", st)
	return p

func _ring(color: Color, start_r: float) -> Panel:
	var p := Panel.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.z_index = 79
	p.size = Vector2(start_r * 2.0, start_r * 2.0)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0, 0, 0, 0)
	st.border_width_left = 2
	st.border_width_top = 2
	st.border_width_right = 2
	st.border_width_bottom = 2
	st.border_color = color
	st.set_corner_radius_all(int(ceil(start_r * 2.0)))
	p.add_theme_stylebox_override("panel", st)
	return p

func spawn_soft_burst(origin: Vector2, count: int = 8, color: Color = Color(1.0, 0.9, 0.4, 0.7)) -> void:
	for i in range(count):
		var r: float = randf_range(2.5, 5.5)
		var c: Color = color
		c.a *= randf_range(0.5, 1.0)
		var p := _orb(c, r)
		p.position = origin - p.size * 0.5
		add_child(p)
		var ang: float = randf() * TAU
		var dist: float = randf_range(28.0, 90.0)
		var target: Vector2 = origin + Vector2(cos(ang), sin(ang)) * dist - p.size * 0.5
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(p, "position", target, randf_range(0.35, 0.65)).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "modulate:a", 0.0, randf_range(0.35, 0.65)).set_ease(Tween.EASE_IN)
		tw.tween_property(p, "scale", Vector2(0.3, 0.3), randf_range(0.35, 0.65))
		tw.chain().tween_callback(p.queue_free)
	var ring := _ring(Color(color.r, color.g, color.b, 0.55), 8.0)
	ring.position = origin - ring.size * 0.5
	add_child(ring)
	var tw2 := create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(ring, "scale", Vector2(3.2, 3.2), 0.4).set_ease(Tween.EASE_OUT)
	tw2.tween_property(ring, "modulate:a", 0.0, 0.4)
	tw2.chain().tween_callback(ring.queue_free)

func spawn_coin_burst(origin: Vector2, count: int = 8) -> void:
	spawn_soft_burst(origin, count, Color(1.0, 0.88, 0.35, 0.75))

func spawn_dust(origin: Vector2, count: int = 6, color: Color = Color(0.7, 0.7, 0.85, 0.5)) -> void:
	for i in range(count):
		var p := _orb(color, randf_range(1.5, 3.0))
		p.position = origin + Vector2(randf_range(-24, 24), randf_range(-16, 16))
		add_child(p)
		var target: Vector2 = p.position + Vector2(randf_range(-30, 30), randf_range(-50, -8))
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(p, "position", target, randf_range(0.55, 1.2)).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "modulate:a", 0.0, randf_range(0.5, 1.1))
		tw.chain().tween_callback(p.queue_free)

func spawn_sparkles(origin: Vector2, count: int = 8) -> void:
	var palette := [
		Color(0.55, 0.8, 1.0, 0.85),
		Color(0.75, 0.9, 1.0, 0.7),
		Color(0.95, 0.95, 1.0, 0.6),
		Color(0.45, 0.7, 0.95, 0.75),
	]
	for i in range(count):
		var c: Color = palette[i % palette.size()]
		var p := _orb(c, randf_range(1.8, 3.8))
		p.position = origin - p.size * 0.5
		add_child(p)
		var ang: float = randf() * TAU
		var dest: Vector2 = origin + Vector2(cos(ang), sin(ang)) * randf_range(18.0, 55.0) - p.size * 0.5
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(p, "position", dest, randf_range(0.25, 0.5)).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "modulate:a", 0.0, randf_range(0.25, 0.5))
		tw.tween_property(p, "scale", Vector2(0.2, 0.2), randf_range(0.25, 0.5))
		tw.chain().tween_callback(p.queue_free)
	if count >= 5:
		var ring := _ring(Color(0.6, 0.8, 1.0, 0.45), 6.0)
		ring.position = origin - ring.size * 0.5
		add_child(ring)
		var twr := create_tween()
		twr.set_parallel(true)
		twr.tween_property(ring, "scale", Vector2(2.5, 2.5), 0.3).set_ease(Tween.EASE_OUT)
		twr.tween_property(ring, "modulate:a", 0.0, 0.3)
		twr.chain().tween_callback(ring.queue_free)

func spawn_toast(text: String, duration: float = 2.2, color: Color = Color(0.95, 0.95, 1.0)) -> void:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = 120
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.08, 0.1, 0.15, 0.92)
	st.set_corner_radius_all(10)
	st.content_margin_left = 16
	st.content_margin_right = 16
	st.content_margin_top = 9
	st.content_margin_bottom = 9
	st.border_width_left = 1
	st.border_width_top = 1
	st.border_width_right = 1
	st.border_width_bottom = 1
	st.border_color = Color(0.4, 0.55, 0.8, 0.5)
	panel.add_theme_stylebox_override("panel", st)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", color)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(lbl)
	add_child(panel)
	await get_tree().process_frame
	var vp := get_viewport().get_visible_rect().size
	panel.size = lbl.size + Vector2(32, 18)
	panel.position = Vector2((vp.x - panel.size.x) * 0.5, vp.y - 88)
	panel.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.15)
	tw.tween_interval(duration)
	tw.tween_property(panel, "modulate:a", 0.0, 0.25)
	tw.tween_callback(panel.queue_free)
