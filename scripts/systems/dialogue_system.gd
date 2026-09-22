extends Node
## =============================================================================
## DialogueSystem — Sistema de diálogos (Autoload) — versión mejorada
##
## - Muestra diálogos con speaker + texto + (opcional) portrait
## - Soporta secuencias paso a paso (tutorial)
## - Puede ESPERAR a que el jugador realice una acción concreta
##   (icon_clicked:Trabajo, app_opened:Correo, etc.)
## - Emite señales para que la UI y otros sistemas reaccionen
## - Cola de diálogos + typewriter en la UI + sin parpadeos
## =============================================================================

signal dialogue_started(sequence_id: String)
signal dialogue_step(step_id: String, text: String)
signal dialogue_finished(sequence_id: String)
signal dialogue_waiting(action: String)  ## Esperando acción del jugador
signal action_reported(action: String)   ## Cualquier sistema puede reportar acciones

## true mientras hay un diálogo activo (bloquea o no según flags)
var is_active: bool = false
## true si el diálogo actual es del tutorial
var is_tutorial: bool = false
## Acción que se está esperando ahora mismo ("" si no espera)
var waiting_for: String = ""
## ID de la secuencia en curso
var current_sequence_id: String = ""

var _data: Dictionary = {}
var _steps: Array = []
var _step_index: int = 0
var _current_step: Dictionary = {}
var _dialogue_ui: Control = null
var _pending_queue: Array = []  ## Cola de diálogos cortos (day events, etc.)
var _advancing: bool = false    ## Evita reentradas en _advance

const DIALOGUE_UI_SCENE := preload("res://scenes/ui/dialogue_box.tscn")

func _ready() -> void:
	# Se pausa con Escape junto al resto del juego
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_load_data()
	# Escuchar acciones del resto del juego
	action_reported.connect(_on_action_reported)

func _load_data() -> void:
	var path := "res://data/dialogues.json"
	if not FileAccess.file_exists(path):
		push_warning("DialogueSystem: no se encontró dialogues.json")
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		_data = parsed

## Arranca una secuencia completa (ej: "tutorial")
func start_sequence(sequence_id: String) -> void:
	if is_active:
		_pending_queue.append({"type": "sequence", "id": sequence_id})
		return
	var seq: Dictionary = {}
	if sequence_id == "tutorial" and _data.has("tutorial"):
		seq = _data["tutorial"]
	elif _data.has("day_events") and _data["day_events"].has(sequence_id):
		# day event como secuencia de 1 paso
		seq = {
			"id": sequence_id,
			"speaker": _data["day_events"][sequence_id].get("speaker", "BOT-01"),
			"steps": [{
				"id": sequence_id,
				"text": _data["day_events"][sequence_id].get("text", ""),
				"wait_for": null
			}]
		}
	else:
		push_warning("DialogueSystem: secuencia desconocida: " + sequence_id)
		return

	current_sequence_id = sequence_id
	is_tutorial = (sequence_id == "tutorial")
	_steps = seq.get("steps", [])
	_step_index = 0
	is_active = true
	waiting_for = ""
	_advancing = false
	_ensure_ui()
	dialogue_started.emit(sequence_id)
	# Pequeño delay para que la UI esté lista y el escritorio se vea
	call_deferred("_show_current_step")

## Muestra un diálogo corto de un solo paso (eventos de día, etc.)
func show_line(speaker: String, text: String, once_id: String = "") -> void:
	if once_id != "" and GameManager.has_meta("dlg_" + once_id):
		return
	if once_id != "":
		GameManager.set_meta("dlg_" + once_id, true)

	if is_active:
		_pending_queue.append({"type": "line", "speaker": speaker, "text": text})
		return

	current_sequence_id = once_id if once_id != "" else "line"
	is_tutorial = false
	_steps = [{
		"id": current_sequence_id,
		"text": text,
		"wait_for": null,
		"speaker": speaker
	}]
	_step_index = 0
	is_active = true
	waiting_for = ""
	_advancing = false
	_ensure_ui()
	dialogue_started.emit(current_sequence_id)
	call_deferred("_show_current_step")

## Cualquier sistema llama esto cuando ocurre una acción relevante
## Ej: DialogueSystem.report_action("icon_clicked:Trabajo")
func report_action(action: String) -> void:
	action_reported.emit(action)

func _on_action_reported(action: String) -> void:
	if not is_active:
		return
	if waiting_for == "" or waiting_for != action:
		return
	# Acción correcta → avanzar (después de un frame para estabilidad)
	waiting_for = ""
	if _dialogue_ui and is_instance_valid(_dialogue_ui) and _dialogue_ui.has_method("set_waiting"):
		_dialogue_ui.set_waiting(false)
	call_deferred("_advance")

func _ensure_ui() -> void:
	if _dialogue_ui != null and is_instance_valid(_dialogue_ui):
		return
	var root := get_tree().root
	# Preferir colgarlo del DesktopUI o del Main (CanvasLayer sería ideal, pero mantenemos compat)
	var parent: Node = root.get_node_or_null("Main/DesktopUI")
	if parent == null:
		parent = root.get_node_or_null("Main")
	if parent == null:
		parent = root
	_dialogue_ui = DIALOGUE_UI_SCENE.instantiate()
	parent.add_child(_dialogue_ui)
	# Por debajo del menú de pausa (z=250); se pausa con el árbol
	_dialogue_ui.z_index = 100
	_dialogue_ui.z_as_relative = false
	_dialogue_ui.process_mode = Node.PROCESS_MODE_PAUSABLE
	_dialogue_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _dialogue_ui.has_signal("continue_pressed"):
		_dialogue_ui.continue_pressed.connect(_on_continue_pressed)

