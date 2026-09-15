extends Node
## =============================================================================
## GameManager — Estado global del juego (Autoload)
##
## Controla: día, dinero, batería, cordura, sospecha, nivel laboral,
## niveles de mejoras (Fase 3-4) y finales.
## Otros scripts leen/modifican este estado y escuchan sus señales.
## =============================================================================

signal day_changed(new_day: int)
signal money_changed(new_money: float)
signal battery_changed(new_battery: float)
signal sanity_changed(new_sanity: float)
signal suspicion_changed(new_suspicion: float)
signal game_over(ending: String)
signal pc_powered_changed(is_on: bool)
signal job_level_changed(new_level: int)
signal jobs_completed_changed(count: int)
## Se emite cuando sube el nivel de cualquier mejora (category, new_level)
signal upgrade_changed(category: String, new_level: int)
## Se emite al transferir a la cuenta de escape (progreso actualizado).
signal escape_changed(transferred: float)

func _ready() -> void:
	# Generar cuenta de escape al arrancar (nueva partida sin save).
	if escape_account_number.is_empty():
		_roll_escape_account()

# --- Variables de estado -----------------------------------------------------
var day: int = 1
var money: float = 0.0
var sanity: float = 100.0
var battery: float = 100.0
var max_battery: float = 100.0
var suspicion: float = 0.0

var job_level: int = 1          # 1=Encuestas … 4=Profesional
var jobs_completed: int = 0     # Contador para subir de nivel

# Niveles de mejoras de PC (Fase 3-4 + Tanda 8). Mínimo 1 en todas.
var upgrade_levels: Dictionary = {
	"battery": 1,
	"cpu": 1,
	"ram": 1,
	"internet": 1,
	"automation": 1,
	"cooling": 1,
	"storage": 1,
	"optimizer": 1,
	"noise_filter": 1,
	"proxy": 1,
	"log_cleaner": 1
}

## Método de cobro preferido: "cash" (efectivo) o "online".
## cash  → no sube sospecha; compras ilegales más caras/lentas
## online → compras baratas/rápidas; cada uso suma sospecha
var payment_method: String = "online"
signal payment_method_changed(method: String)

var is_pc_on: bool = false
var is_game_over: bool = false
var current_ending: String = ""

## Posiciones guardadas de los iconos del escritorio: nombre -> [x, y]
var icon_positions: Dictionary = {}

## Guarda (o actualiza) la posición de un icono del escritorio.
func set_icon_position(icon_name: String, pos: Vector2) -> void:
	icon_positions[icon_name] = [pos.x, pos.y]

## Meta de dinero para el final Escape (transferencia bancaria).
## Antes era 1.000.000 (demasiado alto); ahora es alcanzable en 30 días.
const MONEY_GOAL: float = 150000.0
const MAX_DAYS: int = 30

## --- Escape por transferencia bancaria ------------------------------------
## Día aleatorio (1–10) en el que llega el correo con el número de cuenta.
var escape_account_day: int = 1
## Número de cuenta objetivo (generado al iniciar partida).
var escape_account_number: String = ""
## Cantidad ya transferida a esa cuenta.
var escape_transferred: float = 0.0
## True si ya se envió el correo con la cuenta.
var escape_account_sent: bool = false
## Si true, no se dispara la secuencia de apagado (nueva partida / reset).
var suppress_shutdown: bool = false

## Genera un número de cuenta de 12 dígitos y el día de envío (0–10).
## Día 0 = llega en cuanto empieza la partida (día 1).
func _roll_escape_account() -> void:
	escape_account_day = randi_range(0, 10)
	var digits := ""
	for i in range(12):
		digits += str(randi_range(0, 9) if i > 0 else randi_range(1, 9))
	escape_account_number = digits
	escape_transferred = 0.0
	escape_account_sent = false
	# Notificar UI (progreso a 0 en nueva partida)
	escape_changed.emit(0.0)


## Cuánto falta por transferir para el escape.
func escape_remaining() -> float:
	return maxf(0.0, MONEY_GOAL - escape_transferred)

## True si ya se transfirió todo el dinero requerido.
func has_completed_escape_transfer() -> bool:
	return escape_transferred >= MONEY_GOAL - 0.01

