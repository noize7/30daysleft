extends Node
## =============================================================================
## SoundSystem — Controlador central de SFX (Autoload)
##
## Cómo asignar sonidos (IMPORTANTE):
##   1. En el FileSystem, abre: res://scenes/systems/sound_system.tscn
##   2. Selecciona el nodo raíz "SoundSystem".
##   3. En el Inspector verás todos los grupos (Clicks, PC Power, Glitch…).
##   4. Arrastra tus .wav / .ogg / .mp3 a cada casilla y ajusta volúmenes.
##   5. Guarda la escena (Ctrl+S). Los valores quedan en el autoload.
##
## Arquitectura de reproducción (para que no se corten entre sí):
##   • Power on/off  → player dedicado (nunca lo mata el typewriter ni clicks)
##   • Typewriter    → player dedicado (se reinicia solo a sí mismo)
##   • Resto (click, glitch, misc) → pool de polyfonía independiente
## =============================================================================

signal sfx_played(category: String)

# -----------------------------------------------------------------------------
# EXPORTS — asigna los sonidos aquí en el Inspector
# -----------------------------------------------------------------------------
@export_group("Clicks / UI")
## Click principal (iconos del escritorio, etc.)
@export var sfx_click: AudioStream
## Click más suave (opcional; si está vacío se usa sfx_click)
@export var sfx_click_soft: AudioStream
## Click de botón genérico (Continuar, menús…)
@export var sfx_button: AudioStream
## Volumen de esta categoría (0 = silencio, 1 = máximo)
@export_range(0.0, 1.0, 0.01) var volume_click: float = 0.75

@export_group("PC Power")
## Sonido al encender la PC (arranque)
@export var sfx_power_on: AudioStream
## Sonido al apagar la PC (fin de día / batería 0)
@export var sfx_power_off: AudioStream
## Volumen lineal de encendido/apagado (1.0 = máximo de la categoría)
@export_range(0.0, 1.0, 0.01) var volume_power: float = 1.0
## Extra de volumen en dB solo para power (sube si aún se oye bajo)
@export_range(0.0, 12.0, 0.5) var power_boost_db: float = 7.0

@export_group("Diálogo / Typewriter")
## Sonido corto por letra (o cada N letras) mientras escribe el texto
@export var sfx_typewriter: AudioStream
## Volumen del typewriter (suele ir más bajo que clicks)
@export_range(0.0, 1.0, 0.01) var volume_typewriter: float = 0.45
## Cada cuántas letras se reproduce el sonido (1 = cada letra, 2–3 = más suave)
@export_range(1, 6, 1) var typewriter_every_n_chars: int = 2

@export_group("Glitch / Sanity")
## Lista de sonidos de glitch (se elige uno al azar cada vez)
@export var sfx_glitch: Array[AudioStream] = []
## Volumen de glitches (suele ir más bajo)
@export_range(0.0, 1.0, 0.01) var volume_glitch: float = 0.50
## Probabilidad de reproducir un glitch cuando SanityFX lo pide (0–1)
@export_range(0.0, 1.0, 0.01) var glitch_chance: float = 0.40
## Tiempo mínimo entre dos glitches (evita spam)
@export_range(0.05, 2.0, 0.05) var glitch_cooldown: float = 0.35

@export_group("Otros")
@export var sfx_notification: AudioStream
@export var sfx_error: AudioStream
@export var sfx_success: AudioStream
@export_range(0.0, 1.0, 0.01) var volume_misc: float = 0.70

@export_group("General")
## Multiplicador global de todos los SFX (además del bus SFX / Master)
@export_range(0.0, 1.0, 0.01) var master_sfx_scale: float = 1.0
## Máximo de sonidos del pool general (clicks/glitch/misc). Power y typewriter NO cuentan.
@export_range(1, 16, 1) var max_polyphony: int = 10
## Bus de audio (debe existir en el proyecto; si no, usa Master)
@export var audio_bus: String = "SFX"

# -----------------------------------------------------------------------------
# Players dedicados + pool general (no se pisan entre categorías)
# -----------------------------------------------------------------------------
var _pool: Array[AudioStreamPlayer] = []
var _power_player: AudioStreamPlayer = null
var _type_player: AudioStreamPlayer = null
var _glitch_cd: float = 0.0
var _bus_name: String = "Master"
## Último estado conocido de la PC (evita SFX en reset / nueva partida)
var _was_pc_on: bool = false

func _ready() -> void:
	# Se pausa con Escape (typewriter/glitch no siguen en pausa)
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_resolve_bus()
	_power_player = _make_player("PowerPlayer")
	_type_player = _make_player("TypewriterPlayer")
	if GameManager:
		_was_pc_on = GameManager.is_pc_on
		if not GameManager.pc_powered_changed.is_connected(_on_pc_powered):
			GameManager.pc_powered_changed.connect(_on_pc_powered)

func _process(delta: float) -> void:
	if _glitch_cd > 0.0:
		_glitch_cd = maxf(0.0, _glitch_cd - delta)

func _resolve_bus() -> void:
	if AudioServer.get_bus_index(audio_bus) >= 0:
		_bus_name = audio_bus
	else:
		_bus_name = "Master"

