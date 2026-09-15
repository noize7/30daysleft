extends Node
## =============================================================================
## ClueSystem — Pistas y memorias (Autoload)  [FASE 5 + FASE 4 RAM]
##
## Las pistas se desbloquean por día. Las marcadas hidden=true requieren
## RAM 8GB (UpgradeSystem.has_hidden_files_access).
## Leerlas recupera memoria (+cordura) y cuenta para el final Escape.
## =============================================================================

signal clues_changed

## "type" define qué icono pequeño se muestra junto al título en el explorador
## (ver TYPE_ICON_PATHS en scripts/apps/files_app.gd).
const CLUES: Array = [
	{
		"id": "clue_photo",
		"unlock_day": 5,
		"hidden": false,
		"type": "photo",
		"title": "Foto rota",
		"body": "Una fotografia antigua, cortada a la mitad.\nSolo se ve una mano y parte de una sonrisa.\nEn el reverso: una fecha borrosa."
	},
	{
		"id": "clue_message",
		"unlock_day": 8,
		"hidden": false,
		"type": "text",
		"title": "Mensaje eliminado",
		"body": "Fragmento recuperado del disco:\n«…no fue un accidente. Guarda el dinero y…»\nEl resto esta sobreescrito."
	},
	{
		"id": "clue_audio",
		"unlock_day": 7,
		"hidden": false,
		"type": "audio",
		"title": "Grabacion de voz",
		"body": "Un audio de 6 segundos, muy distorsionado.\nSe escucha una respiracion agitada y una frase:\n«...no mires atras...»"
	},
	{
		"id": "clue_receipt",
		"unlock_day": 10,
		"hidden": false,
		"type": "document",
		"title": "Recibo extraño",
		"body": "Un recibo de un local que no reconoces.\nFecha: la noche del incidente.\nMonto pagado en efectivo, sin firma."
	},
	{
		"id": "clue_medical",
		"unlock_day": 12,
		"hidden": true,
		"type": "medical",
		"title": "[OCULTO] Archivo medico",
		"body": "Ingreso hospitalario. Causa: trauma craneal / amnesia.\nAlta voluntaria. Sin seguimiento.\nNombre del paciente: ilegible.\n\n(Requiere RAM 8GB para leer este sector.)"
	},
	{
		"id": "clue_diary",
		"unlock_day": 14,
		"hidden": false,
		"type": "text",
		"title": "Pagina de diario",
		"body": "«...no se si lo que recuerdo paso de verdad.\nCada dia la historia cambia un poco.\nTengo miedo de llegar al dia 30 y no saber quien soy.»"
	},
	{
		"id": "clue_text",
		"unlock_day": 18,
		"hidden": false,
		"type": "text",
		"title": "Texto raro",
		"body": "Notas en un bloc digital:\n«Ellos no buscan justicia. Buscan silencio.»\n«El dia 30 no es un limite. Es una fecha de entrega.»"
	},
	{
		"id": "clue_camera",
		"unlock_day": 20,
		"hidden": true,
		"type": "photo",
		"title": "[OCULTO] Camara oculta",
		"body": "Un archivo de video sin miniatura, 4 segundos.\nSolo se ve una silueta cruzando la puerta.\nLa marca de tiempo no coincide con esa noche.\n\n(Requiere RAM 8GB para leer este sector.)"
	},
	{
		"id": "clue_key",
		"unlock_day": 24,
		"hidden": true,
		"type": "key",
		"title": "[OCULTO] La ultima pieza",
		"body": "Una direccion. Un nombre en clave.\nSi tienes el dinero y has leido el resto,\nya sabes que hacer antes de que lleguen.\n\n(Archivo en carpeta recuerdos/ — solo con RAM 8GB.)"
	},
	{
		"id": "clue_map",
		"unlock_day": 27,
		"hidden": true,
		"type": "key",
		"title": "[OCULTO] Mapa marcado",
		"body": "Un mapa de la ciudad con una ruta marcada a mano\nhasta la frontera. Una nota al margen:\n«Solo si estas seguro. No hay vuelta atras.»\n\n(Requiere RAM 8GB para leer este sector.)"
	},
	# --- Más archivos ---
	{
		"id": "clue_note_early",
		"unlock_day": 3,
		"hidden": false,
		"type": "text",
		"title": "Nota en el escritorio",
		"body": "Escrito a mano:\n«No confíes en todos los correos.»\n«Algunos los inventa tu cabeza.»"
	},
	{
		"id": "clue_corrupted",
		"unlock_day": 6,
		"hidden": false,
		"type": "warning",
		"sanity_delta": -6.0,
		"title": "archivo_corrompido.dat",
		"body": "Al abrirlo solo ves ruido y una frase:\n«YA ESTÁS DENTRO.»\nTe duele la cabeza."
	},
	{
		"id": "clue_list",
		"unlock_day": 9,
		"hidden": false,
		"type": "document",
		"title": "Lista de nombres",
		"body": "Tres nombres tachados.\nEl cuarto es el tuyo… o alguien con el mismo apellido.\nFecha al pie: la noche del incidente."
	},
	{
		"id": "clue_scream",
		"unlock_day": 11,
		"hidden": false,
		"type": "audio",
		"sanity_delta": -5.0,
		"title": "clip_grito.wav",
		"body": "Un segundo de audio.\nNo es un grito de miedo.\nEs de rabia.\nNo quieres escucharlo otra vez."
	},
	{
		"id": "clue_mirror",
		"unlock_day": 13,
		"hidden": true,
		"type": "photo",
		"sanity_delta": -7.0,
		"title": "[OCULTO] Espejo",
		"body": "Una foto del baño.\nEn el cristal hay una silueta de más.\nNo eras tú solo en la habitación.\n\n(RAM 8GB.)"
	},
	{
		"id": "clue_contract",
		"unlock_day": 16,
		"hidden": false,
		"type": "document",
		"title": "Contrato incompleto",
		"body": "Cláusula 7: «El sujeto no recordará…»\nEl resto está quemado.\nFirma ilegible."
	},
	{
		"id": "clue_loop",
		"unlock_day": 19,
		"hidden": false,
		"type": "system",
		"sanity_delta": -4.0,
		"title": "log_reinicio.txt",
		"body": "BOOT… BOOT… BOOT…\nMismo checksum. Mismo día.\n¿Cuántas veces has llegado al 30?"
	},
	{
		"id": "clue_threat",
		"unlock_day": 22,
		"hidden": true,
		"type": "police",
		"sanity_delta": -5.0,
		"title": "[OCULTO] Amenaza",
		"body": "Mensaje sin remitente:\n«Si transferiste el dinero, ya es tarde.»\nPuede ser real. Puede no serlo.\n\n(RAM 8GB.)"
	},
	{
		"id": "clue_last_photo",
		"unlock_day": 26,
		"hidden": true,
		"type": "photo",
		"title": "[OCULTO] La otra mitad",
		"body": "Un fragmento que encaja con la foto rota.\nAún no se ve el rostro completo.\nPero la mano… es la tuya.\n\n(RAM 8GB.)"
	},
]