# Trabajos necesarios para desbloquear cada nivel laboral
const LEVEL_REQUIREMENTS := {1: 0, 2: 6, 3: 18, 4: 35}

## Enciende la PC (empieza el drenaje de batería y el reloj).
func power_on_pc() -> void:
	if is_game_over:
		return
	is_pc_on = true
	pc_powered_changed.emit(true)

## Apaga la PC y termina el día actual.
func power_off_pc() -> void:
	is_pc_on = false
	pc_powered_changed.emit(false)
	_end_day()

## Suma dinero al jugador.
func add_money(amount: float) -> void:
	if is_game_over:
		return
	money += amount
	money_changed.emit(money)

## Resta dinero si hay suficiente. Devuelve true si se pudo gastar.
## Usa centavos para evitar fallos por flotantes (ej. 109 no dejar transferir 100).
func spend_money(amount: float) -> bool:
	if is_game_over:
		return false
	if amount <= 0.0:
		return false
	var money_cents: int = int(floor(money * 100.0 + 0.001))
	var amount_cents: int = int(floor(amount * 100.0 + 0.001))
	if amount_cents > money_cents:
		# Tolerancia de 1 céntimo
		if amount_cents <= money_cents + 1:
			amount_cents = money_cents
		else:
			return false
	money = float(money_cents - amount_cents) / 100.0
	money_changed.emit(money)
	return true

## Registra un trabajo terminado: paga (con multiplicador CPU) + nivel.
## Respeta el método de pago dual (Tanda 8).
func complete_job(pay: float, job_data: Dictionary = {}) -> void:
	if is_game_over:
		return
	# Multiplicador de CPU (Fase 4)
	var mult: float = UpgradeSystem.get_cpu_multiplier()
	var final_pay: float = pay * mult
	add_money(final_pay)
	jobs_completed += 1
	jobs_completed_changed.emit(jobs_completed)
	_check_job_level_up()

	# --- Pago dual (Tanda 8) ---
	if payment_method == "online":
		# Cada cobro online suma sospecha (mitigado por Proxy)
		var base_susp: float = 1.5 + (final_pay / 500.0)
		var susp_mult: float = 1.0
		if UpgradeSystem and UpgradeSystem.has_method("get_online_suspicion_mult"):
			susp_mult = UpgradeSystem.get_online_suspicion_mult()
		change_suspicion(base_susp * susp_mult)
	# cash: no suma sospecha

	# Pérdida de cordura por tipo de trabajo (mitigado por Filtro de ruido)
	var sanity_cost: float = float(job_data.get("sanity_cost", 0.0))
	if sanity_cost > 0.0:
		var s_mult: float = 1.0
		if UpgradeSystem and UpgradeSystem.has_method("get_sanity_loss_mult"):
			s_mult = UpgradeSystem.get_sanity_loss_mult()
		change_sanity(-sanity_cost * s_mult)

	# Algunos trabajos pueden generar pista / correo falso
	if bool(job_data.get("can_generate_clue", false)) and randf() < 0.12:
		if ClueSystem and ClueSystem.has_method("try_unlock_random_from_job"):
			ClueSystem.try_unlock_random_from_job()

## Comprueba si se alcanzó el requisito del siguiente nivel laboral.
func _check_job_level_up() -> void:
	var new_level: int = 1
	for lvl in [4, 3, 2, 1]:
		if jobs_completed >= int(LEVEL_REQUIREMENTS[lvl]):
			new_level = lvl
			break
	if new_level > job_level:
		job_level = new_level
		job_level_changed.emit(job_level)

## Gasta batería. Si llega a 0, apaga la PC (fin de día).
func spend_battery(amount: float) -> void:
	if not is_pc_on or is_game_over:
		return
	battery = clampf(battery - amount, 0.0, max_battery)
	battery_changed.emit(battery)
	if battery <= 0.0:
		power_off_pc()

func set_battery(value: float) -> void:
	battery = clampf(value, 0.0, max_battery)
	battery_changed.emit(battery)

## Cambia la capacidad maxima de bateria (tras comprar upgrade).
## Mantiene el porcentaje actual en la medida de lo posible.
func set_max_battery(new_max: float) -> void:
	var pct: float = get_battery_percent() / 100.0
	max_battery = maxf(1.0, new_max)
	battery = clampf(max_battery * pct, 0.0, max_battery)
	battery_changed.emit(battery)

