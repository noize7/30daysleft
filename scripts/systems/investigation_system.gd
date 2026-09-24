extends Node
## =============================================================================
## InvestigationSystem — Cadena narrativa entre Correo, Banco y Archivos
## =============================================================================
## Mantiene el progreso narrativo persistente sin sustituir a EmailSystem/ClueSystem.
## Los otros sistemas solo notifican acciones; este sistema decide qué se descubre.

signal investigation_changed
signal file_unlocked(file_id: String)
signal clue_discovered(clue_id: String)

const STORY_FILES: Array = [
	{
		"id": "meridian_14_05",
		"title": "MERIDIAN_14-05.dat",
		"type": "locked",
		"discover_on": "knows_meridian",
		"unlock_method": "password",
		"password": "217",
		"body": "HOTEL MERIDIAN\n\nHabitación: 217\nHora: 23:47\n\n[ARCHIVO PARCIALMENTE CORRUPTO]\n\nUna segunda marca de tiempo aparece debajo:\n14/05 — 23:51\n\nNo recuerdas haber estado allí."
	},
	{
		"id": "meridian_log",
		"title": "MERIDIAN_LOG.txt",
		"type": "locked",
		"discover_on": "meridian_opened",
		"unlock_method": "flag",
		"requires_flag": "saw_meridian_log_hint",
		"body": "REGISTRO DE ACCESO\n\n23:42 — Entrada\n23:47 — Habitación 217\n23:51 — [BORRADO]\n00:03 — Salida\n\nEl registro termina antes de lo esperado."
	},
	{
		"id": "incident_report",
		"title": "INCIDENT_REPORT.dat",
		"type": "locked",
		"discover_on": "found_receipt",
		"unlock_method": "clue",
		"requires_clue": "clue_receipt",
		"body": "INFORME DEL INCIDENTE\n\nFecha: 14/05\nUbicación: [REDACTADO]\nTestigo: [REDACTADO]\n\nLa última línea fue recuperada:\n\"El sujeto afirmó no recordar la noche anterior.\""
	},
	{
		"id": "memory_fragment",
		"title": "MEMORY_FRAGMENT_01.dat",
		"type": "locked",
		"discover_on": "late_memory",
		"unlock_method": "day",
		"requires_day": 10,
		"body": "FRAGMENTO DE MEMORIA\n\nUna puerta.\nUna luz encendida.\nUna voz diciendo tu nombre.\n\nNo puedes determinar si lo recuerdas o si lo acabas de leer."
	},
	{
		"id": "unknown_log",
		"title": "UNKNOWN_LOG.dat",
		"type": "locked",
		"discover_on": "high_paranoia",
		"unlock_method": "paranoia",
		"requires_paranoia": 70,
		"body": "REGISTRO SIN ORIGEN\n\n23:47 — Te están observando.\n23:48 — Dejaste de buscar.\n23:49 — Volviste a buscar.\n\nNo hay ninguna aplicación abierta que pudiera haber creado este archivo."
	}
]

var discovered_clues: Array[String] = []
var discovered_files: Array[String] = []
var read_files: Array[String] = []
var story_flags: Dictionary = {}
var missed_deadlines: Array[String] = []
var _silent: bool = true

func _ready() -> void:
	if GameManager:
		if not GameManager.day_changed.is_connected(_on_day_changed):
			GameManager.day_changed.connect(_on_day_changed)
		if not GameManager.sanity_changed.is_connected(_on_sanity_changed):
			GameManager.sanity_changed.connect(_on_sanity_changed)
	if EmailSystem and not EmailSystem.emails_changed.is_connected(_on_emails_changed):
		EmailSystem.emails_changed.connect(_on_emails_changed)
	if ClueSystem and not ClueSystem.clues_changed.is_connected(_on_clues_changed):
		ClueSystem.clues_changed.connect(_on_clues_changed)
	if ParanoiaSystem and not ParanoiaSystem.paranoia_changed.is_connected(_on_paranoia_changed):
		ParanoiaSystem.paranoia_changed.connect(_on_paranoia_changed)
	call_deferred("_initial_sync")

func _initial_sync() -> void:
	_rebuild_from_known_state()
	_silent = false

func _on_day_changed(_day: int) -> void:
	_check_missed_deadlines(_day)
	_rebuild_from_known_state()

