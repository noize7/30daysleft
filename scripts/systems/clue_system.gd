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
		"unlock_hour": 1,
		"unlock_minute": 35,
		"hidden": false,
		"type": "photo",
		"is_true": true,
		"chain": "photo_chain",
		"related_email": "day5_memory",
		"related_clue": "clue_last_photo",
		"title": "Foto rota",
		"title_en": "Torn photo",
		"body": "Una fotografia antigua, cortada a la mitad.\nSolo se ve una mano y parte de una sonrisa.\nEn el reverso: una fecha borrosa.\n\n[VERIFICADO: archivo original del disco]",
		"body_en": "An old photograph, cut in half.
You only see a hand and part of a smile.
On the back: a blurred date.

[VERIFIED: original file from the disk]"
	},
	{
		"id": "clue_message",
		"unlock_day": 8,
		"unlock_hour": 2,
		"unlock_minute": 20,
		"hidden": false,
		"type": "text",
		"is_true": true,
		"chain": "incident_chain",
		"related_clue": "clue_receipt",
		"title": "Mensaje eliminado",
		"title_en": "Deleted message",
		"body": "Fragmento recuperado del disco:\n«…no fue un accidente. Fue el viaje. Guarda el dinero y sal del país…»\nEl resto está sobreescrito.\n\n[VERIFICADO: metadatos de borrado reales]",
		"body_en": "Fragment recovered from the disk:
«…it wasn't an accident. Keep the money and…»
The rest is overwritten.

[VERIFIED: real deletion metadata]"
	},
	{
		"id": "clue_audio",
		"unlock_day": 7,
		"unlock_hour": 1,
		"unlock_minute": 50,
		"hidden": false,
		"type": "audio",
		"is_true": true,
		"chain": "incident_chain",
		"title": "Grabacion de voz",
		"title_en": "Voice recording",
		"body": "Un audio de 6 segundos, muy distorsionado.\nSe escucha una respiracion agitada y una frase:\n«...no mires atras...»\n\n[VERIFICADO: timestamp coincide con la noche del incidente]",
		"body_en": "A 6-second audio, heavily distorted.
You hear agitated breathing and a line:
«...don't look back...»

[VERIFIED: timestamp matches the night of the incident]"
	},
	{
		"id": "clue_receipt",
		"unlock_day": 10,
		"unlock_hour": 3,
		"unlock_minute": 5,
		"hidden": false,
		"type": "document",
		"is_true": true,
		"chain": "incident_chain",
		"related_bank": "meridian_payment",
		"title": "Recibo extraño",
		"title_en": "Strange receipt",
		"body": "Un recibo de un local que no reconoces.\nFecha: la noche del incidente.\nMonto pagado en efectivo, sin firma.\n\n[VERIFICADO: coincide con movimiento bancario HOTEL MERIDIAN]",
		"body_en": "A receipt from a place you don't recognize.
Date: the night of the incident.
Paid in cash, no signature.

[VERIFIED: matches HOTEL MERIDIAN bank transaction]"
	},
	{
		"id": "clue_medical",
		"unlock_day": 12,
		"hidden": true,
		"type": "medical",
		"is_true": true,
		"chain": "identity_chain",
		"title": "[OCULTO] Archivo medico",
		"title_en": "[HIDDEN] Medical file",
		"body": "Ingreso hospitalario — noche del incidente.\nCausa: trauma / amnesia / posible intoxicación.\nAlta voluntaria. Sin seguimiento.\nAcompañante: [TACHADO].\nNombre del paciente: ilegible.\n\n[VERIFICADO: sello hospitalario genuino]\n(Requiere RAM 8GB para leer este sector.)",
		"body_en": "Hospital admission. Cause: head trauma / amnesia.
Voluntary discharge. No follow-up.
Patient name: illegible.

[VERIFIED: genuine hospital seal]
(Requires 8GB RAM to read this sector.)"
	},
	{
		"id": "clue_diary",
		"unlock_day": 14,
		"hidden": false,
		"type": "text",
		"is_true": true,
		"chain": "identity_chain",
		"title": "Pagina de diario",
		"title_en": "Diary page",
		"body": "«…no sé si lo que recuerdo pasó de verdad.\nCada día la historia de esa noche cambia un poco.\nA veces veo su cara. A veces solo el vacío.\nTengo miedo de llegar al día 30 y no saber quién soy…\nni qué hice.»\n\n[VERIFICADO: escritura propia, fecha coherente]",
		"body_en": "«...I don't know if what I remember really happened.
Every day the story shifts a little.
I'm afraid of reaching day 30 and not knowing who I am.»

[VERIFIED: handwritten original]"
	},
	{
		"id": "clue_text",
		"unlock_day": 18,
		"hidden": false,
		"type": "text",
		"is_true": true,
		"chain": "escape_chain",
		"title": "Texto raro",
		"title_en": "Strange text",
		"body": "Notas en un bloc digital:\n«Ellos no buscan justicia. Buscan silencio.»\n«El dia 30 no es un limite. Es una fecha de entrega.»\n\n[VERIFICADO: no alterado por el sistema]",
		"body_en": "Repeated text across several files:
«THE SUBJECT MUST NOT REMEMBER.»
Someone wrote about you in third person.

[VERIFIED: same phrase in medical report]"
	},
	{
		"id": "clue_camera",
		"unlock_day": 20,
		"hidden": true,
		"type": "photo",
		"is_true": true,
		"chain": "incident_chain",
		"title": "[OCULTO] Camara oculta",
		"title_en": "Hidden camera",
		"body": "Un archivo de video sin miniatura, 4 segundos.\nSolo se ve una silueta cruzando la puerta.\nLa marca de tiempo no coincide con esa noche.\n\n[VERIFICADO: hash de archivo intacto]\n(Requiere RAM 8GB para leer este sector.)",
		"body_en": "A frame from a security camera.
A figure in a hallway. Blurry face.
The time matches the night of the incident.

[VERIFIED: real camera metadata]"
	},
	{
		"id": "clue_key",
		"unlock_day": 24,
		"hidden": true,
		"type": "key",
		"is_true": true,
		"chain": "escape_chain",
		"related_clue": "clue_map",
		"title": "[OCULTO] La ultima pieza",
		"title_en": "[HIDDEN] The last piece",
		"body": "Una dirección. Un nombre en clave.\nSi tienes el dinero del programa y has leído el resto,\nya sabes qué hacer antes de que la policía llegue…\no antes de que tu cabeza te delate.\n\n[VERIFICADO: coordenadas reales]\n(Archivo en carpeta recuerdos/ — solo con RAM 8GB.)",
		"body_en": "An address. A codename.
If you have the money and you've read the rest,
you already know what to do before they arrive.

[VERIFIED: real coordinates]
(File in memories/ folder — only with 8GB RAM.)"
	},
	{
		"id": "clue_map",
		"unlock_day": 27,
		"hidden": true,
		"type": "key",
		"is_true": true,
		"chain": "escape_chain",
		"title": "[OCULTO] Mapa marcado",
		"title_en": "[HIDDEN] Marked map",
		"body": "Un mapa de la ciudad con una ruta marcada a mano\nhasta la frontera. Una nota al margen:\n«Solo si estas seguro. No hay vuelta atras.»\n\n[VERIFICADO: tinta y papel originales]\n(Requiere RAM 8GB para leer este sector.)",
		"body_en": "A city map with a route marked by hand
to the border. A note in the margin:
«Only if you're sure. No turning back.»

[VERIFIED: original ink and paper]
(Requires 8GB RAM to read this sector.)"
	},
	# --- Más archivos ---
	{
		"id": "clue_note_early",
		"unlock_day": 3,
		"unlock_hour": 2,
		"unlock_minute": 5,
		"hidden": false,
		"type": "text",
		"is_true": true,
		"chain": "meta_chain",
		"title": "Nota en el escritorio",
		"title_en": "Note on the desktop",
		"body": "Escrito a mano:\n«No confíes en todos los correos.»\n«Algunos los inventa tu cabeza.»\n\n[VERIFICADO: tu propia letra]",
		"body_en": "Handwritten:
«Don't trust every email.»
«Some are made up by your head.»

[VERIFIED: your own handwriting]"
	},
	{
		"id": "clue_corrupted",
		"unlock_day": 6,
		"unlock_hour": 1,
		"unlock_minute": 40,
		"hidden": false,
		"type": "warning",
		"is_true": false,
		"sanity_delta": -6.0,
		"title": "archivo_corrompido.dat",
		"title_en": "corrupted_file.dat",
		"body": "Al abrirlo solo ves ruido y una frase:\n«YA ESTÁS DENTRO.»\nTe duele la cabeza.\n\n[POSIBLE ALUCINACIÓN: no hay registro de este archivo en el disco]",
		"body_en": "Opening it you only see noise and a line:
«YOU'RE ALREADY INSIDE.»
Your head hurts.

[POSSIBLE HALLUCINATION: no record of this file on disk]"
	},
	{
		"id": "clue_list",
		"unlock_day": 9,
		"hidden": false,
		"type": "document",
		"is_true": true,
		"chain": "identity_chain",
		"title": "Lista de nombres",
		"title_en": "List of names",
		"body": "Tres nombres tachados.\nEl cuarto es el tuyo… o alguien con el mismo apellido.\nFecha al pie: la noche del incidente.\n\n[VERIFICADO: documento escaneado original]",
		"body_en": "Three names crossed out.
The fourth is yours… or someone with the same surname.
Date at the bottom: the night of the incident.

[VERIFIED: original scanned document]"
	},
	{
		"id": "clue_scream",
		"unlock_day": 11,
		"hidden": false,
		"type": "audio",
		"is_true": false,
		"sanity_delta": -5.0,
		"title": "clip_grito.wav",
		"title_en": "scream_clip.wav",
		"body": "Un segundo de audio.\nNo es un grito de miedo.\nEs de rabia.\nNo quieres escucharlo otra vez.\n\n[POSIBLE ALUCINACIÓN: el archivo no existe en el sistema de archivos]",
		"body_en": "One second of audio.
It isn't a scream of fear.
It's rage.
You don't want to hear it again.

[POSSIBLE HALLUCINATION: file does not exist on the filesystem]"
	},
	{
		"id": "clue_mirror",
		"unlock_day": 13,
		"hidden": true,
		"type": "photo",
		"is_true": false,
		"sanity_delta": -7.0,
		"title": "[OCULTO] Espejo",
		"title_en": "[HIDDEN] Mirror",
		"body": "Una foto del baño.\nEn el cristal hay una silueta de más.\nNo eras tú solo en la habitación.\n\n[POSIBLE ALUCINACIÓN: no hay cámara en el baño]\n(RAM 8GB.)",
		"body_en": "A photo of a mirror.
Your reflection doesn't match the room.
Someone else is in the glass.

[POSSIBLE HALLUCINATION: the image changes when you look away]"
	},
	{
		"id": "clue_contract",
		"unlock_day": 16,
		"hidden": false,
		"type": "document",
		"is_true": true,
		"chain": "identity_chain",
		"title": "Contrato incompleto",
		"title_en": "Contract fragment",
		"body": "Cláusula 7: «El sujeto no recordará…»\nEl resto está quemado.\nFirma ilegible.\n\n[VERIFICADO: papel y tinta auténticos]",
		"body_en": "Clause 7: «The subject will not remember…»
The rest is burned.
Illegible signature.

[VERIFIED: original paper]"
	},
	{
		"id": "clue_loop",
		"unlock_day": 19,
		"hidden": false,
		"type": "system",
		"is_true": false,
		"sanity_delta": -4.0,
		"title": "log_reinicio.txt",
		"title_en": "Boot loop",
		"body": "BOOT… BOOT… BOOT…\nMismo checksum. Mismo día.\n¿Cuántas veces has llegado al 30?\n\n[POSIBLE ALUCINACIÓN: el log del sistema no contiene estas líneas]",
		"body_en": "BOOT… BOOT… BOOT…
Same checksum. Same day.
How many times have you reached day 30?

[POSSIBLE HALLUCINATION]"
	},
	{
		"id": "clue_threat",
		"unlock_day": 22,
		"hidden": true,
		"type": "police",
		"is_true": false,
		"sanity_delta": -5.0,
		"title": "[OCULTO] Amenaza",
		"title_en": "Anonymous threat",
		"body": "Mensaje sin remitente:\n«Si transferiste el dinero, ya es tarde.»\nPuede ser real. Puede no serlo.\n\n[POSIBLE ALUCINACIÓN: no hay registro de recepción]\n(RAM 8GB.)",
		"body_en": "Message with no sender:
«If you transferred the money, it's already too late.»
It may be real.
It may not.

[UNVERIFIED]"
	},
	{
		"id": "clue_last_photo",
		"unlock_day": 26,
		"hidden": true,
		"type": "photo",
		"is_true": true,
		"chain": "photo_chain",
		"related_clue": "clue_photo",
		"title": "[OCULTO] La otra mitad",
		"title_en": "Complete photo",
		"body": "Un fragmento que encaja con la foto rota.\nAún no se ve el rostro completo.\nPero la mano… es la tuya.\n\n[VERIFICADO: empalme perfecto con Foto rota]\n(RAM 8GB.)",
		"body_en": "The other half of the photo.
Now you see the full face.
You know who it is.
You wish you didn't.

[VERIFIED: completes clue_photo]"
	},
]

