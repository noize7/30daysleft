extends Node
## =============================================================================
## EmailSystem — Correos reales y falsos (Autoload)  [TANDA 4 / FASE 7]
##
## Los correos se desbloquean por día. Si la cordura es baja, aparecen falsos
## generados por la mente del protagonista.
## =============================================================================

signal emails_changed

## Catálogo de correos del juego (id único).
## unlock_day: día en que aparece en la bandeja.
## is_fake: true = generado por la mente (alucinación).
## "type" define qué icono pequeño se muestra junto al asunto en la bandeja
## (ver TYPE_ICON_PATHS en scripts/apps/email_app.gd).
var EMAILS: Array = [
	{
		"id": "day1_welcome",
		"unlock_day": 1,
		"unlock_hour": 1,
		"unlock_minute": 0,
		"is_fake": false,
		"type": "system",
		"from": "sistema@local",
		"subject": "Sesión reiniciada",
		"subject_en": "Session restarted",
		"body": "Tu sesión se reinició.\nNo hay registro del último apagado limpio.\n\nTienes 30 días.\nEl programa no pregunta qué hiciste.\nSolo si cumples.\n\nRevisa los archivos cuando puedas.\n\n— Sistema",
		"body_en": "Your session restarted.\nNo clean shutdown on record.\n\nYou have 30 days.\nThe program doesn't ask what you did.\nOnly if you deliver.\n\nCheck your files when you can.\n\n— System"
	},
	{
		"id": "day1_job",
		"unlock_day": 1,
		"unlock_hour": 1,
		"unlock_minute": 5,
		"is_fake": false,
		"type": "job",
		"from": "noreply@workgrid.mail",
		"subject": "Programa activo — encargos nocturnos",
		"subject_en": "Program active — night jobs",
		"body": "Operador,\n\nHay encargos activos entre la 01:00 y las 05:00.\nPago anónimo. Sin papeles. Sin preguntas.\n\nNo uses tu nombre real.\n\n— WorkGrid",
		"body_en": "Operator,\n\nJobs active between 01:00 and 05:00.\nAnonymous pay. No papers. No questions.\n\nDo not use your real name.\n\n— WorkGrid"
	},
	{
		"id": "day2_reminder",
		"unlock_day": 2,
		"unlock_hour": 1,
		"unlock_minute": 46,
		"is_fake": false,
		"type": "job",
		"from": "noreply@workgrid.mail",
		"subject": "Recordatorio de horario",
		"subject_en": "Schedule reminder",
		"body": "El sistema detecta inactividad fuera de horario.\nRecuerda: solo se paga entre 01:00 y 05:00.\n\nWorkGrid",
		"body_en": "The system detected inactivity outside work hours.\nRemember: pay only between 01:00 and 05:00.\n\nWorkGrid"
	},
	{
		"id": "day3_odd",
		"unlock_day": 3,
		"unlock_hour": 2,
		"unlock_minute": 15,
		"is_fake": false,
		"type": "warning",
		"from": "desconocido",
		"subject": "No abras la carpeta recuerdos",
		"subject_en": "Don't open the memories folder",
		"body": "Todavía no.\nNo estás listo para esa noche.\n\nSi la abres, no podrás fingir que no pasó.\n\n(¿Quién escribió esto?)",
		"body_en": "Not yet.\nYou're not ready for that night.\n\nIf you open it, you won't be able to pretend it didn't happen.\n\n(Who wrote this?)"
	},
	{
		"id": "day5_memory",
		"unlock_day": 5,
		"unlock_hour": 1,
		"unlock_minute": 30,
		"is_fake": false,
		"type": "photo",
		"from": "tú@ayer",
		"subject": "Foto rota",
		"subject_en": "Torn photo",
		"body": "Encontré una foto en el disco.\nEstá cortada por la mitad.\n\nEn un lado estás tú.\nEn el otro… falta alguien.\nAlguien que ya no puede contestar.",
		"body_en": "I found a photo on the disk.\nIt's cut in half.\n\nOn one side: you.\nOn the other… someone is missing.\nSomeone who can't answer anymore."
	},
	{
		"id": "day5_fake",
		"unlock_day": 5,
		"unlock_hour": 3,
		"unlock_minute": 10,
		"is_fake": true,
		"type": "warning",
		"from": "mamá",
		"subject": "Ven a casa",
		"subject_en": "Come home",
		
		"body": "Cariño, la cena está lista.\nTodo está bien.\nNunca pasó nada.\nVuelve a la habitación.\n\n(Esta persona ya no puede escribirte.\nCordura baja: posible alucinación.)",
		"body_en": "Honey, dinner is ready.
Everything is fine.
Nothing ever happened.

(This message should not exist.)"
	},
	{
		"id": "day7_neighbor",
		"unlock_day": 7,
		"unlock_hour": 2,
		"unlock_minute": 0,
		"is_fake": false,
		"type": "text",
		"from": "vecino_402",
		"subject": "Anoche escuché algo",
		"subject_en": "I heard something last night",
		"body": "No quiero meterme en problemas,\npero anoche se escuchaban gritos en tu piso.\nOtra vez.\n\nSi necesitas ayuda… o si la policía pregunta…\nsolo dime qué digo.",
		"body_en": "I don't want to get into trouble,
but last night there were screams from your floor.

Is everything okay?"
	},
	{
		"id": "day8_fake_call",
		"unlock_day": 8,
		"is_fake": true,
		"type": "warning",
		"from": "??? (llamada perdida)",
		"subject": "3 llamadas perdidas",
		"subject_en": "3 missed calls",
		"body": "Contesta.\nContesta.\nContesta.\n\n(No hay ningún número registrado.)",
		"body_en": "Answer.
Answer.
Answer.

(There is no number on record.)"
	},
	{
		"id": "day10_police",
		"unlock_day": 10,
		"is_fake": false,
		"type": "police",
		"from": "alertas@ciudad.gov",
		"subject": "Aviso de investigación",
		"subject_en": "Investigation notice",
		"body": "Se ha abierto un expediente por un incidente en tu zona.\nHay un fallecimiento bajo investigación.\nColabora si te contactan.\n\nNo ignores este mensaje.\n\n— Unidad de investigación",
		"body_en": "A case has been opened in your area.
Cooperate if they contact you.

Do not ignore this message."
	},
	{
		"id": "day10_fake",
		"unlock_day": 10,
		"is_fake": true,
		"type": "warning",
		"from": "policía",
		"subject": "YA SABEMOS DÓNDE ESTÁS",
		"subject_en": "WE KNOW WHERE YOU ARE",
		"body": "Abre la puerta.\nAbre la puerta.\nAbre la puerta.\n\n(Cordura baja: posible alucinación.)",
		"body_en": "Open the door.
Open the door.
Open the door.

(Low sanity: possible hallucination.)"
	},
	{
		"id": "day12_bank",
		"unlock_day": 12,
		"is_fake": false,
		"type": "document",
		"from": "notificaciones@bancocentral",
		"subject": "Movimiento inusual detectado",
		"subject_en": "Unusual activity detected",
		"body": "Se han registrado depósitos irregulares en tu cuenta.\nRevisa el detalle en la app del Banco.\n\nEste aviso es automático.",
		"body_en": "Irregular deposits were recorded on your account.
Check the details in the Bank app.

This notice is automatic."
	},
	{
		"id": "day15_truth",
		"unlock_day": 15,
		"is_fake": false,
		"type": "medical",
		"from": "archivo.medico",
		"subject": "Informe incompleto",
		"subject_en": "Incomplete report",
		"body": "Paciente: [REDACTADO]\nIngreso: noche del incidente.\nDiagnóstico: lagunas de memoria / posible intoxicación / trauma.\nAlta voluntaria. Sin seguimiento.\n\nRecomendación: no aislarse. No operar maquinaria pesada. No tomar decisiones irreversibles.\n\nPágina 2: ilegible.\nNombre del acompañante: [TACHADO]",
		"body_en": "Patient: [REDACTED]
Diagnosis: memory gaps / trauma.
Recommendation: do not isolate.

Page 2 illegible."
	},
	{
		"id": "day18_press",
		"unlock_day": 18,
		"is_fake": false,
		"type": "document",
		"from": "prensa.local",
		"subject": "Nota de prensa: caso sin resolver",
		"subject_en": "Press note: unsolved case",
		"body": "\"Las autoridades siguen sin identificar sospechosos\",\ndice el artículo.\n\nHay una foto borrosa en la página 3.",
		"body_en": "\"Authorities still have no suspects,\"
the article says.

There is a blurry photo on page 3."
	},
	{
		"id": "day20_crisis",
		"unlock_day": 20,
		"is_fake": false,
		"type": "system",
		"from": "sistema@local",
		"subject": "ERROR DE INTEGRIDAD",
		"subject_en": "INTEGRITY ERROR",
		"body": "Varios archivos no coinciden con el checksum.\nAlguien (o algo) está reescribiendo el disco.\n\nConfía solo en lo que puedas verificar.",
		"body_en": "Several files do not match the checksum.
Someone (or something) is rewriting the disk.

Trust only what you can verify."
	},
	{
		"id": "day20_fake",
		"unlock_day": 20,
		"is_fake": true,
		"type": "warning",
		"from": "tú",
		"subject": "No hay salida",
		"subject_en": "There is no way out",
		"body": "Da igual el dinero.\nDa igual el día 30.\nEsto no es un juego.\n\n(¿O sí?)",
		"body_en": "The money doesn't matter.
Day 30 doesn't matter.
This is not a game."
	},
	{
		"id": "day22_fake_boss",
		"unlock_day": 22,
		"is_fake": true,
		"type": "warning",
		"from": "jefe@workgrid.mail",
		"subject": "Estás despedido",
		"subject_en": "You're fired",
		"body": "Ya no queda trabajo para ti.\nNunca lo hubo.\n\n(Este remitente no existe en los registros.)",
		"body_en": "Don't come back to WorkGrid.
Your access has been revoked.

(This message is not in the server logs.)"
	},
	{
		"id": "day25_final",
		"unlock_day": 25,
		"is_fake": false,
		"type": "key",
		"from": "contacto.seguro",
		"subject": "Ruta de escape",
		"subject_en": "Escape route",
		"body": "Si juntaste el dinero y las pistas,\nhay una salida.\n\nSi no… ellos llegarán primero.",
		"body_en": "Five days remain.
The escape account is still waiting for a transfer.
Check the Bank."
	},
	{
		"id": "day28_last_warning",
		"unlock_day": 28,
		"is_fake": false,
		"type": "police",
		"from": "alertas@ciudad.gov",
		"subject": "Últimas 48 horas",
		"subject_en": "Last 48 hours",
		"body": "El expediente se cierra en 2 días.\nA partir de entonces la decisión no dependerá de ti.\n\nActúa ahora.",
		"body_en": "Time is running out.
If you have not transferred the money and recovered the clues,
you will not make it out."
	},
	# --- Más correos (tanda contenido) ---
	{
		"id": "day4_noise",
		"unlock_day": 4,
		"is_fake": false,
		"type": "text",
		"from": "vecino_402",
		"subject": "¿Oyes eso?",
		"subject_en": "Do you hear that?",
		"body": "Hay un zumbido en las paredes.\nEmpezó anoche.\n¿También lo oyes tú?",
		"body_en": "There's a hum in the walls.
It only starts when the PC is on.

Or maybe it's me."
	},
	{
		"id": "day6_spam_fake",
		"unlock_day": 6,
		"is_fake": true,
		"type": "warning",
		"sanity_delta": -5.0,
		"from": "premio@suerte.mail",
		"subject": "HAS GANADO $1.000.000",
		"subject_en": "YOU WON $1,000,000",
		"body": "Haz clic aquí.\nHaz clic aquí.\nHaz clic aquí.\n\n(No hay enlace. No debería existir.)",
		"body_en": "Click here to claim your prize.
Urgent. Limited time.

(Spam. Hallucination.)"
	},
	{
		"id": "day9_photo_mail",
		"unlock_day": 9,
		"is_fake": false,
		"type": "photo",
		"from": "archivo.local",
		"subject": "Adjunto: img_03.jpg",
		"subject_en": "Attachment: img_03.jpg",
		"body": "Se recuperó una imagen dañada del disco.\nMírala en Archivos → Foto rota.",
		"body_en": "I sent you a photo.
Look at it in Files.
Don't show it to anyone."
	},
	{
		"id": "day11_whisper_fake",
		"unlock_day": 11,
		"is_fake": true,
		"type": "warning",
		"sanity_delta": -6.0,
		"from": "dentro.de.ti",
		"subject": "deja de mirar la pantalla",
		"subject_en": "stop looking at the screen",
		"body": "no eres tú quien escribe\nno eres tú quien lee\n\n(Cordura inestable.)",
		"body_en": "If you keep digging
you'll find something that shouldn't be found.

Close the app."
	},
	{
		"id": "day13_work",
		"unlock_day": 13,
		"is_fake": false,
		"type": "job",
		"from": "noreply@workgrid.mail",
		"subject": "Bonificación nocturna",
		"subject_en": "Night bonus",
		"body": "Los trabajos de nivel 3 pagan más esta semana.\nHorario sin cambios: 01:00–05:00.",
		"body_en": "Level 3 jobs pay more this week.
Hours unchanged: 01:00–05:00."
	},
	{
		"id": "day14_static_fake",
		"unlock_day": 14,
		"is_fake": true,
		"type": "system",
		"sanity_delta": -4.0,
		"from": "sistema@local",
		"subject": "████████",
		"subject_en": "████████",
		"body": "El mensaje se corrompió.\nSolo quedan caracteres basura.\n\n¿O es tu mente?",
		"body_en": "The message corrupted.
Only garbage characters remain.

Or is it your mind?"
	},
	{
		"id": "day16_doctor",
		"unlock_day": 16,
		"is_fake": false,
		"type": "medical",
		"from": "consulta@clinica",
		"subject": "Recordatorio de cita",
		"subject_en": "Appointment reminder",
		"body": "Cita pendiente: evaluación de memoria.\nNo acudiste la última vez.\nLlama si recuerdas este mensaje.",
		"body_en": "Pending appointment: memory evaluation.
You missed the last one.
Call if you remember this message."
	},
	{
		"id": "day17_mirror_fake",
		"unlock_day": 17,
		"is_fake": true,
		"type": "warning",
		"sanity_delta": -7.0,
		"from": "espejo",
		"subject": "no te acerques",
		"subject_en": "don't get closer",
		"body": "Si miras demasiado tiempo\nalguien mira desde el otro lado.\n\nCierra Archivos.",
		"body_en": "If you stare too long
someone stares from the other side.

Close Files."
	},
	{
		"id": "day19_leak",
		"unlock_day": 19,
		"is_fake": false,
		"type": "document",
		"from": "fuente.anonima",
		"subject": "Filtración",
		"subject_en": "Leak",
		"body": "El expediente habla de un testigo.\nEl nombre está tachado.\nLa fecha coincide con tu laguna.",
		"body_en": "The file mentions a witness.
The name is crossed out.
The date matches your gap."
	},
	{
		"id": "day21_loop_fake",
		"unlock_day": 21,
		"is_fake": true,
		"type": "system",
		"sanity_delta": -5.0,
		"from": "sistema@local",
		"subject": "Día 1 otra vez",
		"subject_en": "Day 1 again",
		"body": "Tu sesión se reinició.\nTu sesión se reinició.\nTu sesión se reinició.",
		"body_en": "Your session restarted.
Your session restarted.
Your session restarted."
	},
	{
		"id": "day23_deadline",
		"unlock_day": 23,
		"is_fake": false,
		"type": "police",
		"from": "alertas@ciudad.gov",
		"subject": "Plazo reducido",
		"subject_en": "Deadline moved up",
		"body": "El cierre del caso se adelanta.\nNo salgas de la zona.\nNo ignores este aviso.",
		"body_en": "Case closure is being moved forward.
Do not leave the area.
Do not ignore this notice."
	},
	{
		"id": "day26_help_fake",
		"unlock_day": 26,
		"is_fake": true,
		"type": "key",
		"sanity_delta": -8.0,
		"from": "contacto.seguro",
		"subject": "Ruta falsa",
		"subject_en": "False route",
		"body": "Transfiere el dinero a ESTA cuenta:\n000000000000\n\n(Remitente clonado. No confíes.)",
		"body_en": "Transfer the money to THIS account:
000000000000

(Cloned sender. Do not trust.)"
	},
	{
		"id": "day29_countdown",
		"unlock_day": 29,
		"is_fake": false,
		"type": "system",
		"from": "sistema@local",
		"subject": "1 día restante",
		"subject_en": "1 day remaining",
		"body": "Mañana se evalúa el resultado.\nDinero transferido + pistas = salida.\nSin eso, no hay más reintentos.",
		"body_en": "Tomorrow the result is evaluated.
Money transferred + clues = exit.
Without that, no more retries."
	},
	# --- Cadena narrativa principal: el ordenador revela información por etapas. ---
	{
		"id": "mystery_chain_01",
		"expires_day": 5,
		"unlock_day": 2,
		"unlock_hour": 1,
		"unlock_minute": 20,
		"is_fake": false,
		"type": "warning",
		"from": "unknown@relay.mail",
		"subject": "Sobre aquella noche",
		"subject_en": "About that night",
		"body": "No deberías intentar recordar el Hotel Meridian.\n\nDéjalo enterrado.",
		"body_en": "You shouldn't try to remember the Meridian Hotel.

Leave it buried."
	},
	{
		"id": "mystery_chain_02",
		"requires_flags": ["knows_meridian"],
		"expires_day": 8,
		"unlock_day": 5,
		"unlock_hour": 2,
		"unlock_minute": 10,
		"is_fake": false,
		"type": "document",
		"from": "unknown@relay.mail",
		"subject": "Revisa el Banco",
		"subject_en": "Check the Bank",
		"body": "No busques mi nombre.\nBusca un pago del 14/05.\n\nCuando lo encuentres, entenderás por qué te escribo.",
		"body_en": "Don't look for my name.
Look for a payment from 14/05.

When you find it, you'll understand why I'm writing."
	},
	{
		"id": "mystery_chain_03",
		"requires_flags": ["tx_seen_meridian_payment"],
		"expires_day": 12,
		"unlock_day": 8,
		"unlock_hour": 1,
		"unlock_minute": 35,
		"is_fake": false,
		"type": "key",
		"from": "unknown@relay.mail",
		"subject": "Habitación 217",
		"subject_en": "Room 217",
		"body": "Ya encontraste el pago.\nLa habitación era la 217.\n\nNo abras nada si no estás preparado para recordar.",
		"body_en": "You already found the payment.
The room was 217.

Don't open anything if you're not ready to remember."
	},
	{
		"id": "mystery_chain_04",
		"requires_flags": ["meridian_opened"],
		"expires_day": 17,
		"unlock_day": 12,
		"unlock_hour": 2,
		"unlock_minute": 5,
		"is_fake": false,
		"type": "warning",
		"from": "unknown@relay.mail",
		"subject": "El archivo",
		"subject_en": "The file",
		"body": "El archivo de Meridian está ahí.\nNo intentes adivinar la contraseña.\n\nLa respuesta está en lo que ya viste.",
		"body_en": "The Meridian file is there.
Don't try to guess the password.

The answer is in what you already saw."
	},
	{
		"id": "mystery_chain_05",
		"requires_flags": ["meridian_log_seen"],
		"expires_day": 24,
		"unlock_day": 17,
		"unlock_hour": 1,
		"unlock_minute": 25,
		"is_fake": false,
		"type": "medical",
		"from": "unknown@relay.mail",
		"subject": "¿Quién es el sujeto?",
		"subject_en": "Who is the subject?",
		"body": "Lee los informes médicos.\nDespués vuelve a revisar tus archivos.\n\nHay una frase que aparece más de una vez: \"el sujeto\".",
		"body_en": "Read the medical reports.
Then check your files again.

There's a phrase that appears more than once: \"the subject\"."
	},
	{
		"id": "mystery_chain_06",
		"requires_flags": ["knows_subject"],
		"expires_day": 29,
		"unlock_day": 24,
		"unlock_hour": 3,
		"unlock_minute": 0,
		"is_fake": false,
		"type": "police",
		"from": "unknown@relay.mail",
		"subject": "No queda mucho tiempo",
		"subject_en": "Not much time left",
		"body": "Si sigues investigando, vas a encontrar la respuesta.\nSi dejas de investigar, quizá consigas escapar.\n\nNo puedes hacer ambas cosas para siempre.",
		"body_en": "If you keep investigating, you'll find the answer.
If you stop investigating, you might escape.

You can't do both forever."
	},
	# El correo de cuenta de escape se genera dinámicamente (ver try_send_escape_account).
]

