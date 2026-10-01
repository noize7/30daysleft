extends Node
## =============================================================================
## EventSystem — Eventos con decisiones (Autoload)  [TANDA 9]
##
## Lee data/events.json. Durante el día (entre trabajos) puede aparecer un
## dilema con 2-3 opciones. Cada opción tiene consecuencias (dinero, cordura,
## sospecha, batería, tiempo, pistas). Mientras el evento está abierto el
## reloj y la batería se congelan (GameManager.event_pause).
## La ventana la dibuja scripts/ui/loop_hud.gd.
## =============================================================================

signal event_requested(event: Dictionary)
signal event_closed

const DATA_PATH := "res://data/events.json"
const MAX_EVENTS_PER_DAY: int = 2
const FIRST_EVENT_DAY: int = 2

var _events: Array = []
var seen_ids: Array = []
var events_today: int = 0
var _timer: float = 0.0
var _next_delay: float = 40.0
var _active: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_load_events()
	GameManager.pc_powered_changed.connect(_on_pc_powered)
	GameManager.day_changed.connect(_on_day_changed)


func _load_events() -> void:
	_events.clear()
	if not FileAccess.file_exists(DATA_PATH):
		push_warning("EventSystem: falta %s" % DATA_PATH)
		return
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	var raw: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(raw) != TYPE_DICTIONARY:
		push_warning("EventSystem: events.json inválido")
		return
	var list = raw.get("events", [])
	if list is Array:
		for e in list:
			if e is Dictionary:
				_events.append(e)


func reset() -> void:
	seen_ids.clear()
	events_today = 0
	_active = {}
	GameManager.event_pause = false
	_reset_timer()


func _reset_timer() -> void:
	_timer = 0.0
	_next_delay = _rng.randf_range(30.0, 60.0)


func _on_day_changed(_d: int) -> void:
	events_today = 0
	_reset_timer()


func _on_pc_powered(is_on: bool) -> void:
	_reset_timer()
	if not is_on and not _active.is_empty():
		close()


func is_active() -> bool:
	return not _active.is_empty()


func _process(delta: float) -> void:
	if not _active.is_empty():
		return
	if not GameManager.is_pc_on or GameManager.is_game_over or GameManager.tutorial_active:
		return
	if GameManager.day < FIRST_EVENT_DAY or events_today >= MAX_EVENTS_PER_DAY:
		return
	if GameManager.is_job_running:
		return
	_timer += delta
	if _timer < _next_delay:
		return
	_reset_timer()
	_try_fire()


func _eligible(e: Dictionary) -> bool:
	var d: int = GameManager.day
	if d < int(e.get("min_day", 1)) or d > int(e.get("max_day", 99)):
		return false
	if bool(e.get("once", true)) and str(e.get("id", "")) in seen_ids:
		return false
	if e.has("sanity_below") and GameManager.sanity >= float(e["sanity_below"]):
		return false
	if e.has("suspicion_above") and GameManager.suspicion <= float(e["suspicion_above"]):
		return false
	if e.has("payment") and GameManager.payment_method != str(e["payment"]):
		return false
	if e.has("min_money") and GameManager.money < float(e["min_money"]):
		return false
	return true


func _try_fire() -> void:
	var pool: Array = []
	var total: float = 0.0
	for e in _events:
		if _eligible(e):
			pool.append(e)
			total += float(e.get("weight", 1.0))
	if pool.is_empty() or total <= 0.0:
		return
	var roll: float = _rng.randf() * total
	var pick: Dictionary = pool[0]
	for e in pool:
		roll -= float(e.get("weight", 1.0))
		if roll <= 0.0:
			pick = e
			break
	fire(pick)


## Lanza un evento concreto (también útil para depurar).
func fire(e: Dictionary) -> void:
	if not _active.is_empty() or GameManager.is_game_over:
		return
	_active = e
	events_today += 1
	var id: String = str(e.get("id", ""))
	if id != "" and id not in seen_ids:
		seen_ids.append(id)
	GameManager.event_pause = true
	event_requested.emit(e)


## El jugador elige una opción. Devuelve el texto de resultado.
func choose(idx: int) -> String:
	if _active.is_empty():
		return ""
	var choices: Array = _active.get("choices", [])
	if idx < 0 or idx >= choices.size():
		return ""
	var ch: Dictionary = choices[idx]
	var effects_txt: String = _apply_effects(ch.get("effects", {}))
	var result: String = str(ch.get("result", ""))
	if effects_txt != "":
		result += "\n\n" + effects_txt
	return result


func close() -> void:
	_active = {}
	GameManager.event_pause = false
	event_closed.emit()


func _apply_effects(fx) -> String:
	if not (fx is Dictionary):
		return ""
	var parts: Array = []
	var q: float = 100.0
	if LoopSystem:
		q = LoopSystem.quota_target

	var money: float = float(fx.get("money", 0.0))
	if fx.has("money_q"):
		money += round(q * float(fx["money_q"]) / 5.0) * 5.0
	if money > 0.0:
		GameManager.add_money(money)
		parts.append("+$%d" % int(money))
	elif money < 0.0:
		var take: float = minf(-money, GameManager.money)
		if take > 0.0 and GameManager.spend_money(take):
			parts.append("-$%d" % int(take))

	var sanity: float = float(fx.get("sanity", 0.0))
	if sanity != 0.0:
		GameManager.change_sanity(sanity)
		parts.append("%+d cordura" % int(round(sanity)))

	var susp: float = float(fx.get("suspicion", 0.0))
	if susp != 0.0 and not GameManager.is_game_over:
		GameManager.change_suspicion(susp)
		parts.append("%+.1f sospecha" % susp)

	var bat: float = float(fx.get("battery_pct", 0.0))
	if bat != 0.0 and not GameManager.is_game_over:
		var amount: float = GameManager.max_battery * absf(bat) / 100.0
		if bat > 0.0:
			# Pérdida de batería: se aplica sin el freno del evento abierto
			GameManager.battery = clampf(GameManager.battery - amount, 1.0, GameManager.max_battery)
			GameManager.battery_changed.emit(GameManager.battery)
			parts.append("-%d%% batería" % int(bat))
		else:
			GameManager.set_battery(GameManager.battery + amount)
			parts.append("+%d%% batería" % int(absf(bat)))

	var minutes: int = int(fx.get("minutes", 0))
	if minutes > 0 and TimeManager:
		TimeManager.advance_minutes(minutes)
		parts.append("pasan %d min" % minutes)

	if bool(fx.get("clue", false)) and ClueSystem:
		ClueSystem.try_unlock_random_from_job()
		parts.append("nueva pista en Archivos")

	var out: String = ""
	for i in range(parts.size()):
		if i > 0:
			out += "   "
		out += str(parts[i])
	return out


# =============================================================================
# GUARDADO
# =============================================================================

func get_save_data() -> Dictionary:
	return {"seen": seen_ids.duplicate(), "today": events_today}


func load_save_data(data: Dictionary) -> void:
	seen_ids.clear()
	var s = data.get("seen", [])
	if s is Array:
		for id in s:
			seen_ids.append(str(id))
	events_today = int(data.get("today", 0))
	_reset_timer()
