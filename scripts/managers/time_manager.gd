extends Node
## =============================================================================
## TimeManager — Reloj del juego + drenaje de batería + ingreso pasivo (Autoload)
## Loop: encender → trabajar 01:00–05:00 → fuera de horario drenaje ↑ → apagar → día++
## =============================================================================

signal time_updated(hour: int, minute: int, second: int)
signal work_hours_changed(is_work_time: bool)
signal work_hours_warning(message: String)

var hour: int = 1
var minute: int = 0
var second: int = 0

# Base: ~0.28 %/s → ~6 min para vaciar 100 % (ajustable por opciones y cooling)
var BATTERY_DRAIN_PER_REAL_SECOND: float = 0.22
# Fuera de horario laboral la batería cae más rápido → empuja a apagar y avanzar día
var OFF_HOURS_DRAIN_MULT: float = 1.55
# 28 segundos de juego por cada segundo real
var GAME_SECONDS_PER_REAL_SECOND: float = 28.0

var _accum: float = 0.0
var is_work_time: bool = true
var _warned_end: bool = false
var _warned_last_hour: bool = false
var _ambient_tick: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_process(false)
	GameManager.pc_powered_changed.connect(_on_pc_powered)

func _on_pc_powered(is_on: bool) -> void:
	set_process(is_on)
	if is_on:
		hour = 1
		minute = 0
		second = 0
		_accum = 0.0
		_warned_end = false
		_warned_last_hour = false
		_ambient_tick = 0.0
		_update_work_time()
		time_updated.emit(hour, minute, second)
		# Liberar correos/archivos de las 1:00 del día actual al encender
		_check_timed_content()
		_check_time_dialogues()

func _center_pos() -> Vector2:
	var vp := get_viewport().get_visible_rect().size if get_viewport() else Vector2(540, 360)
	return Vector2(vp.x * 0.5, vp.y * 0.22)

func _process(delta: float) -> void:
	if GameManager.is_game_over or not GameManager.is_pc_on:
		return
	# Durante el tutorial: no drenar batería ni avanzar presión ambiental
	# (el reloj sí puede avanzar suavemente si se desea; aquí lo congelamos también)
	if GameManager.tutorial_active:
		return
	# Drenaje de batería (más fuerte fuera de horario)
	var drain_factor: float = 1.0
	if UpgradeSystem and UpgradeSystem.has_method("get_battery_drain_factor"):
		drain_factor = UpgradeSystem.get_battery_drain_factor()
	if not is_work_time:
		drain_factor *= OFF_HOURS_DRAIN_MULT
	GameManager.spend_battery(BATTERY_DRAIN_PER_REAL_SECOND * drain_factor * delta)
	# Ingreso pasivo solo con PC encendida
	if UpgradeSystem and UpgradeSystem.has_method("get_passive_income_per_sec"):
		var passive: float = UpgradeSystem.get_passive_income_per_sec()
		if passive > 0.0:
			GameManager.add_money(passive * delta)
	# Presión ambiental leve (cordura) cuando el día avanza y la PC sigue encendida
	_ambient_tick += delta
	if _ambient_tick >= 45.0:
		_ambient_tick = 0.0
		_ambient_pressure()
	# Reloj
	_accum += delta * GAME_SECONDS_PER_REAL_SECOND
	while _accum >= 1.0:
		_accum -= 1.0
		_tick_second()

func _ambient_pressure() -> void:
	# Después de las 05:00, o en días altos, un goteo de tensión
	if not is_work_time and GameManager.day >= 3:
		GameManager.change_sanity(-0.8)
		if GameManager.day >= 12 and randf() < 0.35:
			GameManager.change_suspicion(0.6)
	elif is_work_time and GameManager.day >= 15 and randf() < 0.2:
		GameManager.change_sanity(-0.4)

func _tick_second() -> void:
	second += 1
	var minute_changed := false
	if second >= 60:
		second = 0
		minute += 1
		minute_changed = true
		if minute >= 60:
			minute = 0
			hour += 1
			if hour >= 24:
				hour = 0
			_update_work_time()
			_check_hour_warnings()
	time_updated.emit(hour, minute, second)
	# Solo al cambiar de minuto: diálogos y correos/archivos programados
	if minute_changed:
		_check_time_dialogues()
		_check_timed_content()

func _check_hour_warnings() -> void:
	# Última hora laboral
	if hour == 4 and not _warned_last_hour:
		_warned_last_hour = true
		work_hours_warning.emit("Última hora laboral (hasta 05:00)")
		if VFXSystem:
			VFXSystem.spawn_floating_text("Última hora de trabajo", _center_pos(), Color(1.0, 0.85, 0.3), 24)
	# Fin de horario
	if hour == 5 and not _warned_end:
		_warned_end = true
		work_hours_warning.emit("Horario laboral terminado — apaga para avanzar el día")
		if VFXSystem:
			VFXSystem.spawn_floating_text(
				"Fuera de horario — apaga el PC para el día siguiente",
				_center_pos(), Color(1.0, 0.55, 0.35), 22
			)
			VFXSystem.flash_screen(Color(1.0, 0.5, 0.2, 0.12), 0.3)

func _update_work_time() -> void:
	var was: bool = is_work_time
	is_work_time = (hour >= 1 and hour < 5)
	if was != is_work_time:
		work_hours_changed.emit(is_work_time)
		if not is_work_time and not _warned_end:
			_check_hour_warnings()

func get_time_string() -> String:
	var h: int = hour
	var suffix: String = "AM"
	if h >= 12:
		suffix = "PM"
		if h > 12:
			h -= 12
	if h == 0:
		h = 12
	return "%02d:%02d %s" % [h, minute, suffix]

## Dispara diálogos programados por día/hora (ej. día 2 a las 2:40)
func _check_time_dialogues() -> void:
	if not DialogueSystem:
		return
	if GameManager.day == 2 and hour == 2 and minute >= 40:
		DialogueSystem.try_day_event("day_2_mid")
	if GameManager.day == 1 and hour == 1 and minute >= 20:
		DialogueSystem.try_day_event("day_1_player_thought")
	if GameManager.day == 4 and hour == 3 and minute >= 0:
		DialogueSystem.try_day_event("day_4_player_doubt")

## Libera correos/archivos que ya alcanzaron su hora de llegada
func _check_timed_content() -> void:
	if EmailSystem and EmailSystem.has_method("check_timed_unlocks"):
		EmailSystem.check_timed_unlocks()
	if ClueSystem and ClueSystem.has_method("check_timed_unlocks"):
		ClueSystem.check_timed_unlocks()