var unlocked_ids: Array = []
var read_ids: Array = []
## Si true, no reproducir SFX al desbloquear (arranque, carga, reset).
var _silent_unlock: bool = true

const CLUES_NEEDED_FOR_ESCAPE: int = 3

func _ready() -> void:
	GameManager.day_changed.connect(_on_day_changed)
	GameManager.upgrade_changed.connect(_on_upgrade_changed)
	_silent_unlock = true
	unlock_for_day(1)
	call_deferred("_enable_notifications")

func _enable_notifications() -> void:
	_silent_unlock = false

func unlock_for_day(day: int, silent: bool = false) -> void:
	var changed := false
	var newly: int = 0
	var cur_h: int = 1
	var cur_m: int = 0
	if TimeManager:
		cur_h = TimeManager.hour
		cur_m = TimeManager.minute
	var pc_on: bool = GameManager != null and GameManager.is_pc_on
	for clue in CLUES:
		var id: String = str(clue["id"])
		if id in unlocked_ids:
			continue
		var uday: int = int(clue.get("unlock_day", 999))
		if uday > day:
			continue
		# Mismo día: respetar hora/minuto de llegada (default 1:00)
		if uday == day:
			var uh: int = int(clue.get("unlock_hour", 1))
			var um: int = int(clue.get("unlock_minute", 0))
			if not pc_on:
				# PC apagada: no usar la hora del día anterior
				if uh > 1 or (uh == 1 and um > 0):
					continue
			elif cur_h < uh or (cur_h == uh and cur_m < um):
				continue
		unlocked_ids.append(id)
		changed = true
		newly += 1
	if changed:
		clues_changed.emit()
		if newly > 0 and not silent and not _silent_unlock:
			if SoundSystem and SoundSystem.has_method("play_notification"):
				SoundSystem.play_notification()