func _check_missed_deadlines(current_day: int) -> void:
	if EmailSystem == null:
		return
	for mail in EmailSystem.EMAILS:
		var id := str(mail.get("id", ""))
		var deadline := int(mail.get("expires_day", 999))
		if id.is_empty() or deadline >= 999 or current_day <= deadline:
			continue
		if id in EmailSystem.read_ids or id in missed_deadlines:
			continue
		missed_deadlines.append(id)
		_set_flag("missed_" + id, true, true)
	if missed_deadlines.size() > 0 and ParanoiaSystem:
		ParanoiaSystem.register_discovery_event("story")

func _on_sanity_changed(_value: float) -> void:
	_try_unlock_story_files()

func _on_emails_changed() -> void:
	_try_unlock_story_files()

func _on_clues_changed() -> void:
	_try_unlock_story_files()

func _on_paranoia_changed(_level: float) -> void:
	_try_unlock_story_files()

func _rebuild_from_known_state() -> void:
	# Las banderas se reconstruyen de forma determinista a partir del progreso guardado.
	if EmailSystem:
		for id in EmailSystem.read_ids:
			register_email_read(str(id), true)
	if ClueSystem:
		for id in ClueSystem.read_ids:
			register_clue_read(str(id), true)
	_try_unlock_story_files()

func register_email_read(email_id: String, silent: bool = false) -> void:
	match email_id:
		"day3_odd":
			_set_flag("warning_folder", true, silent)
		"day5_memory":
			_set_flag("memory_photo", true, silent)
		"day9_photo_mail":
			_set_flag("recovered_photo", true, silent)
		"day12_bank":
			_set_flag("bank_warning", true, silent)
		"day18_press":
			_set_flag("case_public", true, silent)
		"day19_leak":
			_set_flag("case_leak", true, silent)
		"day20_crisis":
			_set_flag("disk_compromised", true, silent)
		"day25_final":
			_set_flag("escape_route_hint", true, silent)
		"mystery_chain_01":
			_set_flag("knows_meridian", true, silent)
		"mystery_chain_02":
			_set_flag("suspects_bank", true, silent)
		"mystery_chain_03":
			_set_flag("knows_room", true, silent)
		"mystery_chain_04":
			_set_flag("saw_meridian_log_hint", true, silent)
		"mystery_chain_05":
			_set_flag("knows_subject", true, silent)
		"mystery_chain_06":
			_set_flag("late_warning", true, silent)
	_try_unlock_story_files()

func register_clue_read(clue_id: String, silent: bool = false) -> void:
	if clue_id.is_empty():
		return
	if clue_id not in discovered_clues:
		discovered_clues.append(clue_id)
		changed(silent)
	match clue_id:
		"clue_receipt":
			_set_flag("found_receipt", true, silent)
		"clue_photo":
			_set_flag("photo_seen", true, silent)
		"clue_contract":
			_set_flag("contract_seen", true, silent)
		"clue_diary":
			_set_flag("diary_seen", true, silent)
		"clue_key":
			_set_flag("escape_piece", true, silent)
	_try_unlock_story_files()

func register_bank_open() -> void:
	_set_flag("bank_seen", true, false)
	_try_unlock_story_files()

func register_transaction_seen(transaction_id: String) -> void:
	if transaction_id.is_empty():
		return
	_set_flag("tx_seen_" + transaction_id, true, false)
	match transaction_id:
		"meridian_payment":
			_set_flag("knows_meridian", true, false)
			_set_flag("knows_room", true, false)
		"safehouse_payment":
			_set_flag("knows_safehouse", true, false)
	_try_unlock_story_files()
	if EmailSystem and EmailSystem.has_method("check_timed_unlocks"):
		EmailSystem.check_timed_unlocks()

func is_flag_set(flag: String) -> bool:
	return bool(story_flags.get(flag, false))

func set_flag(flag: String, value: bool = true) -> void:
	_set_flag(flag, value, false)

func _set_flag(flag: String, value: bool, silent: bool) -> void:
	if flag.is_empty():
		return
	if bool(story_flags.get(flag, false)) == value:
		return
	story_flags[flag] = value
	if not silent:
		changed(false)

func changed(silent: bool = false) -> void:
	investigation_changed.emit()
	if not silent and not _silent:
		ParanoiaSystem.register_discovery_event("story")