func change_sanity(delta: float) -> void:
	sanity = clampf(sanity + delta, 0.0, 100.0)
	sanity_changed.emit(sanity)
	if sanity <= 0.0:
		trigger_ending("locura")

func change_suspicion(delta: float) -> void:
	var mult: float = 1.0
	if has_meta("suspicion_mult"):
		mult = float(get_meta("suspicion_mult"))
	suspicion = clampf(suspicion + delta * mult, 0.0, 100.0)
	suspicion_changed.emit(suspicion)
	if suspicion >= 100.0:
		trigger_ending("atrapado")

## Nivel actual de una categoria de mejora.
func get_upgrade_level(category: String) -> int:
	return int(upgrade_levels.get(category, 1))

## Establece el nivel de una mejora y notifica.
func set_upgrade_level(category: String, level: int) -> void:
	upgrade_levels[category] = level
	upgrade_changed.emit(category, level)

## Avanza al día siguiente y recarga la batería al máximo actual.
func _end_day() -> void:
	if is_game_over:
		return
	day += 1
	day_changed.emit(day)
	battery = max_battery
	battery_changed.emit(battery)
	# Eventos narrativos por día (presión gradual)
	_apply_day_events(day)
	# Auto-guardado al terminar el día (respeta opción auto_save)
	var do_autosave := true
	if FileAccess.file_exists("user://settings.json"):
		var f := FileAccess.open("user://settings.json", FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			f.close()
			if typeof(parsed) == TYPE_DICTIONARY and parsed.has("auto_save"):
				do_autosave = bool(parsed["auto_save"])
	if do_autosave and SaveManager:
		SaveManager.save_game()
	if day > MAX_DAYS:
		# El escape SOLO se consigue transfiriendo el dinero en el Banco.
		# Tener el dinero en mano no basta.
		if has_completed_escape_transfer() and ClueSystem.has_enough_for_escape():
			trigger_ending("escape")
		else:
			trigger_ending("atrapado")

## Cambia el método de cobro preferido ("cash" | "online").
func set_payment_method(method: String) -> void:
	if method != "cash" and method != "online":
		return
	payment_method = method
	payment_method_changed.emit(method)

## Eventos narrativos fijos por día (presión gradual de cordura/sospecha).
func _apply_day_events(d: int) -> void:
	# Desbloquear correos y pistas del nuevo día
	if EmailSystem:
		EmailSystem.unlock_for_day(d)
	if ClueSystem:
		ClueSystem.unlock_for_day(d)
	# Limpieza de logs (Script de limpieza) — chance al empezar el día
	if UpgradeSystem and UpgradeSystem.has_method("get_log_clean_chance"):
		var chance: float = UpgradeSystem.get_log_clean_chance()
		if chance > 0.0 and randf() < chance and suspicion > 0.0:
			var cleaned: float = minf(suspicion, randf_range(3.0, 8.0))
			change_suspicion(-cleaned)
	# Presión narrativa en días clave (DayEventManager)
	match d:
		5:
			change_sanity(-5.0)
			change_suspicion(5.0)
		8:
			# Correo policial ya se desbloquea por EmailSystem
			change_suspicion(3.0)
		10:
			change_sanity(-8.0)
			change_suspicion(8.0)
		14:
			change_sanity(-6.0)  # Crisis mental leve
		18, 19, 20:
			change_sanity(-8.0)
			change_suspicion(6.0)
			# Posible llegada falsa de efectivo si sanity baja
			if sanity < 40.0 and payment_method == "cash" and randf() < 0.35:
				_fake_cash_delivery()
		25:
			change_sanity(-12.0)
			change_suspicion(12.0)
		28, 29, 30:
			change_sanity(-10.0)
			change_suspicion(10.0)
		_:
			# Drenaje leve diario
			if d > 1 and d % 3 == 0:
				change_sanity(-2.0)
				change_suspicion(1.0)

## Alucinación: "llegada falsa" de efectivo cuando la cordura está baja.
func _fake_cash_delivery() -> void:
	# Feedback visual/auditivo vía SanityFX si existe
	if SanityFX and SanityFX.has_method("trigger_fake_delivery"):
		SanityFX.trigger_fake_delivery()
	# Pequeño golpe de cordura extra
	change_sanity(-4.0)

## Dispara un final y bloquea el juego.
func trigger_ending(ending: String) -> void:
	if is_game_over:
		return
	is_game_over = true
	is_pc_on = false
	current_ending = ending
	game_over.emit(ending)

## Porcentaje de batería (0–100) para la barra de la UI.
func get_battery_percent() -> float:
	if max_battery <= 0.0:
		return 0.0
	return (battery / max_battery) * 100.0

## Reinicia todo el estado (botón Reiniciar tras un final / Nueva partida).
func reset_game() -> void:
	# Evitar el flash de "Apagando PC" al reiniciar desde menú o final.
	suppress_shutdown = true
	day = 1
	money = 0.0
	sanity = 100.0
	battery = 100.0
	max_battery = 100.0
	suspicion = 0.0
	job_level = 1
	jobs_completed = 0
	payment_method = "online"
	upgrade_levels = {
		"battery": 1,
		"cpu": 1,
		"ram": 1,
		"internet": 1,
		"automation": 1,
		"cooling": 1,
		"storage": 1,
		"optimizer": 1,
		"noise_filter": 1,
		"proxy": 1,
		"log_cleaner": 1
	}
	is_pc_on = false
	is_game_over = false
	current_ending = ""
	icon_positions = {}
	_roll_escape_account()
	payment_method_changed.emit(payment_method)
	# Limpiar progreso narrativo (Tanda 4)
	if EmailSystem:
		EmailSystem.unlocked_ids.clear()
		EmailSystem.read_ids.clear()
		EmailSystem.unlock_for_day(1)
	if ClueSystem:
		ClueSystem.unlocked_ids.clear()
		ClueSystem.read_ids.clear()
		ClueSystem.unlock_for_day(1)
	day_changed.emit(day)
	money_changed.emit(money)
	battery_changed.emit(battery)
	sanity_changed.emit(sanity)
	suspicion_changed.emit(suspicion)
	job_level_changed.emit(job_level)
	jobs_completed_changed.emit(jobs_completed)
	for cat in upgrade_levels.keys():
		upgrade_changed.emit(str(cat), 1)
	pc_powered_changed.emit(false)
	# Liberar el flag en el siguiente frame para no interferir con el boot.
	call_deferred("_clear_suppress_shutdown")

func _clear_suppress_shutdown() -> void:
	suppress_shutdown = false

## Transfiere dinero a una cuenta. Si es la cuenta de escape, acumula progreso.
## Devuelve un mensaje de estado para la UI del banco.
func transfer_money(account: String, amount: float) -> String:
	if is_game_over:
		return "Partida terminada."
	account = account.strip_edges().replace(" ", "")
	if account.is_empty():
		return "Introduce un número de cuenta."
	if amount <= 0.0:
		return "La cantidad debe ser mayor que 0."
	# Redondeo a centavos y tope al saldo disponible
	var money_cents: int = int(floor(money * 100.0 + 0.001))
	var amount_cents: int = int(floor(amount * 100.0 + 0.001))
	if amount_cents <= 0:
		return "La cantidad debe ser mayor que 0."
	if amount_cents > money_cents:
		if amount_cents <= money_cents + 1:
			amount_cents = money_cents
		else:
			return "Saldo insuficiente (tienes $%.2f)." % money
	amount = float(amount_cents) / 100.0
	if not spend_money(amount):
		return "No se pudo completar la transferencia (saldo $%.2f)." % money
	# Comparar cuenta ignorando espacios
	var target: String = escape_account_number.strip_edges().replace(" ", "")
	if target != "" and account == target:
		escape_transferred += amount
		escape_changed.emit(escape_transferred)
		money_changed.emit(money)
		var remaining: float = escape_remaining()
		if remaining <= 0.01:
			if ClueSystem and ClueSystem.has_enough_for_escape():
				trigger_ending("escape")
				return "Transferencia completa. Ruta de escape activada."
			return "Transferencia completa ($%.0f). Aún necesitas más pistas en Archivos." % MONEY_GOAL
		return "Transferido $%.2f a la cuenta de escape. Faltan $%.2f." % [amount, remaining]
	return "Transferencia de $%.2f enviada a %s." % [amount, account]