func _make_player(node_name: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = node_name
	p.bus = _bus_name
	add_child(p)
	return p

# =============================================================================
# API pública
# =============================================================================

## Click de icono / UI principal
func play_click(soft: bool = false) -> void:
	var stream: AudioStream = sfx_click_soft if soft and sfx_click_soft else sfx_click
	if stream == null:
		stream = sfx_click
	_play_pooled(stream, volume_click, "click")

## Click de botón (diálogos, menús)
func play_button() -> void:
	var stream: AudioStream = sfx_button if sfx_button else sfx_click
	_play_pooled(stream, volume_click, "button")

## Encender PC — player dedicado, no lo corta el typewriter ni otros SFX
func play_power_on() -> void:
	_play_dedicated(_power_player, sfx_power_on, volume_power, "power_on", power_boost_db)

## Espera a que termine el sonido de encendido (para no solapar con diálogos).
## Si no hay stream o no está sonando, vuelve al instante.
func wait_power_on_finished() -> void:
	if _power_player == null or sfx_power_on == null:
		return
	# Dar un frame para que play() arranque
	await get_tree().process_frame
	if not is_instance_valid(_power_player) or not _power_player.playing:
		# Fallback: duración del stream si no llegó a marcar playing
		var dur := _stream_duration(sfx_power_on)
		if dur > 0.05:
			await get_tree().create_timer(dur).timeout
		return
	await _power_player.finished

func _stream_duration(stream: AudioStream) -> float:
	if stream == null:
		return 0.0
	if stream.has_method("get_length"):
		return maxf(0.0, float(stream.get_length()))
	return 0.0

## Apagar PC — player dedicado
func play_power_off() -> void:
	_play_dedicated(_power_player, sfx_power_off, volume_power, "power_off", power_boost_db)

## Tick del typewriter — player dedicado (solo se reinicia a sí mismo)
func play_typewriter() -> void:
	_play_dedicated(_type_player, sfx_typewriter, volume_typewriter, "typewriter")

## Efecto glitch (aleatorio de la lista, con cooldown y probabilidad)
func play_glitch(force: bool = false) -> void:
	if sfx_glitch.is_empty():
		return
	if not force:
		if _glitch_cd > 0.0:
			return
		if randf() > glitch_chance:
			return
	_glitch_cd = glitch_cooldown
	var stream: AudioStream = sfx_glitch[randi() % sfx_glitch.size()]
	_play_pooled(stream, volume_glitch, "glitch")

func play_notification() -> void:
	_play_pooled(sfx_notification, volume_misc, "notification")

func play_error() -> void:
	_play_pooled(sfx_error, volume_misc, "error")

func play_success() -> void:
	_play_pooled(sfx_success, volume_misc, "success")

func play_custom(stream: AudioStream, volume_scale: float = 1.0) -> void:
	_play_pooled(stream, volume_misc * volume_scale, "custom")

func set_category_volume(category: String, linear: float) -> void:
	linear = clampf(linear, 0.0, 1.0)
	match category:
		"click", "ui":
			volume_click = linear
		"power":
			volume_power = linear
		"glitch":
			volume_glitch = linear
		"misc":
			volume_misc = linear
		"typewriter", "dialogue":
			volume_typewriter = linear
		"master":
			master_sfx_scale = linear

# =============================================================================
# Interno
# =============================================================================

func _on_pc_powered(is_on: bool) -> void:
	if is_on:
		if not _was_pc_on:
			play_power_on()
		_was_pc_on = true
	else:
		var suppress := false
		if GameManager:
			suppress = GameManager.suppress_shutdown
		if _was_pc_on and not suppress:
			play_power_off()
		_was_pc_on = false

func sync_pc_state(is_on: bool) -> void:
	_was_pc_on = is_on

## Player fijo: no toca el pool ni a otros dedicados
func _play_dedicated(player: AudioStreamPlayer, stream: AudioStream, category_vol: float, category: String, boost_db: float = 0.0) -> void:
	if player == null or stream == null:
		return
	if master_sfx_scale <= 0.001 or category_vol <= 0.001:
		return
	player.bus = _bus_name
	player.stream = stream
	player.volume_db = _to_db(category_vol) + boost_db
	player.play()
	sfx_played.emit(category)

## Pool general: solo se pisan entre ellos, nunca a power/typewriter
func _play_pooled(stream: AudioStream, category_vol: float, category: String, boost_db: float = 0.0) -> void:
	if stream == null:
		return
	if master_sfx_scale <= 0.001 or category_vol <= 0.001:
		return
	_cleanup_pool()
	var db: float = _to_db(category_vol) + boost_db

	# Reutilizar uno libre del pool
	for p in _pool:
		if is_instance_valid(p) and not p.playing:
			p.stream = stream
			p.volume_db = db
			p.bus = _bus_name
			p.play()
			sfx_played.emit(category)
			return

	# Crear nuevo si hay sitio
	if _pool.size() < max_polyphony:
		var player := AudioStreamPlayer.new()
		player.stream = stream
		player.volume_db = db
		player.bus = _bus_name
		player.finished.connect(_on_pool_finished.bind(player))
		add_child(player)
		_pool.append(player)
		player.play()
		sfx_played.emit(category)
		return

	# Pool lleno: reutilizar el más antiguo del pool (NO toca power/typewriter)
	var oldest: AudioStreamPlayer = _pool[0]
	if not is_instance_valid(oldest):
		_pool.remove_at(0)
		_play_pooled(stream, category_vol, category, boost_db)
		return
	oldest.stop()
	oldest.stream = stream
	oldest.volume_db = db
	oldest.bus = _bus_name
	oldest.play()
	_pool.remove_at(0)
	_pool.append(oldest)
	sfx_played.emit(category)

func _to_db(category_vol: float) -> float:
	var linear: float = clampf(category_vol * master_sfx_scale, 0.0001, 1.0)
	return linear_to_db(linear)

func _on_pool_finished(player: AudioStreamPlayer) -> void:
	# Se deja en el pool para reutilizar; no se borra al terminar
	pass

func _cleanup_pool() -> void:
	var alive: Array[AudioStreamPlayer] = []
	for p in _pool:
		if is_instance_valid(p):
			alive.append(p)
	_pool = alive