## Llamado al cambiar de minuto para liberar archivos programados por hora.
func check_timed_unlocks() -> void:
	if GameManager:
		unlock_for_day(GameManager.day)

func _on_day_changed(new_day: int) -> void:
	unlock_for_day(new_day, true)

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
	var is_true: bool = true
	var related_clue: String = ""
	# No permitir leer ocultos sin RAM
	for clue in CLUES:
		if str(clue["id"]) != clue_id:
			continue
		if bool(clue.get("hidden", false)) and not UpgradeSystem.has_hidden_files_access():
			return
		if clue.has("sanity_delta"):
			sanity_delta = float(clue["sanity_delta"])
		is_true = bool(clue.get("is_true", true))
		related_clue = str(clue.get("related_clue", ""))
		break
	read_ids.append(clue_id)
	# Pistas falsas cuestan más cordura; las verdaderas recuperan un poco más
	if not is_true and sanity_delta > 0:
		sanity_delta = -absf(sanity_delta) - 2.0
	elif is_true and sanity_delta > 0:
		sanity_delta += 1.5
	GameManager.change_sanity(sanity_delta)
	if InvestigationSystem and InvestigationSystem.has_method("register_clue_read"):
		InvestigationSystem.register_clue_read(clue_id)
	if ParanoiaSystem and ParanoiaSystem.has_method("register_discovery_event"):
		ParanoiaSystem.register_discovery_event("clue")
	# Cadena: si hay related_clue y ya está desbloqueada, bonus de investigación
	if related_clue != "" and related_clue in unlocked_ids and related_clue in read_ids:
		if InvestigationSystem and InvestigationSystem.has_method("register_chain_complete"):
			InvestigationSystem.register_chain_complete(clue_id)
		GameManager.change_sanity(3.0)
	clues_changed.emit()
	# Reacciones del jugador al ver ciertas pistas (después de cualquier diálogo en curso)
	_trigger_player_reaction(clue_id)