## ID del correo dinámico con el número de cuenta de escape.
const ESCAPE_MAIL_ID := "escape_account"

## IDs desbloqueados en esta partida.
var unlocked_ids: Array = []
## IDs que el jugador ya abrió.
var read_ids: Array = []

## Si true, no reproducir SFX al desbloquear (arranque, carga, reset).
var _silent_unlock: bool = true

func _ready() -> void:
	_ensure_email_english_fallback()

	GameManager.day_changed.connect(_on_day_changed)
	# Día 1 al empezar (sin sonido de notificación)
	_silent_unlock = true
	unlock_for_day(1)
	try_send_escape_account(1)
	# Tras el primer frame permitir notificaciones en gameplay
	call_deferred("_enable_notifications")

func _enable_notifications() -> void:
	_silent_unlock = false

## Desbloquea correos cuyo unlock_day/hora ya se alcanzó.
## unlock_hour / unlock_minute opcionales (default 1:00 = al empezar el día).
## Los falsos solo se desbloquean si sanity < 70 (o umbral más alto en días altos).
## silent: no tocar el flag; se usa _silent_unlock o el parámetro explícito.
func unlock_for_day(day: int, silent: bool = false) -> void:
	var changed := false
	var newly: int = 0
	var cur_h: int = 1
	var cur_m: int = 0
	if TimeManager:
		cur_h = TimeManager.hour
		cur_m = TimeManager.minute
	var pc_on: bool = GameManager != null and GameManager.is_pc_on
	for mail in EMAILS:
		var id: String = str(mail["id"])
		if id in unlocked_ids:
			continue
		var uday: int = int(mail.get("unlock_day", 999))
		if uday > day:
			continue
		var required_flags = mail.get("requires_flags", [])
		if required_flags is Array and InvestigationSystem:
			var requirements_met := true
			for required_flag in required_flags:
				if not InvestigationSystem.is_flag_set(str(required_flag)):
					requirements_met = false
					break
			if not requirements_met:
				continue
		# Si es el mismo día, respetar hora/minuto de llegada
		if uday == day:
			var uh: int = int(mail.get("unlock_hour", 1))
			var um: int = int(mail.get("unlock_minute", 0))
			if not pc_on:
				# PC apagada: la hora del reloj es del día anterior → solo liberar
				# lo que llega al arranque (1:00). El resto espera al reloj.
				if uh > 1 or (uh == 1 and um > 0):
					continue
			elif cur_h < uh or (cur_h == uh and cur_m < um):
				continue
		var is_fake: bool = bool(mail.get("is_fake", false))
		# Correos falsos solo si cordura baja o día alto con cordura < 85
		if is_fake:
			if GameManager.sanity >= 70.0 and day < 20:
				continue
			if GameManager.sanity >= 85.0:
				continue
		unlocked_ids.append(id)
		changed = true
		newly += 1
	if changed:
		emails_changed.emit()
		# Un solo sonido si hay correos nuevos Y no estamos en modo silencioso
		if newly > 0 and not silent and not _silent_unlock:
			if SoundSystem and SoundSystem.has_method("play_notification"):
				SoundSystem.play_notification()

