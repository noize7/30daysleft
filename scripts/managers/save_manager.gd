extends Node
## =============================================================================
## SaveManager — Guardado y carga de partida (Autoload)  [TANDA 4]
##
## Guarda en user://save/game_save.json el estado de GameManager + pistas leídas
## y correos abiertos. Auto-guarda al terminar cada día.
## =============================================================================

const SAVE_DIR := "user://save"
const SAVE_PATH := "user://save/game_save.json"

## True si existe un archivo de guardado.
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

## Serializa el estado actual y lo escribe en disco.
## Devuelve true si se guardó correctamente.
func save_game() -> bool:
	# Crear carpeta si no existe
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)

	var data := {
		"version": 2,
		"day": GameManager.day,
		"money": GameManager.money,
		"sanity": GameManager.sanity,
		"battery": GameManager.battery,
		"max_battery": GameManager.max_battery,
		"suspicion": GameManager.suspicion,
		"job_level": GameManager.job_level,
		"jobs_completed": GameManager.jobs_completed,
		"upgrade_levels": GameManager.upgrade_levels.duplicate(true),
		# Tanda 8: método de pago dual
		"payment_method": GameManager.payment_method,
		# Tanda 4: progreso narrativo
		"unlocked_emails": EmailSystem.unlocked_ids.duplicate() if EmailSystem else [],
		"read_emails": EmailSystem.read_ids.duplicate() if EmailSystem else [],
		"unlocked_clues": ClueSystem.unlocked_ids.duplicate() if ClueSystem else [],
		"read_clues": ClueSystem.read_ids.duplicate() if ClueSystem else [],
		# Posiciones de los iconos del escritorio (arrastrados por el jugador)
		"icon_positions": GameManager.icon_positions.duplicate(true),
		# Escape por transferencia
		"escape_account_day": GameManager.escape_account_day,
		"escape_account_number": GameManager.escape_account_number,
		"escape_transferred": GameManager.escape_transferred,
		"escape_account_sent": GameManager.escape_account_sent,
		# Tutorial + misiones
		"tutorial_done": GameManager.tutorial_done,
		"missions": _safe_mission_save(),
	}

	var json_text := JSON.stringify(data, "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("SaveManager: no se pudo escribir %s" % SAVE_PATH)
		return false
	file.store_string(json_text)
	file.close()
	return true

func _safe_mission_save() -> Dictionary:
	if MissionSystem == null:
		return {}
	if MissionSystem.has_method("get_save_data"):
		var d = MissionSystem.get_save_data()
		if typeof(d) == TYPE_DICTIONARY:
			return d
	return {}

## Carga el guardado y restaura GameManager + sistemas narrativos.
## Devuelve true si se cargó bien.
func load_game() -> bool:
	if not has_save():
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("SaveManager: JSON inválido")
		return false
	var data: Dictionary = parsed

	GameManager.day = int(data.get("day", 1))
	GameManager.money = float(data.get("money", 0.0))
	GameManager.sanity = float(data.get("sanity", 100.0))
	GameManager.max_battery = float(data.get("max_battery", 100.0))
	GameManager.battery = float(data.get("battery", GameManager.max_battery))
	GameManager.suspicion = float(data.get("suspicion", 0.0))
	GameManager.job_level = int(data.get("job_level", 1))
	GameManager.jobs_completed = int(data.get("jobs_completed", 0))

	var ups = data.get("upgrade_levels", {})
	if typeof(ups) == TYPE_DICTIONARY:
		GameManager.upgrade_levels = ups.duplicate(true)
	# Asegurar claves nuevas de Tanda 8
	for key in ["optimizer", "noise_filter", "proxy", "log_cleaner"]:
		if not GameManager.upgrade_levels.has(key):
			GameManager.upgrade_levels[key] = 1

	# Método de pago dual (Tanda 8)
	var pm: String = str(data.get("payment_method", "online"))
	if pm != "cash" and pm != "online":
		pm = "online"
	GameManager.payment_method = pm

	# Narrativa (sin notificaciones al restaurar)
	if EmailSystem:
		EmailSystem._silent_unlock = true
		EmailSystem.unlocked_ids.clear()
		for id in data.get("unlocked_emails", []):
			EmailSystem.unlocked_ids.append(str(id))
		EmailSystem.read_ids.clear()
		for id in data.get("read_emails", []):
			EmailSystem.read_ids.append(str(id))
		EmailSystem.call_deferred("_enable_notifications")

	if ClueSystem:
		ClueSystem._silent_unlock = true
		ClueSystem.unlocked_ids.clear()
		for id in data.get("unlocked_clues", []):
			ClueSystem.unlocked_ids.append(str(id))
		ClueSystem.read_ids.clear()
		for id in data.get("read_clues", []):
			ClueSystem.read_ids.append(str(id))
		ClueSystem.call_deferred("_enable_notifications")

	# Posiciones de los iconos del escritorio
	var ip = data.get("icon_positions", {})
	if typeof(ip) == TYPE_DICTIONARY:
		GameManager.icon_positions = ip.duplicate(true)
	else:
		GameManager.icon_positions = {}

	# Escape por transferencia
	GameManager.escape_account_day = int(data.get("escape_account_day", GameManager.escape_account_day))
	GameManager.escape_account_number = str(data.get("escape_account_number", GameManager.escape_account_number))
	GameManager.escape_transferred = float(data.get("escape_transferred", 0.0))
	GameManager.escape_account_sent = bool(data.get("escape_account_sent", false))
	if GameManager.escape_account_number.is_empty():
		GameManager._roll_escape_account()
	# Reinyectar correo de cuenta si ya se había enviado
	if GameManager.escape_account_sent and EmailSystem:
		EmailSystem.try_send_escape_account(GameManager.day)

	# Tutorial + misiones
	GameManager.tutorial_done = bool(data.get("tutorial_done", false))
	GameManager.tutorial_active = false
	if MissionSystem and data.has("missions") and MissionSystem.has_method("load_save_data"):
		MissionSystem.load_save_data(data["missions"])

	# Notificar UI
	GameManager.day_changed.emit(GameManager.day)
	GameManager.money_changed.emit(GameManager.money)
	GameManager.battery_changed.emit(GameManager.battery)
	GameManager.sanity_changed.emit(GameManager.sanity)
	GameManager.suspicion_changed.emit(GameManager.suspicion)
	GameManager.job_level_changed.emit(GameManager.job_level)
	GameManager.jobs_completed_changed.emit(GameManager.jobs_completed)
	for cat in GameManager.upgrade_levels.keys():
		GameManager.upgrade_changed.emit(str(cat), int(GameManager.upgrade_levels[cat]))

	# Reaplicar capacidad de batería según upgrade
	if UpgradeSystem:
		var bat = UpgradeSystem.get_current("battery")
		if bat and bat.has("capacity"):
			GameManager.max_battery = float(bat["capacity"])
			GameManager.battery = clampf(GameManager.battery, 0.0, GameManager.max_battery)
			GameManager.battery_changed.emit(GameManager.battery)

	return true

## Borra el archivo de guardado (nueva partida).
func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)
