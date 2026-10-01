extends Node
## =============================================================================
## LoopSystem — Loop diario con decisiones (Autoload)  [TANDA 9]
##
## Añade tensión y objetivos a cada día:
##   - CUOTA diaria del empleador (escala con tu nivel de trabajo y el día)
##   - RACHA de calidad: notas A/S seguidas suben el pago; una C/D la rompe
##   - ENCARGOS: 3 objetivos opcionales por día con recompensa
##   - ACCIONES: Descansar (cordura a cambio de tiempo/batería) y
##               Borrar rastros (sospecha a cambio de dinero)
## La interfaz está en scripts/ui/loop_hud.gd (se crea sola).
## =============================================================================

signal state_changed
signal toast(text: String, color: Color)

const REST_MAX_PER_DAY: int = 3
const TRACKS_MAX_PER_DAY: int = 2
const REST_MINUTES: int = 25
const REST_BATTERY_PCT: float = 3.0
const REST_SANITY: float = 4.0
const TRACKS_SUSPICION: float = 6.0
const STREAK_MAX: int = 8
const STREAK_STEP: float = 0.04
## Los primeros días no hay castigo por no llegar a la cuota.
const GRACE_DAYS: int = 2

const COL_OK := Color(0.4, 0.95, 0.55)
const COL_WARN := Color(1.0, 0.8, 0.3)
const COL_BAD := Color(1.0, 0.4, 0.45)
const COL_INFO := Color(0.8, 0.7, 1.0)

var quota_target: float = 0.0
var earned_today: float = 0.0
var jobs_today: int = 0
var grades_a_today: int = 0
var streak: int = 0
var best_streak_today: int = 0
var rests_used: int = 0
var tracks_used: int = 0
var suspicion_at_day_start: float = 0.0
## Cada encargo: {type, title, target, progress, reward_q, reward_sanity, done, failed}
var contracts: Array = []
var last_summary: String = ""
var last_summary_color: Color = Color(0.8, 0.7, 1.0)
var hud_collapsed: bool = false
## Días seguidos cumpliendo la cuota.
var quota_streak_days: int = 0
var _started: bool = false


func _ready() -> void:
	GameManager.job_paid.connect(_on_job_paid)
	GameManager.pc_powered_changed.connect(_on_pc_powered)
	GameManager.suspicion_changed.connect(_on_suspicion_changed)
	TimeManager.time_updated.connect(_on_time_updated)
	call_deferred("_setup_hud")


func _setup_hud() -> void:
	var hud := CanvasLayer.new()
	hud.name = "LoopHUD"
	hud.set_script(load("res://scripts/ui/loop_hud.gd"))
	add_child(hud)


# =============================================================================
# INICIO / FIN DE DÍA
# =============================================================================

func reset() -> void:
	_started = false
	quota_target = 0.0
	quota_streak_days = 0
	last_summary = ""
	_begin_day()


func _begin_day() -> void:
	_started = true
	var d: int = GameManager.day
	earned_today = 0.0
	jobs_today = 0
	grades_a_today = 0
	streak = 0
	best_streak_today = 0
	rests_used = 0
	tracks_used = 0
	suspicion_at_day_start = GameManager.suspicion
	quota_target = _compute_quota(d)
	contracts = _roll_contracts(d)
	state_changed.emit()


## Llamado por GameManager al terminar el día (antes de day += 1).
func on_day_ending() -> void:
	if not _started:
		return
	# Encargos que se evalúan al cierre
	for c in contracts:
		if str(c["type"]) == "quiet" and not bool(c["done"]) and not bool(c["failed"]):
			_complete_contract(c)

	var d: int = GameManager.day
	var ratio: float = earned_today / maxf(1.0, quota_target)
	var sanity_d: float = 0.0
	var susp_d: float = 0.0
	var bonus: float = 0.0
	var verdict: String = ""
	var col: Color = COL_INFO

	if ratio >= 2.0:
		bonus = round(quota_target * 0.30)
		sanity_d = 3.0
		susp_d = -1.5
		quota_streak_days += 1
		verdict = "¡Sobrecumplido!"
		col = COL_OK
	elif ratio >= 1.0:
		bonus = round(quota_target * 0.10)
		sanity_d = 1.5
		susp_d = -1.0
		quota_streak_days += 1
		verdict = "Cuota cumplida"
		col = COL_OK
	else:
		quota_streak_days = 0
		if d > GRACE_DAYS:
			if ratio < 0.5:
				sanity_d = -4.0
				susp_d = 4.0
				verdict = "Cuota muy por debajo"
			else:
				sanity_d = -2.0
				susp_d = 2.0
				verdict = "Cuota no alcanzada"
			col = COL_BAD
		else:
			verdict = "Cuota no alcanzada (sin castigo aún)"
			col = COL_WARN

	# Premio por semanas de constancia
	if quota_streak_days > 0 and quota_streak_days % 5 == 0:
		sanity_d += 3.0
		susp_d -= 2.0
		verdict += " · ¡%d días seguidos!" % quota_streak_days

	last_summary = "Día %d: $%d de $%d — %s" % [d, int(earned_today), int(quota_target), verdict]
	if bonus > 0.0:
		last_summary += "  (bono +$%d)" % int(bonus)
	last_summary_color = col

	if bonus > 0.0:
		GameManager.add_money(bonus)
	if sanity_d != 0.0:
		GameManager.change_sanity(sanity_d)
	if susp_d != 0.0 and not GameManager.is_game_over:
		GameManager.change_suspicion(susp_d)