## Llamado al cambiar de minuto para liberar correos programados por hora.
func check_timed_unlocks() -> void:
	if GameManager:
		unlock_for_day(GameManager.day)

func _on_day_changed(new_day: int) -> void:
	# Cambio de día / carga: sin spam de notificaciones
	unlock_for_day(new_day, true)
	try_send_escape_account(new_day)

## Envía (una sola vez) el correo con el número de cuenta de escape
## en el día aleatorio guardado en GameManager.escape_account_day (0–10).
## Día 0 = llega desde el día 1.
func try_send_escape_account(day: int) -> void:
	if GameManager.escape_account_sent:
		return
	if GameManager.escape_account_number.is_empty():
		return
	var unlock_day: int = maxi(1, int(GameManager.escape_account_day))
	if day < unlock_day:
		return
	# Texto corto para que no se salga de la ventana
	var body := "Cuenta: %s\nMeta: $%.0f\n\nTransfiere en Banco.\nUsa el botón 📋 para copiar." % [
		GameManager.escape_account_number,
		GameManager.MONEY_GOAL
	]
	var entry := {
		"id": ESCAPE_MAIL_ID,
		"unlock_day": unlock_day,
		"is_fake": false,
		"type": "document",
		"from": "contacto.seguro",
		"subject": "Cuenta de transferencia",
		"subject_en": "Cuenta de transferencia",
		"body": body,
		"copy_account": true
	}
	# Sustituir si ya existía o añadir
	var found := false
	for i in range(EMAILS.size()):
		if str(EMAILS[i].get("id", "")) == ESCAPE_MAIL_ID:
			EMAILS[i] = entry
			found = true
			break
	if not found:
		EMAILS.append(entry)
	if ESCAPE_MAIL_ID not in unlocked_ids:
		unlocked_ids.append(ESCAPE_MAIL_ID)
	GameManager.escape_account_sent = true
	emails_changed.emit()