## Devuelve true si la pista es verificada como real (no alucinación).
func is_clue_true(clue_id: String) -> bool:
	for clue in CLUES:
		if str(clue["id"]) == clue_id:
			return bool(clue.get("is_true", true))
	return true

## Lista de pistas leídas con su valor de verdad (para Truth Archive).
func get_truth_archive() -> Array:
	var result: Array = []
	for clue in CLUES:
		var cid: String = str(clue["id"])
		if cid not in read_ids:
			continue
		result.append({
			"id": cid,
			"title": str(clue.get("title", cid)),
			"is_true": bool(clue.get("is_true", true)),
			"chain": str(clue.get("chain", ""))
		})
	return result

## Diálogos cortos del jugador al descubrir pistas clave.
func _trigger_player_reaction(clue_id: String) -> void:
	if not DialogueSystem:
		return
	var reactions: Dictionary = {
		"clue_photo": "Una foto cortada a la mitad…\n¿De quién será la otra mitad?",
		"clue_message": "«No fue un accidente»…\n¿Qué demonios pasó esa noche?",
		"clue_audio": "«No mires atrás»…\n¿A quién le hablaba?",
		"clue_receipt": "Un recibo de esa noche.\nNo recuerdo haber estado ahí.",
		"clue_diary": "Cada día la historia cambia un poco.\nEso… me suena demasiado familiar.",
		"clue_list": "Mi apellido en esa lista…\nO el de alguien como yo.",
		"clue_contract": "«El sujeto no recordará…»\n¿Yo soy el sujeto?",
		"clue_key": "Una dirección. Un nombre en clave.\nSi llego al día 30… ya sé qué hacer."
	}
	if not reactions.has(clue_id):
		return
	# once_id evita repetir la reacción si se vuelve a abrir
	DialogueSystem.show_line("TÚ", str(reactions[clue_id]), "player_react_" + clue_id)

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


func localized_title(clue: Dictionary) -> String:
	if LocaleSystem:
		return LocaleSystem.field(clue, "title")
	return str(clue.get("title", ""))

func localized_body(clue: Dictionary) -> String:
	if LocaleSystem:
		return LocaleSystem.field(clue, "body")
	return str(clue.get("body", clue.get("text", "")))