## Llamado por GameManager cuando ya empezó el día nuevo.
func on_day_started() -> void:
	_begin_day()


func _on_pc_powered(is_on: bool) -> void:
	if not is_on:
		return
	GameManager.is_job_running = false
	if not _started:
		_begin_day()
	if last_summary != "":
		var txt: String = last_summary
		var c: Color = last_summary_color
		last_summary = ""
		get_tree().create_timer(1.6).timeout.connect(func(): toast.emit(txt, c))
	state_changed.emit()


# =============================================================================
# CUOTA + RACHA
# =============================================================================

func _compute_quota(d: int) -> float:
	var access: int = 1
	if UpgradeSystem:
		access = UpgradeSystem.get_job_level_access()
	# Nivel más alto (no secreto) al que ya tienes acceso
	var top_level: int = 1
	for job in WorkSystem.JOBS:
		if bool(job.get("secret", false)):
			continue
		var lv: int = int(job.get("level", 1))
		if lv <= access and lv > top_level:
			top_level = lv
	var sum_pay: float = 0.0
	var count: int = 0
	for job in WorkSystem.JOBS:
		if bool(job.get("secret", false)) or int(job.get("level", 1)) != top_level:
			continue
		sum_pay += (float(job.get("min_pay", 0)) + float(job.get("max_pay", 0))) * 0.5
		count += 1
	var avg: float = 25.0
	if count > 0:
		avg = sum_pay / float(count)
	var cpu_mult: float = 1.0
	if UpgradeSystem:
		cpu_mult = UpgradeSystem.get_cpu_multiplier()
	# "Trabajos equivalentes" que exige el empleador: sube con los días.
	var jobs_needed: float = 3.0 + 0.22 * float(d)
	var q: float = avg * cpu_mult * jobs_needed
	return maxf(50.0, round(q / 10.0) * 10.0)


func get_pay_multiplier() -> float:
	return 1.0 + float(mini(streak, STREAK_MAX)) * STREAK_STEP


func _on_job_paid(pay: float, job: Dictionary) -> void:
	if not _started:
		_begin_day()
	jobs_today += 1
	earned_today += pay
	var quality: float = float(job.get("quality", 0.8))
	if quality >= 0.92:
		grades_a_today += 1
		streak += 1
	elif quality < 0.72:
		if streak >= 3:
			toast.emit("Racha perdida (×%d)" % streak, COL_BAD)
		streak = 0
	best_streak_today = maxi(best_streak_today, streak)
	_update_contracts()
	state_changed.emit()


func _on_time_updated(h: int, _m: int, _s: int) -> void:
	# Encargo "early": falla pasadas las 03:00
	if h < 3 or h > 12:
		return
	var changed: bool = false
	for c in contracts:
		if str(c["type"]) == "early" and not bool(c["done"]) and not bool(c["failed"]):
			c["failed"] = true
			changed = true
	if changed:
		state_changed.emit()


func _on_suspicion_changed(v: float) -> void:
	for c in contracts:
		if str(c["type"]) == "quiet" and not bool(c["done"]) and not bool(c["failed"]):
			var gained: float = v - suspicion_at_day_start
			c["progress"] = maxf(0.0, gained)
			if gained > float(c["target"]):
				c["failed"] = true
	state_changed.emit()


# =============================================================================
# ENCARGOS
# =============================================================================

