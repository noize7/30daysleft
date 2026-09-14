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
		"is_fake": false,
		"type": "system",
		"from": "sistema@local",
		"subject": "Bienvenido de nuevo",
		"body": "Tu sesión se reinició.\nNo recordamos el último apagado limpio.\n\nRevisa los archivos cuando puedas.\n\n— Sistema"
	},
	{
		"id": "day1_job",
		"unlock_day": 1,
		"is_fake": false,
		"type": "job",
		"from": "noreply@workgrid.mail",
		"subject": "Nuevos encargos disponibles",
		"body": "Hola.\n\nHay encuestas activas entre la 01:00 y las 05:00.\nEl pago se acredita al instante.\n\nWorkGrid"
	},
	{
		"id": "day2_reminder",
		"unlock_day": 2,
		"is_fake": false,
		"type": "job",
		"from": "noreply@workgrid.mail",
		"subject": "Recordatorio de horario",
		"body": "El sistema detecta inactividad fuera de horario.\nRecuerda: solo se paga entre 01:00 y 05:00.\n\nWorkGrid"
	},
	{
		"id": "day3_odd",
		"unlock_day": 3,
		"is_fake": false,
		"type": "warning",
		"from": "desconocido",
		"subject": "No abras la carpeta recuerdos",
		"body": "Todavía no.\nNo estás listo.\n\nSi la abres, no podrás cerrarla."
	},
	{
		"id": "day5_memory",
		"unlock_day": 5,
		"is_fake": false,
		"type": "photo",
		"from": "tú@ayer",
		"subject": "Foto rota",
		"body": "Encontré una foto en el disco.\nEstá cortada por la mitad.\n\n¿Quién es la persona que falta?"
	},
	{
		"id": "day5_fake",
		"unlock_day": 5,
		"is_fake": true,
		"type": "warning",
		"from": "mamá",
		"subject": "Ven a casa",
		"body": "Cariño, la cena está lista.\nTodo está bien.\nNunca pasó nada.\n\n(Este mensaje no debería existir.)"
	},
	{
		"id": "day7_neighbor",
		"unlock_day": 7,
		"is_fake": false,
		"type": "text",
		"from": "vecino_402",
		"subject": "Anoche escuché algo",
		"body": "No quiero meterme en problemas,\npero anoche se escuchaban gritos en tu piso.\n\n¿Está todo bien?"
	},
	{
		"id": "day8_fake_call",
		"unlock_day": 8,
		"is_fake": true,
		"type": "warning",
		"from": "??? (llamada perdida)",
		"subject": "3 llamadas perdidas",
		"body": "Contesta.\nContesta.\nContesta.\n\n(No hay ningún número registrado.)"
	},
	{
		"id": "day10_police",
		"unlock_day": 10,
		"is_fake": false,
		"type": "police",
		"from": "alertas@ciudad.gov",
		"subject": "Aviso de investigación",
		"body": "Se ha abierto un expediente en tu zona.\nColabora si te contactan.\n\nNo ignores este mensaje."
	},
	{
		"id": "day10_fake",
		"unlock_day": 10,
		"is_fake": true,
		"type": "warning",
		"from": "policía",
		"subject": "YA SABEMOS DÓNDE ESTÁS",
		"body": "Abre la puerta.\nAbre la puerta.\nAbre la puerta.\n\n(Cordura baja: posible alucinación.)"
	},
	{
		"id": "day12_bank",
		"unlock_day": 12,
		"is_fake": false,
		"type": "document",
		"from": "notificaciones@bancocentral",
		"subject": "Movimiento inusual detectado",
		"body": "Se han registrado depósitos irregulares en tu cuenta.\nRevisa el detalle en la app del Banco.\n\nEste aviso es automático."
	},
	{
		"id": "day15_truth",
		"unlock_day": 15,
		"is_fake": false,
		"type": "medical",
		"from": "archivo.medico",
		"subject": "Informe incompleto",
		"body": "Paciente: [REDACTADO]\nDiagnóstico: lagunas de memoria / trauma.\nRecomendación: no aislarse.\n\nPágina 2 ilegible."
	},
	{
		"id": "day18_press",
		"unlock_day": 18,
		"is_fake": false,
		"type": "document",
		"from": "prensa.local",
		"subject": "Nota de prensa: caso sin resolver",
		"body": "\"Las autoridades siguen sin identificar sospechosos\",\ndice el artículo.\n\nHay una foto borrosa en la página 3."
	},
	{
		"id": "day20_crisis",
		"unlock_day": 20,
		"is_fake": false,
		"type": "system",
		"from": "sistema@local",
		"subject": "ERROR DE INTEGRIDAD",
		"body": "Varios archivos no coinciden con el checksum.\nAlguien (o algo) está reescribiendo el disco.\n\nConfía solo en lo que puedas verificar."
	},
	{
		"id": "day20_fake",
		"unlock_day": 20,
		"is_fake": true,
		"type": "warning",
		"from": "tú",
		"subject": "No hay salida",
		"body": "Da igual el dinero.\nDa igual el día 30.\nEsto no es un juego.\n\n(¿O sí?)"
	},
	{
		"id": "day22_fake_boss",
		"unlock_day": 22,
		"is_fake": true,
		"type": "warning",
		"from": "jefe@workgrid.mail",
		"subject": "Estás despedido",
		"body": "Ya no queda trabajo para ti.\nNunca lo hubo.\n\n(Este remitente no existe en los registros.)"
	},
	{
		"id": "day25_final",
		"unlock_day": 25,
		"is_fake": false,
		"type": "key",
		"from": "contacto.seguro",
		"subject": "Ruta de escape",
		"body": "Si juntaste el dinero y las pistas,\nhay una salida.\n\nSi no… ellos llegarán primero."
	},
	{
		"id": "day28_last_warning",
		"unlock_day": 28,
		"is_fake": false,
		"type": "police",
		"from": "alertas@ciudad.gov",
		"subject": "Últimas 48 horas",
		"body": "El expediente se cierra en 2 días.\nA partir de entonces la decisión no dependerá de ti.\n\nActúa ahora."
	},
	# --- Más correos (tanda contenido) ---
	{
		"id": "day4_noise",
		"unlock_day": 4,
		"is_fake": false,
		"type": "text",
		"from": "vecino_402",
		"subject": "¿Oyes eso?",
		"body": "Hay un zumbido en las paredes.\nEmpezó anoche.\n¿También lo oyes tú?"
	},
	{
		"id": "day6_spam_fake",
		"unlock_day": 6,
		"is_fake": true,
		"type": "warning",
		"sanity_delta": -5.0,
		"from": "premio@suerte.mail",
		"subject": "HAS GANADO $1.000.000",
		"body": "Haz clic aquí.\nHaz clic aquí.\nHaz clic aquí.\n\n(No hay enlace. No debería existir.)"
	},
	{
		"id": "day9_photo_mail",
		"unlock_day": 9,
		"is_fake": false,
		"type": "photo",
		"from": "archivo.local",
		"subject": "Adjunto: img_03.jpg",
		"body": "Se recuperó una imagen dañada del disco.\nMírala en Archivos → Foto rota."
	},
	{
		"id": "day11_whisper_fake",
		"unlock_day": 11,
		"is_fake": true,
		"type": "warning",
		"sanity_delta": -6.0,
		"from": "dentro.de.ti",
		"subject": "deja de mirar la pantalla",
		"body": "no eres tú quien escribe\nno eres tú quien lee\n\n(Cordura inestable.)"
	},
	{
		"id": "day13_work",
		"unlock_day": 13,
		"is_fake": false,
		"type": "job",
		"from": "noreply@workgrid.mail",
		"subject": "Bonificación nocturna",
		"body": "Los trabajos de nivel 3 pagan más esta semana.\nHorario sin cambios: 01:00–05:00."
	},
	{
		"id": "day14_static_fake",
		"unlock_day": 14,
		"is_fake": true,
		"type": "system",
		"sanity_delta": -4.0,
		"from": "sistema@local",
		"subject": "████████",
		"body": "El mensaje se corrompió.\nSolo quedan caracteres basura.\n\n¿O es tu mente?"
	},
	{
		"id": "day16_doctor",
		"unlock_day": 16,
		"is_fake": false,
		"type": "medical",
		"from": "consulta@clinica",
		"subject": "Recordatorio de cita",
		"body": "Cita pendiente: evaluación de memoria.\nNo acudiste la última vez.\nLlama si recuerdas este mensaje."
	},
	{
		"id": "day17_mirror_fake",
		"unlock_day": 17,
		"is_fake": true,
		"type": "warning",
		"sanity_delta": -7.0,
		"from": "espejo",
		"subject": "no te acerques",
		"body": "Si miras demasiado tiempo\nalguien mira desde el otro lado.\n\nCierra Archivos."
	},
	{
		"id": "day19_leak",
		"unlock_day": 19,
		"is_fake": false,
		"type": "document",
		"from": "fuente.anonima",
		"subject": "Filtración",
		"body": "El expediente habla de un testigo.\nEl nombre está tachado.\nLa fecha coincide con tu laguna."
	},
	{
		"id": "day21_loop_fake",
		"unlock_day": 21,
		"is_fake": true,
		"type": "system",
		"sanity_delta": -5.0,
		"from": "sistema@local",
		"subject": "Día 1 otra vez",
		"body": "Tu sesión se reinició.\nTu sesión se reinició.\nTu sesión se reinició."
	},
	{
		"id": "day23_deadline",
		"unlock_day": 23,
		"is_fake": false,
		"type": "police",
		"from": "alertas@ciudad.gov",
		"subject": "Plazo reducido",
		"body": "El cierre del caso se adelanta.\nNo salgas de la zona.\nNo ignores este aviso."
	},
	{
		"id": "day26_help_fake",
		"unlock_day": 26,
		"is_fake": true,
		"type": "key",
		"sanity_delta": -8.0,
		"from": "contacto.seguro",
		"subject": "Ruta falsa",
		"body": "Transfiere el dinero a ESTA cuenta:\n000000000000\n\n(Remitente clonado. No confíes.)"
	},
	{
		"id": "day29_countdown",
		"unlock_day": 29,
		"is_fake": false,
		"type": "system",
		"from": "sistema@local",
		"subject": "1 día restante",
		"body": "Mañana se evalúa el resultado.\nDinero transferido + pistas = salida.\nSin eso, no hay más reintentos."
	},
	# El correo de cuenta de escape se genera dinámicamente (ver try_send_escape_account).
]

## ID del correo dinámico con el número de cuenta de escape.
const ESCAPE_MAIL_ID := "escape_account"

## IDs desbloqueados en esta partida.
var unlocked_ids: Array = []
## IDs que el jugador ya abrió.
var read_ids: Array = []

func _ready() -> void:
	GameManager.day_changed.connect(_on_day_changed)
	# Día 1 al empezar
	unlock_for_day(1)
	try_send_escape_account(1)

## Desbloquea correos cuyo unlock_day <= día actual.
## Los falsos solo se desbloquean si sanity < 70 (o siempre a partir de cierto umbral).
func unlock_for_day(day: int) -> void:
	var changed := false
	for mail in EMAILS:
		var id: String = str(mail["id"])
		if id in unlocked_ids:
			continue
		if int(mail["unlock_day"]) > day:
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
	if changed:
		emails_changed.emit()

func _on_day_changed(new_day: int) -> void:
	unlock_for_day(new_day)
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
	for mail in EMAILS:
		if str(mail["id"]) in unlocked_ids:
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
	emails_changed.emit()

func is_read(email_id: String) -> bool:
	return email_id in read_ids

func unread_count() -> int:
	var n := 0
	for id in unlocked_ids:
		if id not in read_ids:
			n += 1
	return n
