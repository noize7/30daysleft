extends Control
## MusicPlayer — Reproductor de música estilo XP
## UI definida en scenes/apps/music_app.tscn

const TRACKS := [
	{"id": "musica_juego1", "name": "music1", "path": "res://assets/audio/music/musica_juego1.mp3"},
	{"id": "musica_juego2", "name": "music2", "path": "res://assets/audio/music/musica_juego2.ogg"},
	{"id": "musica_juego3", "name": "music3", "path": "res://assets/audio/music/musica_juego3.mp3"},
	{"id": "musica_juego4", "name": "music4", "path": "res://assets/audio/music/musica_juego4.mp3"},
	{"id": "musica_juego5", "name": "music5", "path": "res://assets/audio/music/musica_juego5.mp3"},
]

@onready var _title: Label = $Root/Title
@onready var _list: ItemList = $Root/TrackList
@onready var _btn_prev: Button = $Root/Buttons/BtnPrev
@onready var _btn_play: Button = $Root/Buttons/BtnPlay
@onready var _btn_next: Button = $Root/Buttons/BtnNext
@onready var _status: Label = $Root/Status
@onready var _vol_label: Label = $Root/VolRow/VolLabel
@onready var _volume: HSlider = $Root/VolRow/Volume

var _player: AudioStreamPlayer = null
var _current_idx: int = 0
var _is_playing: bool = false

func _ready() -> void:
	_apply_locale()
	_connect_ui()
	_ensure_player()
	_load_saved_track()
	_refresh_list()
	if GameManager.has_signal("sanity_changed") and not GameManager.sanity_changed.is_connected(_on_sanity):
		GameManager.sanity_changed.connect(_on_sanity)
	if GameManager.has_signal("pc_powered_changed") and not GameManager.pc_powered_changed.is_connected(_on_pc_power):
		GameManager.pc_powered_changed.connect(_on_pc_power)
	if LocaleSystem and not LocaleSystem.language_changed.is_connected(_on_lang):
		LocaleSystem.language_changed.connect(_on_lang)
	if not GameManager.is_pc_on:
		_force_stopped_ui()

func _on_lang(_lang: String) -> void:
	_apply_locale()
	_update_status()

func _apply_locale() -> void:
	if _title:
		_title.text = LocaleSystem.t("music.title", "Reproductor de música") if LocaleSystem else "Reproductor de música"
	if _btn_prev:
		_btn_prev.text = LocaleSystem.t("music.prev", "◀ Anterior") if LocaleSystem else "◀ Anterior"
	if _btn_play:
		_btn_play.text = LocaleSystem.t("music.pause" if _is_playing else "music.play", "❚❚ Pause" if _is_playing else "▶ Play") if LocaleSystem else ("❚❚ Pause" if _is_playing else "▶ Play")
	if _btn_next:
		_btn_next.text = LocaleSystem.t("music.next", "Siguiente ▶") if LocaleSystem else "Siguiente ▶"
	if _vol_label:
		_vol_label.text = LocaleSystem.t("music.volume", "Volumen") if LocaleSystem else "Volumen"
	if _status and not _is_playing and _status.text.find("PC") < 0:
		if _status.text == "Sin pista" or _status.text == "No track":
			_status.text = LocaleSystem.t("music.no_track", "Sin pista") if LocaleSystem else "Sin pista"

func _connect_ui() -> void:
	if _list and not _list.item_selected.is_connected(_on_select):
		_list.item_selected.connect(_on_select)
	if _btn_prev and not _btn_prev.pressed.is_connected(_on_prev_pressed):
		_btn_prev.pressed.connect(_on_prev_pressed)
	if _btn_play and not _btn_play.pressed.is_connected(_on_play_pressed):
		_btn_play.pressed.connect(_on_play_pressed)
	if _btn_next and not _btn_next.pressed.is_connected(_on_next_pressed):
		_btn_next.pressed.connect(_on_next_pressed)
	if _volume and not _volume.value_changed.is_connected(_on_volume):
		_volume.value_changed.connect(_on_volume)

func _on_prev_pressed() -> void:
	if SoundSystem:
		SoundSystem.play_button()
	_prev()

func _on_play_pressed() -> void:
	if SoundSystem:
		SoundSystem.play_button()
	_toggle_play()

