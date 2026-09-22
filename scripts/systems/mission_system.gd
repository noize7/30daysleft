extends Node
## =============================================================================
## MissionSystem — DESACTIVADO
## El sistema de misiones se eliminó por diseño. Este autoload queda como
## stub vacío para no romper referencias antiguas en el proyecto.
## =============================================================================

signal mission_started(mission_id: String, title: String)
signal mission_progress(mission_id: String, current: int, target: int)
signal mission_completed(mission_id: String, reward: float)
signal missions_updated()

var missions: Array = []
var active: Dictionary = {}
var completed_ids: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_DISABLED

func start_new_game_missions() -> void:
	active.clear()
	completed_ids.clear()
	missions_updated.emit()

func on_tutorial_finished() -> void:
	pass

## Stub: guardar (siempre vacío)
func get_save_data() -> Dictionary:
	return {}

## Stub: cargar (ignora datos antiguos de misiones)
func load_save_data(_data) -> void:
	active.clear()
	completed_ids.clear()
	missions_updated.emit()

## Stub: reset nueva partida
func reset() -> void:
	active.clear()
	completed_ids.clear()
	missions.clear()
	missions_updated.emit()
