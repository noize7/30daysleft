extends Node
## =============================================================================
## WorkSystem — Catálogo de trabajos (Autoload) — expandido y balanceado
## Carga data/jobs.json + trabajos secretos.
## =============================================================================

const DATA_PATH := "res://data/jobs.json"

var JOBS: Array = []

## Trabajos secretos (requieren Internet nivel 2+)
const SECRET_JOBS: Array = [
	{
		"id": "secret_data", "level": 2, "secret": true,
		"name": "[SEC] Limpieza de datos",
		"description": "Borra rastros en servidores grises. Riesgo medio.",
		"min_pay": 100, "max_pay": 220, "duration": 12, "clicks_required": 9
	},
	{
		"id": "secret_scrape", "level": 2, "secret": true,
		"name": "[SEC] Scraping gris",
		"description": "Extrae datos de sitios sin API pública.",
		"min_pay": 90, "max_pay": 200, "duration": 11, "clicks_required": 10
	},
	{
		"id": "secret_proxy", "level": 3, "secret": true,
		"name": "[SEC] Proxy oscuro",
		"description": "Enruta tráfico anónimo. Requiere banda ancha.",
		"min_pay": 350, "max_pay": 700, "duration": 16, "clicks_required": 13
	},
	{
		"id": "secret_crypto", "level": 3, "secret": true,
		"name": "[SEC] Minería oculta",
		"description": "Configura nodos de minería en VPS baratos.",
		"min_pay": 400, "max_pay": 800, "duration": 17, "clicks_required": 14
	},
	{
		"id": "secret_contract", "level": 4, "secret": true,
		"name": "[SEC] Contrato sombra",
		"description": "Encargo sin nombre. Paga muy bien. No preguntes.",
		"min_pay": 1800, "max_pay": 4000, "duration": 22, "clicks_required": 18
	},
	{
		"id": "secret_zero", "level": 4, "secret": true,
		"name": "[SEC] Zero-day report",
		"description": "Documenta y vende un fallo de seguridad.",
		"min_pay": 2500, "max_pay": 5500, "duration": 24, "clicks_required": 20
	},
]

func _ready() -> void:
	_load_jobs()

func _load_jobs() -> void:
	JOBS.clear()
	if FileAccess.file_exists(DATA_PATH):
		var f := FileAccess.open(DATA_PATH, FileAccess.READ)
		var raw: Variant = JSON.parse_string(f.get_as_text())
		f.close()
		if typeof(raw) == TYPE_DICTIONARY:
			for j in raw.get("jobs", []):
				var job: Dictionary = j.duplicate()
				job["secret"] = false
				JOBS.append(job)
	for s in SECRET_JOBS:
		JOBS.append(s.duplicate())

func get_available_jobs() -> Array:
	var result: Array = []
	var access: int = 1
	if UpgradeSystem:
		if UpgradeSystem.has_method("get_job_level_access"):
			access = UpgradeSystem.get_job_level_access()
		elif UpgradeSystem.has_method("get_effective_job_level"):
			access = UpgradeSystem.get_effective_job_level()
	var allow_secret: bool = false
	var internet_lvl: int = 1
	if UpgradeSystem and UpgradeSystem.has_method("has_secret_jobs"):
		allow_secret = UpgradeSystem.has_secret_jobs()
	if UpgradeSystem and UpgradeSystem.has_method("get_level"):
		internet_lvl = UpgradeSystem.get_level("internet")
		allow_secret = allow_secret or internet_lvl >= 2
	for job in JOBS:
		var is_secret: bool = bool(job.get("secret", false))
		if is_secret and not allow_secret:
			continue
		if int(job.get("level", 1)) > access:
			continue
		# Tanda 8: tareas especiales requieren Internet alto
		if job.has("requires_internet") and internet_lvl < int(job["requires_internet"]):
			continue
		result.append(job)
	return result

func get_next_level_requirement() -> int:
	var next_level: int = GameManager.job_level + 1
	if not GameManager.LEVEL_REQUIREMENTS.has(next_level):
		return -1
	return int(GameManager.LEVEL_REQUIREMENTS[next_level])