## Lista de correos desbloqueados (dicts del catálogo).
func get_inbox() -> Array:
	var result: Array = []
	var current_day := GameManager.day if GameManager else 1
	for mail in EMAILS:
		if str(mail["id"]) not in unlocked_ids:
			continue
		var expires_day := int(mail.get("expires_day", 999))
		if current_day > expires_day and str(mail["id"]) not in read_ids:
			continue
		result.append(mail)
	return result

## Marca un correo como leído. Puede subir o bajar cordura según el mail.
func mark_read(email_id: String) -> void:
	if email_id in read_ids:
		return
	read_ids.append(email_id)
	for mail in EMAILS:
		if str(mail["id"]) != email_id:
			continue
		if mail.has("sanity_delta"):
			GameManager.change_sanity(float(mail["sanity_delta"]))
		elif bool(mail.get("is_fake", false)):
			GameManager.change_sanity(-3.0)
		else:
			if int(mail.get("unlock_day", 1)) >= 5 and email_id != ESCAPE_MAIL_ID:
				GameManager.change_sanity(2.0)
		break
	if InvestigationSystem and InvestigationSystem.has_method("register_email_read"):
		InvestigationSystem.register_email_read(email_id)
	if ParanoiaSystem and ParanoiaSystem.has_method("register_discovery_event"):
		ParanoiaSystem.register_discovery_event("email")
	emails_changed.emit()