var unlocked_ids: Array = []
var read_ids: Array = []

const CLUES_NEEDED_FOR_ESCAPE: int = 3

func _ready() -> void:
	GameManager.day_changed.connect(_on_day_changed)
	GameManager.upgrade_changed.connect(_on_upgrade_changed)
	unlock_for_day(1)

func unlock_for_day(day: int) -> void:
	var changed := false
	for clue in CLUES:
		var id: String = str(clue["id"])
		if id in unlocked_ids:
			continue
		if int(clue["unlock_day"]) <= day:
			unlocked_ids.append(id)
			changed = true
	if changed:
		clues_changed.emit()

func _on_day_changed(new_day: int) -> void:
	unlock_for_day(new_day)

## Al mejorar RAM, refrescar UI de archivos (aparecen ocultos).
func _on_upgrade_changed(category: String, _level: int) -> void:
	if category == "ram":
		clues_changed.emit()

## Pistas visibles: desbloqueadas por día y, si son hidden, requieren RAM 8GB.
func get_available() -> Array:
	var result: Array = []
	var can_hidden: bool = UpgradeSystem.has_hidden_files_access()
	for clue in CLUES:
		var id: String = str(clue["id"])
		if id not in unlocked_ids:
			continue
		if bool(clue.get("hidden", false)) and not can_hidden:
			continue
		result.append(clue)
	return result

## Hay pistas ocultas desbloqueadas por día pero bloqueadas por falta de RAM.
func has_locked_hidden() -> bool:
	if UpgradeSystem.has_hidden_files_access():
		return false
	for clue in CLUES:
		if bool(clue.get("hidden", false)) and str(clue["id"]) in unlocked_ids:
			return true
	return false

func mark_read(clue_id: String) -> void:
	if clue_id in read_ids:
		return
	if clue_id not in unlocked_ids:
		return
	var sanity_delta: float = 5.0
	# No permitir leer ocultos sin RAM
	for clue in CLUES:
		if str(clue["id"]) != clue_id:
			continue
		if bool(clue.get("hidden", false)) and not UpgradeSystem.has_hidden_files_access():
			return
		if clue.has("sanity_delta"):
			sanity_delta = float(clue["sanity_delta"])
		break
	read_ids.append(clue_id)
	GameManager.change_sanity(sanity_delta)
	clues_changed.emit()

func is_read(clue_id: String) -> bool:
	return clue_id in read_ids

func read_count() -> int:
	return read_ids.size()

func has_enough_for_escape() -> bool:
	return read_count() >= CLUES_NEEDED_FOR_ESCAPE

## Tanda 8: algunos trabajos pueden desbloquear una pista aleatoria aún no vista.
func try_unlock_random_from_job() -> void:
	var candidates: Array = []
	for clue in CLUES:
		var cid: String = str(clue["id"])
		if cid in unlocked_ids:
			continue
		# Solo pistas no ocultas o si ya tiene acceso a ocultas
		if bool(clue.get("hidden", false)) and not UpgradeSystem.has_hidden_files_access():
			continue
		candidates.append(cid)
	if candidates.is_empty():
		return
	var pick: String = str(candidates[randi() % candidates.size()])
	if pick not in unlocked_ids:
		unlocked_ids.append(pick)
		clues_changed.emit()
