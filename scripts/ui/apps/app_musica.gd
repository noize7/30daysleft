extends Control
## MusicPlayer — Reproductor de música estilo XP (Tanda 8)
## El jugador elige pistas en loop. Bajo cordura puede distorsionarse.

const TRACKS := [
	{"id": "musica_juego1", "name": "music1", "path": "res://assets/audio/music/musica_juego1.mp3"},
	{"id": "musica_juego2", "name": "music2", "path": "res://assets/audio/music/musica_juego2.ogg"},
	{"id": "musica_juego3", "name": "music3", "path": "res://assets/audio/music/musica_juego3.mp3"},
	{"id": "musica_juego4", "name": "music4", "path": "res://assets/audio/music/musica_juego4.mp3"},
	{"id": "musica_juego5", "name": "music5", "path": "res://assets/audio/music/musica_juego5.mp3"},
]

var _player: AudioStreamPlayer = null
var _current_idx: int = 0
var _is_playing: bool = false
var _list: ItemList = null
var _btn_play: Button = null
var _btn_prev: Button = null
var _btn_next: Button = null
var _status: Label = null
var _volume: HSlider = null

func _ready() -> void:
	_build_ui()
	_ensure_player()
	_load_saved_track()
	_refresh_list()
	if GameManager.has_signal("sanity_changed") and not GameManager.sanity_changed.is_connected(_on_sanity):
		GameManager.sanity_changed.connect(_on_sanity)
	if GameManager.has_signal("pc_powered_changed") and not GameManager.pc_powered_changed.is_connected(_on_pc_power):
		GameManager.pc_powered_changed.connect(_on_pc_power)
	if not GameManager.is_pc_on:
		_force_stopped_ui()

func _on_pc_power(is_on: bool) -> void:
	if not is_on:
		if _player:
			_player.stop()
		_is_playing = false
		_force_stopped_ui()

func _force_stopped_ui() -> void:
	_is_playing = false
	if _btn_play:
		_btn_play.text = "▶ Play"
	if _status:
		_status.text = "PC apagada — la música se detuvo.\nEnciende el PC y pulsa Play."
	_refresh_list()

func _ensure_player() -> void:
	# Usar un player global para que la música persista entre cierres de app
	var root := get_tree().root
	_player = root.get_node_or_null("MusicPlayerGlobal") as AudioStreamPlayer
	if _player == null:
		_player = AudioStreamPlayer.new()
		_player.name = "MusicPlayerGlobal"
		_player.bus = "Master"
		_player.volume_db = linear_to_db(0.6)
		_player.process_mode = Node.PROCESS_MODE_ALWAYS
		root.add_child(_player)
	# Reconectar finished por si el player ya existía
	if not _player.finished.is_connected(_on_track_finished):
		_player.finished.connect(_on_track_finished)

func _load_stream(path: String) -> AudioStream:
	# Carga robusta de OGG/WAV/MP3 y activa loop si es posible
	if not ResourceLoader.exists(path):
		# Intentar sin extensión forzada / rutas alternativas por si el usuario usó otro nombre
		return null
	var res = load(path)
	if res == null:
		push_warning("MusicPlayer: load() devolvió null para %s" % path)
		return null
	if res is AudioStream:
		var stream: AudioStream = res as AudioStream
		# Godot 4: AudioStreamOggVorbis, AudioStreamMP3, AudioStreamWAV tienen loop
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		elif stream is AudioStreamMP3:
			(stream as AudioStreamMP3).loop = true
		elif stream is AudioStreamWAV:
			var wav := stream as AudioStreamWAV
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		return stream
	push_warning("MusicPlayer: el recurso no es AudioStream: %s (%s)" % [path, res])
	return null

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.92, 0.92, 0.88)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := Label.new()
	title.text = "Music Player"
	title.position = Vector2(12, 8)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.1, 0.1, 0.35))
	add_child(title)

	_list = ItemList.new()
	_list.position = Vector2(12, 40)
	_list.size = Vector2(340, 200)
	_list.item_selected.connect(_on_select)
	add_child(_list)

	_btn_prev = Button.new()
	_btn_prev.text = "◀ Anterior"
	_btn_prev.position = Vector2(12, 250)
	_btn_prev.size = Vector2(100, 32)
	_btn_prev.pressed.connect(func():
		if SoundSystem: SoundSystem.play_button()
		_prev()
	)
	add_child(_btn_prev)

	_btn_play = Button.new()
	_btn_play.text = "▶ Play"
	_btn_play.position = Vector2(120, 250)
	_btn_play.size = Vector2(120, 32)
	_btn_play.pressed.connect(func():
		if SoundSystem: SoundSystem.play_button()
		_toggle_play()
	)
	add_child(_btn_play)

	_btn_next = Button.new()
	_btn_next.text = "Siguiente ▶"
	_btn_next.position = Vector2(250, 250)
	_btn_next.size = Vector2(100, 32)
	_btn_next.pressed.connect(func():
		if SoundSystem: SoundSystem.play_button()
		_next()
	)
	add_child(_btn_next)

	var vol_lbl := Label.new()
	vol_lbl.text = "Volumen"
	vol_lbl.position = Vector2(12, 295)
	vol_lbl.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
	add_child(vol_lbl)

	_volume = HSlider.new()
	_volume.min_value = 0.0
	_volume.max_value = 1.0
	_volume.step = 0.05
	_volume.value = 0.6
	_volume.position = Vector2(80, 295)
	_volume.size = Vector2(270, 24)
	_volume.value_changed.connect(_on_volume)
	add_child(_volume)

	_status = Label.new()
	_status.text = "Sin pista"
	_status.position = Vector2(12, 330)
	_status.size = Vector2(340, 40)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	_status.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15))

