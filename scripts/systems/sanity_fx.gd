extends CanvasLayer
## =============================================================================
## SanityFX — Viñeta + barras glitch + shader de distorsión (cordura baja)
## =============================================================================

var _vignette: ColorRect = null
var _glitch_bar: ColorRect = null
var _shader_rect: ColorRect = null
var _noise_timer: float = 0.0
var _shake_timer: float = 0.0
var _enabled: bool = true
var _shader_mat: ShaderMaterial = null

func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_nodes()
	if GameManager:
		GameManager.sanity_changed.connect(_on_sanity)
		_on_sanity(GameManager.sanity)

func _build_nodes() -> void:
	_vignette = ColorRect.new()
	_vignette.name = "Vignette"
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.color = Color(0.15, 0.0, 0.05, 0.0)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vignette)

	_shader_rect = ColorRect.new()
	_shader_rect.name = "ShaderGlitch"
	_shader_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shader_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Blanco opaco: el shader escribe COLOR con alpha según intensity (glitch RGB)
	_shader_rect.color = Color(1, 1, 1, 1)
	var sh: Shader = load("res://shaders/sanity_glitch.gdshader") as Shader
	if sh:
		_shader_mat = ShaderMaterial.new()
		_shader_mat.shader = sh
		_shader_mat.set_shader_parameter("intensity", 0.0)
		_shader_rect.material = _shader_mat
	add_child(_shader_rect)

	_glitch_bar = ColorRect.new()
	_glitch_bar.name = "GlitchBar"
	_glitch_bar.color = Color(0.9, 0.9, 1.0, 0.0)
	_glitch_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glitch_bar.size = Vector2(0, 0)
	add_child(_glitch_bar)

func _on_sanity(s: float) -> void:
	if not _enabled or _vignette == null:
		return
	var t: float = 0.0
	if s < 70.0:
		t = clampf((70.0 - s) / 70.0, 0.0, 1.0)
	_vignette.color = Color(0.12 + t * 0.25, 0.0, 0.05, t * 0.4)
	if _shader_mat:
		var si: float = 0.0
		if s < 60.0:
			si = clampf((60.0 - s) / 60.0, 0.0, 1.0)
		# Intensidad moderada (antes 0.85 era demasiado fuerte a cordura baja)
		_shader_mat.set_shader_parameter("intensity", si * 0.42)

func _process(delta: float) -> void:
	if not _enabled or not GameManager:
		_hide_fx()
		return
	if not GameManager.is_pc_on or GameManager.is_game_over:
		_hide_fx()
		return
	var s: float = GameManager.sanity
	_on_sanity(s)
	if s >= 55.0:
		if _glitch_bar:
			_glitch_bar.color.a = 0.0
		return
	var intensity: float = clampf((55.0 - s) / 55.0, 0.0, 1.0)
	_noise_timer -= delta
	if _noise_timer <= 0.0:
		_noise_timer = randf_range(0.25, 1.4) * (1.15 - intensity * 0.6)
		_flash_glitch(intensity)
		if intensity > 0.55 and randf() < 0.35:
			_shake_timer = randf_range(0.08, 0.2)
		# Partículas de “estática / polvo” cuando la cordura baja
		if VFXSystem and intensity > 0.25 and randf() < 0.45 + intensity * 0.4:
			var vp := get_viewport().get_visible_rect().size
			var origin := Vector2(randf() * vp.x, randf() * vp.y)
			var col := Color(0.75, 0.55, 0.9, 0.55) if intensity > 0.5 else Color(0.65, 0.7, 0.85, 0.45)
			VFXSystem.spawn_dust(origin, 3 + int(intensity * 5), col)
	if _shake_timer > 0.0:
		_shake_timer -= delta
		if _shader_mat:
			# Picos de glitch suaves (antes llegaba casi a 1.3 y era demasiado)
			_shader_mat.set_shader_parameter("intensity", intensity * (0.38 + randf() * 0.18))

func _hide_fx() -> void:
	if _glitch_bar:
		_glitch_bar.color.a = 0.0
	if _shader_mat:
		_shader_mat.set_shader_parameter("intensity", 0.0)

func _flash_glitch(intensity: float) -> void:
	if _glitch_bar == null:
		return
	var vp := get_viewport().get_visible_rect().size
	if vp.x <= 0.0:
		return
	# Varias bandas a veces
	var bands: int = 1 + (1 if intensity > 0.5 and randf() < 0.5 else 0)
	for _i in range(bands):
		var h: float = randf_range(3.0, 14.0 + intensity * 36.0)
		var y: float = randf_range(0.0, maxf(1.0, vp.y - h))
		var bar := _glitch_bar if _i == 0 else _glitch_bar.duplicate()
		if _i > 0:
			add_child(bar)
		bar.position = Vector2(randf_range(-8.0, 8.0) * intensity, y)
		bar.size = Vector2(vp.x + 20.0, h)
		bar.color = Color(
			randf_range(0.65, 1.0),
			randf_range(0.15, 0.55) * intensity,
			randf_range(0.45, 1.0),
			0.14 + intensity * 0.32
		)
		var tw := create_tween()
		tw.tween_property(bar, "color:a", 0.0, randf_range(0.04, 0.2))
		if _i > 0:
			tw.tween_callback(bar.queue_free)
	# SFX de glitch (con cooldown / probabilidad internos en SoundSystem)
	if SoundSystem and intensity > 0.15:
		SoundSystem.play_glitch()