func is_read(email_id: String) -> bool:
	return email_id in read_ids

func unread_count() -> int:
	var n := 0
	for id in unlocked_ids:
		if id not in read_ids:
			n += 1
	return n


func localized_subject(email: Dictionary) -> String:
	if LocaleSystem:
		return LocaleSystem.field(email, "subject")
	return str(email.get("subject", ""))

func localized_body(email: Dictionary) -> String:
	if LocaleSystem:
		return LocaleSystem.field(email, "body")
	return str(email.get("body", ""))


## Ensures every email has subject_en/body_en (fallback to Spanish if missing).
func _ensure_email_english_fallback() -> void:
	var table := {
		"day1_welcome": ["Welcome back", "Your session restarted.\nWe don't remember the last clean shutdown.\n\nCheck your files when you can.\n\n— System"],
		"day1_job": ["New jobs available", "Hi.\n\nSurveys are active between 01:00 and 05:00.\nPay is credited instantly.\n\nWorkGrid"],
		"day2_reminder": ["Schedule reminder", "The system detected inactivity outside work hours.\nRemember: pay only between 01:00 and 05:00.\n\nWorkGrid"],
		"day3_odd": ["Don't open the memories folder", "Not yet.\nYou're not ready.\n\nIf you open it, you won't be able to close it."],
		"day5_memory": ["Torn photo", "I found a photo on the disk.\nIt's cut in half.\n\nWho is the missing person?"],
		"day5_fake": ["Come home", "Honey, dinner is ready.\nEverything is fine.\nNothing ever happened.\n\n(This message should not exist.)"],
		"day7_neighbor": ["Noise complaint", "The downstairs neighbor reported noise at 3 AM.\nKeep it down."],
		"day8_fake_call": ["Missed call", "You have 1 missed call.\nUnknown number.\n(Possible hallucination.)"],
		"day10_police": ["Official inquiry", "We need to speak with you about an incident on 14/05.\nA reply is not required. Appearing is."],
		"day10_fake": ["You're safe", "Nobody is looking for you.\nYou can rest.\n(Do not trust this.)"],
		"day12_bank": ["Account movement", "A transfer was registered near Hotel Meridian.\nReview your statements."],
		"day15_truth": ["Day 15", "Halfway.\nPeople who ask too much stop asking."],
		"day18_press": ["We see you", "Online payments leave a trail.\nCash is quieter.\nChoose carefully."],
		"day20_crisis": ["Delivery failed", "A package could not be delivered.\nOr it was delivered to the wrong person."],
		"day20_fake": ["Everything is fine", "Your debt is cleared.\nYou can stop.\n(False.)"],
		"day22_fake_boss": ["Urgent: boss", "Come to the office tomorrow.\n(There is no office.)"],
		"day25_final": ["Five days left", "Five days remain.\nThe escape account is still waiting for a transfer."],
		"day28_last_warning": ["Almost over", "Almost no time left.\nIf you fail, there will be no next boot."],
		"mystery_chain_01": ["Re: Meridian", "Room 217. 23:47.\nDoes that mean anything to you?"],
		"mystery_chain_02": ["Re: Meridian (2)", "The password is shorter than you think.\nThree digits."],
		"mystery_chain_03": ["Receipt", "Cash. No signature.\nHotel Meridian."],
		"mystery_chain_04": ["Follow-up", "If you found the log, you already know too much."],
		"mystery_chain_05": ["Last warning", "Stop digging.\nOr finish it."],
		"mystery_chain_06": ["Escape account", "Transfer to the account in this message.\nOnly bank transfer counts."],
	}
	for email in EMAILS:
		var eid := str(email.get("id", ""))
		if table.has(eid):
			var pair: Array = table[eid]
			if not email.has("subject_en"):
				email["subject_en"] = pair[0]
			if not email.has("body_en"):
				email["body_en"] = pair[1]
		else:
			if not email.has("subject_en"):
				email["subject_en"] = str(email.get("subject", ""))
			if not email.has("body_en"):
				email["body_en"] = str(email.get("body", ""))
