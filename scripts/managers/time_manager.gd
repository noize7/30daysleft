extends Node
## =============================================================================
## TimeManager — Reloj del juego + drenaje de batería + ingreso pasivo (Autoload)
## Balanceado: ~5-7 min reales para vaciar 100% con cooling base.
## =============================================================================

signal time_updated(hour: int, minute: int, second: int)
signal work_hours_changed(is_work_time: bool)

var hour: int = 1
var minute: int = 0
var second: int = 0

# Base: ~0.28 %/s → ~6 min para vaciar 100 % (ajustable por opciones y cooling)
var BATTERY_DRAIN_PER_REAL_SECOND: float = 0.28
# 28 segundos de juego por cada segundo real
var GAME_SECONDS_PER_REAL_SECOND: float = 28.0

var _accum: float = 0.0
var is_work_time: bool = true

func _ready() -> void:
	set_process(false)
	GameManager.pc_powered_changed.connect(_on_pc_powered)

func _on_pc_powered(is_on: bool) -> void:
	set_process(is_on)
	if is_on:
		hour = 1
		minute = 0
		second = 0
		_accum = 0.0
		_update_work_time()
		time_updated.emit(hour, minute, second)

func _process(delta: float) -> void:
	if GameManager.is_game_over or not GameManager.is_pc_on:
		return
	# Drenaje de batería con factor de refrigeración
	var drain_factor: float = 1.0
	if UpgradeSystem and UpgradeSystem.has_method("get_battery_drain_factor"):
		drain_factor = UpgradeSystem.get_battery_drain_factor()
	GameManager.spend_battery(BATTERY_DRAIN_PER_REAL_SECOND * drain_factor * delta)
	# Ingreso pasivo
	var passive: float = UpgradeSystem.get_passive_income_per_sec()
	if passive > 0.0:
		GameManager.add_money(passive * delta)
	# Avance del reloj
	_accum += delta * GAME_SECONDS_PER_REAL_SECOND
	while _accum >= 1.0:
		_accum -= 1.0
		_tick_second()

func _tick_second() -> void:
	second += 1
	if second >= 60:
		second = 0
		minute += 1
		if minute >= 60:
			minute = 0
			hour += 1
			if hour >= 24:
				hour = 0
			_update_work_time()
	time_updated.emit(hour, minute, second)

func _update_work_time() -> void:
	var was: bool = is_work_time
	is_work_time = (hour >= 1 and hour < 5)
	if was != is_work_time:
		work_hours_changed.emit(is_work_time)

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