func _roll_contracts(d: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%d" % [GameManager.escape_account_number, d])
	var pool: Array = ["jobs", "grades", "streak", "early", "quiet"]
	var out: Array = []
	while out.size() < 3 and not pool.is_empty():
		var i: int = rng.randi_range(0, pool.size() - 1)
		out.append(_make_contract(str(pool[i]), d))
		pool.remove_at(i)
	return out


func _make_contract(t: String, d: int) -> Dictionary:
	var c: Dictionary = {
		"type": t, "progress": 0.0, "done": false, "failed": false,
		"reward_q": 0.2, "reward_sanity": 0.0, "target": 1.0, "title": ""
	}
	match t:
		"jobs":
			var n: int = 3 + int(float(d) / 8.0)
			c["target"] = float(n)
			c["title"] = "Completa %d trabajos" % n
			c["reward_q"] = 0.20
		"grades":
			var n2: int = 2 + int(float(d) / 12.0)
			c["target"] = float(n2)
			c["title"] = "Saca %d notas A o S" % n2
			c["reward_q"] = 0.30
		"streak":
			var n3: int = mini(3 + int(float(d) / 6.0), 7)
			c["target"] = float(n3)
			c["title"] = "Alcanza racha ×%d" % n3
			c["reward_q"] = 0.35
		"early":
			var goal: float = maxf(30.0, round(quota_target * 0.5 / 10.0) * 10.0)
			c["target"] = goal
			c["title"] = "Gana $%d antes de las 03:00" % int(goal)
			c["reward_q"] = 0.35
		"quiet":
			c["target"] = 3.0
			c["title"] = "Sube menos de 3 de sospecha hoy"
			c["reward_q"] = 0.15
			c["reward_sanity"] = 2.0
	return c


func _update_contracts() -> void:
	for c in contracts:
		if bool(c["done"]) or bool(c["failed"]):
			continue
		match str(c["type"]):
			"jobs":
				c["progress"] = float(jobs_today)
			"grades":
				c["progress"] = float(grades_a_today)
			"streak":
				c["progress"] = float(best_streak_today)
			"early":
				c["progress"] = earned_today
			_:
				continue
		if float(c["progress"]) >= float(c["target"]):
			_complete_contract(c)


func _complete_contract(c: Dictionary) -> void:
	c["done"] = true
	var reward: float = round(quota_target * float(c.get("reward_q", 0.2)) / 5.0) * 5.0
	if reward > 0.0:
		GameManager.add_money(reward)
	var san: float = float(c.get("reward_sanity", 0.0))
	if san != 0.0:
		GameManager.change_sanity(san)
	toast.emit("✓ Encargo: %s   +$%d" % [str(c["title"]), int(reward)], COL_OK)
	state_changed.emit()


func contract_reward(c: Dictionary) -> int:
	return int(round(quota_target * float(c.get("reward_q", 0.2)) / 5.0) * 5.0)


# =============================================================================
# ACCIONES
# =============================================================================

func _can_act() -> bool:
	return GameManager.is_pc_on and not GameManager.is_game_over \
		and not GameManager.is_job_running and not GameManager.event_pause


func can_rest() -> bool:
	return _can_act() and rests_used < REST_MAX_PER_DAY


func do_rest() -> void:
	if not can_rest():
		return
	rests_used += 1
	GameManager.change_sanity(REST_SANITY)
	TimeManager.advance_minutes(REST_MINUTES)
	toast.emit("Respiras un momento… +%d cordura, pasan %d min" % [int(REST_SANITY), REST_MINUTES], COL_INFO)
	# El coste de batería va al final: si llega a 0 el día termina.
	state_changed.emit()
	GameManager.spend_battery(GameManager.max_battery * REST_BATTERY_PCT / 100.0)


func tracks_cost() -> float:
	return maxf(40.0, round(quota_target * 0.30 / 10.0) * 10.0)


func can_clean_tracks() -> bool:
	return _can_act() and tracks_used < TRACKS_MAX_PER_DAY \
		and GameManager.suspicion > 0.0 and GameManager.money >= tracks_cost()


func do_clean_tracks() -> void:
	if not can_clean_tracks():
		return
	if not GameManager.spend_money(tracks_cost()):
		return
	tracks_used += 1
	GameManager.change_suspicion(-TRACKS_SUSPICION)
	toast.emit("Rastros borrados: -%d sospecha" % int(TRACKS_SUSPICION), COL_INFO)
	state_changed.emit()


# =============================================================================
# GUARDADO
# =============================================================================

func get_save_data() -> Dictionary:
	return {
		"started": _started,
		"quota_target": quota_target,
		"earned_today": earned_today,
		"jobs_today": jobs_today,
		"grades_a_today": grades_a_today,
		"streak": streak,
		"best_streak_today": best_streak_today,
		"rests_used": rests_used,
		"tracks_used": tracks_used,
		"suspicion_at_day_start": suspicion_at_day_start,
		"contracts": contracts.duplicate(true),
		"last_summary": last_summary,
		"hud_collapsed": hud_collapsed,
		"quota_streak_days": quota_streak_days,
	}


func load_save_data(data: Dictionary) -> void:
	if data.is_empty():
		# Guardado antiguo: empieza el día con valores nuevos.
		_begin_day()
		return
	_started = bool(data.get("started", true))
	quota_target = float(data.get("quota_target", 0.0))
	earned_today = float(data.get("earned_today", 0.0))
	jobs_today = int(data.get("jobs_today", 0))
	grades_a_today = int(data.get("grades_a_today", 0))
	streak = int(data.get("streak", 0))
	best_streak_today = int(data.get("best_streak_today", 0))
	rests_used = int(data.get("rests_used", 0))
	tracks_used = int(data.get("tracks_used", 0))
	suspicion_at_day_start = float(data.get("suspicion_at_day_start", GameManager.suspicion))
	last_summary = str(data.get("last_summary", ""))
	hud_collapsed = bool(data.get("hud_collapsed", false))
	quota_streak_days = int(data.get("quota_streak_days", 0))
	contracts.clear()
	var raw = data.get("contracts", [])
	if raw is Array:
		for c in raw:
			if c is Dictionary:
				contracts.append(c)
	if quota_target <= 0.0 or contracts.is_empty():
		_begin_day()
		return
	state_changed.emit()
