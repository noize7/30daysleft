extends Node
## =============================================================================
## ParanoiaSystem — Paranoia narrativa interna (0–100, nunca visible al jugador)
## =============================================================================
## No reemplaza a GameManager.sanity. La cordura sigue siendo el estado de juego;
## la paranoia controla la frecuencia y el tipo de anomalías narrativas.

signal paranoia_changed(level: float)
signal paranoia_event(event_type: String)

var _paranoia: float = 0.0
var _event_cooldown: float = 0.0
var _action_cooldown: float = 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	if GameManager:
		GameManager.sanity_changed.connect(_on_state_changed)
		GameManager.suspicion_changed.connect(_on_state_changed)
		GameManager.day_changed.connect(_on_day_changed)
		GameManager.pc_powered_changed.connect(_on_pc_powered)
	call_deferred("_recalculate")

func _process(delta: float) -> void:
	if GameManager == null or not GameManager.is_pc_on or GameManager.is_game_over:
		return
	if GameManager.tutorial_active:
		return
	_event_cooldown = maxf(0.0, _event_cooldown - delta)
	_action_cooldown = maxf(0.0, _action_cooldown - delta)
	if _event_cooldown <= 0.0:
		_try_narrative_event()

func _on_state_changed(_value: float) -> void:
	_recalculate()

func _on_day_changed(_day: int) -> void:
	_recalculate()
	_event_cooldown = 8.0

func _on_pc_powered(is_on: bool) -> void:
	if is_on:
		_recalculate()
		_event_cooldown = 12.0

func _recalculate() -> void:
	if GameManager == null:
		return
	# Cordura baja y sospecha alta son los factores principales.
	# El día añade presión gradual, pero nunca puede crear paranoia por sí solo.
	var sanity_component := (100.0 - GameManager.sanity) * 0.62
	var suspicion_component := GameManager.suspicion * 0.18
	var day_component := clampf(float(GameManager.day - 1) * 1.15, 0.0, 28.0)
	var investigation_component := 0.0
	if InvestigationSystem:
		investigation_component = minf(float(InvestigationSystem.discovered_files.size()) * 3.0, 18.0)
	var target := clampf(sanity_component + suspicion_component + day_component + investigation_component, 0.0, 100.0)
	_set_paranoia(target)

func _set_paranoia(value: float) -> void:
	var new_value := clampf(value, 0.0, 100.0)
	if absf(new_value - _paranoia) < 0.5:
		return
	_paranoia = new_value
	paranoia_changed.emit(_paranoia)

func get_paranoia() -> float:
	return _paranoia

func get_stage() -> String:
	if _paranoia < 21.0:
		return "normal"
	if _paranoia < 41.0:
		return "unease"
	if _paranoia < 71.0:
		return "paranoia"
	return "distortion"

func register_discovery_event(kind: String) -> void:
	# Descubrir archivos/pistas aumenta ligeramente la presión sin saltos bruscos.
	var amount := 0.0
	match kind:
		"file":
			amount = 2.5
		"story":
			amount = 1.0
		"clue":
			amount = 1.5
		"email":
			amount = 0.8
		_:
			amount = 0.5
	if amount <= 0.0:
		return
	_set_paranoia(_paranoia + amount)

func _try_narrative_event() -> void:
	var stage := get_stage()
	if stage == "normal":
		_event_cooldown = 5.0
		return
	var chance_per_second := 0.0
	var min_delay := 20.0
	var max_delay := 40.0
	match stage:
		"unease":
			chance_per_second = 0.018
			min_delay = 25.0
			max_delay = 45.0
		"paranoia":
			chance_per_second = 0.026
			min_delay = 20.0
			max_delay = 38.0
		"distortion":
			chance_per_second = 0.035
			min_delay = 16.0
			max_delay = 32.0
	if _rng.randf() < chance_per_second:
		var event_type := _pick_event(stage)
		paranoia_event.emit(event_type)
		_event_cooldown = _rng.randf_range(min_delay, max_delay)
	else:
		_event_cooldown = 1.0

func _pick_event(stage: String) -> String:
	var events: Array[String] = ["screen_glitch"]
	if stage == "unease":
		events.append_array(["fake_file", "screen_glitch"])
	elif stage == "paranoia":
		events.append_array(["fake_file", "email_echo", "screen_glitch"])
	else:
		events.append_array(["fake_file", "email_echo", "screen_glitch", "ui_corruption", "audio_distortion"])
	return events[_rng.randi_range(0, events.size() - 1)]

func trigger_paranoia_event() -> void:
	if _event_cooldown > 0.0:
		return
	var stage := get_stage()
	if stage == "normal":
		return
	paranoia_event.emit(_pick_event(stage))
	_event_cooldown = 18.0

func get_visual_intensity() -> float:
	if _paranoia < 21.0:
		return 0.0
	return clampf((_paranoia - 20.0) / 80.0, 0.0, 1.0)

func get_save_data() -> Dictionary:
	return {"paranoia": _paranoia}

func load_save_data(data: Dictionary) -> void:
	_paranoia = clampf(float(data.get("paranoia", 0.0)), 0.0, 100.0)
	paranoia_changed.emit(_paranoia)

func reset() -> void:
	_paranoia = 0.0
	_event_cooldown = 0.0
	_action_cooldown = 0.0
	paranoia_changed.emit(_paranoia)