func _refresh_list() -> void:
	_list.clear()
	for i in range(TRACKS.size()):
		var t: Dictionary = TRACKS[i]
		var mark: String = "▶ " if i == _current_idx and _is_playing else "   "
		_list.add_item("%s%s" % [mark, str(t["name"])])
	if _current_idx >= 0 and _current_idx < TRACKS.size():
		_list.select(_current_idx)
	_update_status()

func _on_select(idx: int) -> void:
	if idx < 0 or idx >= TRACKS.size():
		return
	_current_idx = idx
	_play_current()

func _toggle_play() -> void:
	if _is_playing:
		_pause()
	else:
		_play_current()

func _play_current() -> void:
	if _player == null:
		_ensure_player()
	if _player == null:
		_status.text = "Error: no hay AudioStreamPlayer"
		return
	var t: Dictionary = TRACKS[_current_idx]
	var path: String = str(t["path"])
	var stream: AudioStream = _load_stream(path)
	if stream:
		_player.stop()
		_player.stream = stream
		_player.volume_db = linear_to_db(clampf(_volume.value, 0.0, 1.0))
		_player.play()
		_is_playing = true
		_btn_play.text = "❚❚ Pause"
		_status.text = "Sonando: %s  (loop)" % str(t["name"])
		_save_track()
		# Debug útil si sigue sin oírse
		if not _player.playing:
			_status.text = "Stream cargado pero no reproduce. Revisa volumen del sistema / Master."
	else:
		# Sin archivo importado: mensaje claro (no fingir audio)
		_is_playing = false
		_btn_play.text = "▶ Play"
		_status.text = "No se encontró: %s\nPon el OGG en assets/audio/music/ y reimporta en Godot." % path.get_file()
		push_warning("MusicPlayer: falta archivo o no importado → %s" % path)
	_refresh_list()

func _pause() -> void:
	if _player:
		_player.stop()
	_is_playing = false
	_btn_play.text = "▶ Play"
	_update_status()
	_refresh_list()

func _prev() -> void:
	_current_idx = (_current_idx - 1 + TRACKS.size()) % TRACKS.size()
	_play_current()

func _next() -> void:
	_current_idx = (_current_idx + 1) % TRACKS.size()
	_play_current()

func _on_track_finished() -> void:
	# Loop infinito de la pista actual
	if _is_playing:
		_play_current()

func _on_volume(v: float) -> void:
	if _player:
		_player.volume_db = linear_to_db(v)

func _on_sanity(s: float) -> void:
	# Bajo cordura: posible cambio forzado a pista de crisis
	if s < 30.0 and _is_playing and _current_idx != 3 and randf() < 0.08:
		_current_idx = 3  # Crisis
		_play_current()
		_status.text = "La música se distorsiona… (cordura baja)"

func _update_status() -> void:
	if _status == null:
		return
	var t: Dictionary = TRACKS[_current_idx]
	if _is_playing:
		_status.text = "Sonando: %s  (loop)" % str(t["name"])
	else:
		_status.text = "Pausado / Listo: %s" % str(t["name"])

func _save_track() -> void:
	# Guardar preferencia simple en user://
	var f := FileAccess.open("user://music_pref.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"track": _current_idx, "vol": _volume.value}))
		f.close()

func _load_saved_track() -> void:
	if not FileAccess.file_exists("user://music_pref.json"):
		return
	var f := FileAccess.open("user://music_pref.json", FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) == TYPE_DICTIONARY:
		_current_idx = clampi(int(data.get("track", 0)), 0, TRACKS.size() - 1)
		if _volume:
			_volume.value = float(data.get("vol", 0.6))