func _show_current_step() -> void:
	if not is_active:
		return
	if _step_index >= _steps.size():
		_finish_sequence()
		return

	_current_step = _steps[_step_index]
	var text: String = str(_current_step.get("text", ""))
	# Prioridad: speaker del paso > speaker de la secuencia > BOT-01
	var speaker: String = "BOT-01"
	if _data.has("tutorial") and current_sequence_id == "tutorial":
		speaker = str(_data["tutorial"].get("speaker", speaker))
	if _current_step.has("speaker") and str(_current_step["speaker"]) != "":
		speaker = str(_current_step["speaker"])

	var wait_raw = _current_step.get("wait_for", null)
	waiting_for = str(wait_raw) if wait_raw != null and str(wait_raw) != "" else ""

	if _dialogue_ui == null or not is_instance_valid(_dialogue_ui):
		_ensure_ui()

	if _dialogue_ui and _dialogue_ui.has_method("show_dialogue"):
		_dialogue_ui.show_dialogue(speaker, text, waiting_for != "")

	dialogue_step.emit(str(_current_step.get("id", "")), text)

	if waiting_for != "":
		dialogue_waiting.emit(waiting_for)
		# Highlight de icono si se indica
		var hl: String = str(_current_step.get("highlight", ""))
		if hl != "" and _dialogue_ui and _dialogue_ui.has_method("highlight_hint"):
			_dialogue_ui.highlight_hint(hl)

func _on_continue_pressed() -> void:
	# Solo se puede continuar si NO estamos esperando una acción
	if waiting_for != "":
		return
	if _advancing:
		return
	# Si la UI todavía está tipeando, no avanzar (la UI ya hace skip al pulsar)
	if _dialogue_ui and _dialogue_ui.has_method("is_typing") and _dialogue_ui.is_typing():
		return
	_advance()

func _advance() -> void:
	if _advancing or not is_active:
		return
	_advancing = true

	# Ejecutar on_complete del paso actual si existe
	var on_complete: String = str(_current_step.get("on_complete", ""))
	if on_complete == "end_tutorial":
		_end_tutorial_flag()

	_step_index += 1
	if _step_index >= _steps.size():
		_finish_sequence()
	else:
		# Pequeño delay entre pasos para que el fade del typewriter se sienta limpio
		await get_tree().create_timer(0.08).timeout
		if is_active:  # por si se canceló mientras esperábamos
			_show_current_step()
	_advancing = false

func _end_tutorial_flag() -> void:
	GameManager.tutorial_done = true
	GameManager.tutorial_active = false
	# Notificar a misiones
	if MissionSystem and MissionSystem.has_method("on_tutorial_finished"):
		MissionSystem.on_tutorial_finished()

func _finish_sequence() -> void:
	is_active = false
	waiting_for = ""
	_advancing = false
	var finished_id := current_sequence_id
	current_sequence_id = ""
	is_tutorial = false
	if _dialogue_ui and is_instance_valid(_dialogue_ui) and _dialogue_ui.has_method("hide_dialogue"):
		_dialogue_ui.hide_dialogue()
	dialogue_finished.emit(finished_id)
	# Procesar cola un frame después para que el hide termine de arrancar
	call_deferred("_process_queue")

func _process_queue() -> void:
	if _pending_queue.is_empty() or is_active:
		return
	var next: Dictionary = _pending_queue.pop_front()
	if next.get("type") == "sequence":
		start_sequence(str(next.get("id", "")))
	elif next.get("type") == "line":
		show_line(str(next.get("speaker", "BOT-01")), str(next.get("text", "")))

## Helpers para disparar eventos de día desde TimeManager / GameManager
func try_day_event(event_id: String) -> void:
	if not _data.has("day_events"):
		return
	var events: Dictionary = _data["day_events"]
	if not events.has(event_id):
		return
	var ev: Dictionary = events[event_id]
	if bool(ev.get("once", true)) and GameManager.has_meta("dlg_" + event_id):
		return
	# Condición de hora opcional
	if ev.has("condition"):
		var cond: Dictionary = ev["condition"]
		if cond.has("day") and GameManager.day != int(cond["day"]):
			return
		if cond.has("hour_min"):
			if TimeManager.hour < int(cond["hour_min"]):
				return
			if TimeManager.hour == int(cond["hour_min"]) and cond.has("minute_min"):
				if TimeManager.minute < int(cond["minute_min"]):
					return
	show_line(str(ev.get("speaker", "BOT-01")), str(ev.get("text", "")), event_id)

## Reinicia estado (nueva partida)
func reset() -> void:
	is_active = false
	is_tutorial = false
	waiting_for = ""
	current_sequence_id = ""
	_steps = []
	_step_index = 0
	_advancing = false
	_pending_queue.clear()
	if _dialogue_ui and is_instance_valid(_dialogue_ui):
		_dialogue_ui.queue_free()
		_dialogue_ui = null