func _on_next_pressed() -> void:
	if SoundSystem:
		SoundSystem.play_button()
	_next()

func _on_pc_power(is_on: bool) -> void:
	if not is_on:
		if _player:
			_player.stop()
		_is_playing = false
		_force_stopped_ui()

func _force_stopped_ui() -> void:
	_is_playing = false
	if _btn_play:
		_btn_play.text = LocaleSystem.t("music.play", "▶ Play") if LocaleSystem else "▶ Play"
	if _status:
		_status.text = LocaleSystem.t("music.pc_off", "PC apagada — la música se detuvo.\nEnciende el PC y pulsa Play.") if LocaleSystem else "PC apagada — la música se detuvo.\nEnciende el PC y pulsa Play."
	_refresh_list()

func _ensure_player() -> void:
	var root := get_tree().root
	_player = root.get_node_or_null("MusicPlayerGlobal") as AudioStreamPlayer
	if _player == null:
		_player = AudioStreamPlayer.new()
		_player.name = "MusicPlayerGlobal"
		_player.bus = "Master"
		_player.volume_db = linear_to_db(0.6)
		_player.process_mode = Node.PROCESS_MODE_ALWAYS
		root.add_child(_player)
	if not _player.finished.is_connected(_on_track_finished):
		_player.finished.connect(_on_track_finished)

func _load_stream(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	var res = load(path)
	if res == null:
		push_warning("MusicPlayer: load() devolvió null para %s" % path)
		return null
	if res is AudioStream:
		var stream: AudioStream = res as AudioStream
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

func _refresh_list() -> void:
	if _list == null:
		return
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
		_btn_play.text = LocaleSystem.t("music.pause", "❚❚ Pause") if LocaleSystem else "❚❚ Pause"
		var play_fmt: String = LocaleSystem.t("music.playing", "Sonando: %s  (loop)") if LocaleSystem else "Sonando: %s  (loop)"
		_status.text = play_fmt % str(t["name"])
		_save_track()
		if not _player.playing:
			_status.text = "Stream cargado pero no reproduce. Revisa volumen del sistema / Master."
	else:
		_is_playing = false
		_btn_play.text = LocaleSystem.t("music.play", "▶ Play") if LocaleSystem else "▶ Play"
		var miss_fmt: String = LocaleSystem.t("music.missing_file", "No se encontró: %s\nPon el OGG en assets/audio/music/ y reimporta en Godot.") if LocaleSystem else "No se encontró: %s\nPon el OGG en assets/audio/music/ y reimporta en Godot."
		_status.text = miss_fmt % path.get_file()
		push_warning("MusicPlayer: falta archivo o no importado → %s" % path)
	_refresh_list()

func _pause() -> void:
	if _player:
		_player.stop()
	_is_playing = false
	_btn_play.text = LocaleSystem.t("music.play", "▶ Play") if LocaleSystem else "▶ Play"
	_update_status()
	_refresh_list()

func _prev() -> void:
	_current_idx = (_current_idx - 1 + TRACKS.size()) % TRACKS.size()
	_play_current()

func _next() -> void:
	_current_idx = (_current_idx + 1) % TRACKS.size()
	_play_current()

func _on_track_finished() -> void:
	if _is_playing:
		_play_current()

func _on_volume(v: float) -> void:
	if _player:
		_player.volume_db = linear_to_db(v)

func _on_sanity(s: float) -> void:
	if s < 30.0 and _is_playing and _current_idx != 3 and randf() < 0.08:
		_current_idx = 3
		_play_current()
		_status.text = LocaleSystem.t("music.distorted", "La música se distorsiona… (cordura baja)") if LocaleSystem else "La música se distorsiona… (cordura baja)"

func _update_status() -> void:
	if _status == null:
		return
	var t: Dictionary = TRACKS[_current_idx]
	if _is_playing:
		var play_fmt: String = LocaleSystem.t("music.playing", "Sonando: %s  (loop)") if LocaleSystem else "Sonando: %s  (loop)"
		_status.text = play_fmt % str(t["name"])
	else:
		var pause_fmt: String = LocaleSystem.t("music.paused", "Pausado / Listo: %s") if LocaleSystem else "Pausado / Listo: %s"
		_status.text = pause_fmt % str(t["name"])

func _save_track() -> void:
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
