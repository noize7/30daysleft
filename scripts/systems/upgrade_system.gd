extends Node
## =============================================================================
## UpgradeSystem — Tienda de mejoras de PC (Autoload)
##
## Categorías: battery, cpu, ram, internet, automation, cooling, storage
## Lee data/upgrades.json. GameManager guarda los niveles.
## =============================================================================

signal upgrades_loaded

const DATA_PATH := "res://data/upgrades.json"

var _data: Dictionary = {}

const CATEGORY_LABELS := {
	"battery": "Bateria",
	"cpu": "CPU",
	"ram": "RAM",
	"internet": "Internet",
	"automation": "Automatizacion",
	"cooling": "Refrigeracion",
	"storage": "Almacenamiento"
}

const CATEGORY_ORDER := ["battery", "cpu", "ram", "internet", "automation", "cooling", "storage"]

## Iconos de cada categoría. Sustituye los PNG en assets/Icons Pc/ con los tuyos
## (mismo nombre de archivo) y se actualizarán solos.
const CATEGORY_ICON_PATHS := {
	"battery": "res://assets/Icons Pc/Bateria.png",
	"cpu": "res://assets/Icons Pc/CPU.png",
	"ram": "res://assets/Icons Pc/Ram.png",
	"internet": "res://assets/Icons Pc/Navegador.png",
	"automation": "res://assets/Icons Pc/bot.png",
	"cooling": "res://assets/Icons Pc/ventilador.png",
	"storage": "res://assets/Icons Pc/Almacenamiento.png",
}

func get_category_icon(category: String) -> Texture2D:
	var path: String = str(CATEGORY_ICON_PATHS.get(category, ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

func _ready() -> void:
	_load_data()

func _load_data() -> void:
	if not FileAccess.file_exists(DATA_PATH):
		push_error("UpgradeSystem: no existe %s" % DATA_PATH)
		return
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	var raw: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(raw) != TYPE_DICTIONARY:
		push_error("UpgradeSystem: JSON invalido")
		return
	_data = raw.get("upgrades", {})
	upgrades_loaded.emit()

func get_categories() -> Array:
	var out: Array = []
	for c in CATEGORY_ORDER:
		if _data.has(c):
			out.append(c)
	for c in _data.keys():
		if c not in out:
			out.append(c)
	return out

func get_level(category: String) -> int:
	return int(GameManager.upgrade_levels.get(category, 1))

func get_tiers(category: String) -> Array:
	return _data.get(category, [])

func get_current(category: String) -> Dictionary:
	var tiers: Array = get_tiers(category)
	var lvl: int = get_level(category)
	for t in tiers:
		if int(t.get("level", 0)) == lvl:
			return t
	if tiers.size() > 0:
		return tiers[0]
	return {}

func get_next(category: String) -> Dictionary:
	var tiers: Array = get_tiers(category)
	var lvl: int = get_level(category)
	for t in tiers:
		if int(t.get("level", 0)) == lvl + 1:
			return t
	return {}

func can_buy(category: String) -> bool:
	var nxt: Dictionary = get_next(category)
	if nxt.is_empty():
		return false
	return GameManager.money >= float(nxt.get("cost", 0))

func buy(category: String) -> bool:
	var nxt: Dictionary = get_next(category)
	if nxt.is_empty():
		return false
	var cost: float = float(nxt.get("cost", 0))
	if not GameManager.spend_money(cost):
		return false
	var new_lvl: int = int(nxt.get("level", 1))
	GameManager.upgrade_levels[category] = new_lvl
	# Aplicar efectos inmediatos
	if category == "battery":
		var cap: float = float(nxt.get("capacity", 100))
		GameManager.max_battery = cap
		# Rellenar un poco al mejorar
		GameManager.battery = mini(GameManager.battery + 20.0, cap)
		GameManager.battery_changed.emit(GameManager.battery)
	GameManager.upgrade_changed.emit(category, new_lvl)
	return true

func get_cpu_multiplier() -> float:
	var cur: Dictionary = get_current("cpu")
	var mult: float = float(cur.get("multiplier", 1.0))
	# Storage nivel 4+ da +10% extra
	if get_level("storage") >= 4:
		mult *= 1.10
	return mult

func get_passive_income_per_sec() -> float:
	var cur: Dictionary = get_current("automation")
	return float(cur.get("passive_per_sec", 0.0))

func get_battery_drain_mult() -> float:
	var cur: Dictionary = get_current("cooling")
	return float(cur.get("drain_mult", 1.0))

func has_hidden_files_access() -> bool:
	return get_level("ram") >= 3

## Internet nivel 2+ desbloquea trabajos secretos.
func has_secret_jobs() -> bool:
	return get_level("internet") >= 2

## Alias de get_cpu_multiplier (usado por desktop_ui / complete_job).
func get_pay_multiplier() -> float:
	return get_cpu_multiplier()

## Alias de get_battery_drain_mult (usado por TimeManager).
func get_battery_drain_factor() -> float:
	return get_battery_drain_mult()

## True si hay un siguiente nivel comprable (sin mirar dinero).
func can_upgrade(category: String) -> bool:
	return not get_next(category).is_empty()

func get_next_cost(category: String) -> int:
	var nxt: Dictionary = get_next(category)
	if nxt.is_empty():
		return 0
	return int(nxt.get("cost", 0))

## Alias de buy (usado por desktop_ui).
func try_buy(category: String) -> bool:
	return buy(category)

func get_effective_job_level() -> int:
	var base: int = GameManager.job_level
	# Internet 3+: +1 nivel efectivo
	if get_level("internet") >= 3:
		base = mini(4, base + 1)
	# Internet 5: siempre nivel 4
	if get_level("internet") >= 5:
		base = 4
	return base

func get_job_level_access() -> int:
	## Nivel máximo de trabajos que puede ver el jugador
	var base: int = GameManager.job_level
	if get_level("internet") >= 2:
		base = mini(4, base + 1)
	if get_level("internet") >= 5:
		base = 4
	return base

func get_suspicion_mult() -> float:
	if get_level("internet") >= 4:
		return 0.7
	return 1.0

func get_status_line(category: String) -> String:
	var cur: Dictionary = get_current(category)
	var nxt: Dictionary = get_next(category)
	var label: String = CATEGORY_LABELS.get(category, category)
	var cur_name: String = str(cur.get("name", "?"))
	if nxt.is_empty():
		return "%s: %s  [MAX]" % [label, cur_name]
	var cost: int = int(nxt.get("cost", 0))
	return "%s: %s  →  %s ($%d)" % [label, cur_name, str(nxt.get("name", "")), cost]

func get_desc_line(category: String) -> String:
	var cur: Dictionary = get_current(category)
	var nxt: Dictionary = get_next(category)
	if nxt.is_empty():
		return str(cur.get("desc", "Maximo alcanzado."))
	return "Actual: %s\nSiguiente: %s\nCoste: $%d" % [
		str(cur.get("desc", "")),
		str(nxt.get("desc", "")),
		int(nxt.get("cost", 0))
	]