func _try_unlock_story_files() -> void:
	for file_data in STORY_FILES:
		var id := str(file_data.get("id", ""))
		if id.is_empty() or id in discovered_files:
			continue
		if _file_discovery_condition_met(file_data):
			discovered_files.append(id)
			file_unlocked.emit(id)
			investigation_changed.emit()

func _file_discovery_condition_met(file_data: Dictionary) -> bool:
	var flag := str(file_data.get("discover_on", ""))
	match flag:
		"knows_meridian":
			return is_flag_set("knows_meridian")
		"meridian_opened":
			return "meridian_14_05" in read_files
		"found_receipt":
			return is_flag_set("found_receipt")
		"late_memory":
			return GameManager.day >= int(file_data.get("requires_day", 10))
		"high_paranoia":
			return ParanoiaSystem.get_paranoia() >= int(file_data.get("requires_paranoia", 70))
		_:
			return false

func get_visible_story_files() -> Array:
	var result: Array = []
	for file_data in STORY_FILES:
		var id := str(file_data.get("id", ""))
		if id in discovered_files:
			result.append(file_data)
	return result

func get_file(file_id: String) -> Dictionary:
	for file_data in STORY_FILES:
		if str(file_data.get("id", "")) == file_id:
			return file_data.duplicate(true)
	return {}

func is_file_read(file_id: String) -> bool:
	return file_id in read_files

func try_open_file(file_id: String, supplied_password: String = "") -> Dictionary:
	var file_data := get_file(file_id)
	if file_data.is_empty():
		return {"ok": false, "message": "Archivo no encontrado."}
	if file_id not in discovered_files:
		return {"ok": false, "message": "El archivo todavía no aparece."}
	var method := str(file_data.get("unlock_method", "flag"))
	match method:
		"password":
			var expected := str(file_data.get("password", ""))
			if supplied_password.strip_edges() != expected:
				return {"ok": false, "message": "Contraseña incorrecta."}
		"clue":
			var req := str(file_data.get("requires_clue", ""))
			if not is_flag_set("found_receipt") and req != "":
				return {"ok": false, "message": "Todavía falta una pista relacionada."}
		"day":
			if GameManager.day < int(file_data.get("requires_day", 1)):
				return {"ok": false, "message": "El archivo todavía no puede recuperarse."}
		"paranoia":
			if ParanoiaSystem.get_paranoia() < int(file_data.get("requires_paranoia", 70)):
				return {"ok": false, "message": "El archivo todavía no es accesible."}
	if file_id not in read_files:
		read_files.append(file_id)
		if file_id == "meridian_14_05":
			_set_flag("meridian_opened", true, false)
			_set_flag("saw_meridian_log_hint", true, false)
		if file_id == "meridian_log":
			_set_flag("meridian_log_seen", true, false)
		investigation_changed.emit()
		if EmailSystem and EmailSystem.has_method("check_timed_unlocks"):
			EmailSystem.check_timed_unlocks()
		ParanoiaSystem.register_discovery_event("file")
	return {"ok": true, "message": str(file_data.get("body", "")), "title": str(file_data.get("title", ""))}

func get_save_data() -> Dictionary:
	return {
		"discovered_clues": discovered_clues.duplicate(),
		"discovered_files": discovered_files.duplicate(),
		"read_files": read_files.duplicate(),
		"story_flags": story_flags.duplicate(true),
		"missed_deadlines": missed_deadlines.duplicate()
	}

func load_save_data(data: Dictionary) -> void:
	discovered_clues.clear()
	discovered_files.clear()
	read_files.clear()
	story_flags.clear()
	missed_deadlines.clear()
	for id in data.get("discovered_clues", []):
		discovered_clues.append(str(id))
	for id in data.get("discovered_files", []):
		discovered_files.append(str(id))
	for id in data.get("read_files", []):
		read_files.append(str(id))
	for id in data.get("missed_deadlines", []):
		missed_deadlines.append(str(id))
	var flags = data.get("story_flags", {})
	if flags is Dictionary:
		story_flags = flags.duplicate(true)
	_try_unlock_story_files()
	investigation_changed.emit()

func reset() -> void:
	discovered_clues.clear()
	discovered_files.clear()
	read_files.clear()
	story_flags.clear()
	missed_deadlines.clear()
	_silent = true
	_try_unlock_story_files()
	investigation_changed.emit()
	call_deferred("_enable")

func _enable() -> void:
	_silent = false
