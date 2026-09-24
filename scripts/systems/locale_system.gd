extends Node
## =============================================================================
## LocaleSystem — Idioma ES / EN (Autoload)
## =============================================================================
## Uso:
##   LocaleSystem.t("ui.play")           -> string de UI
##   LocaleSystem.field(dict, "text")    -> dict["text"] o dict["text_en"]
##   LocaleSystem.set_language("en")
## =============================================================================

signal language_changed(lang: String)

const SETTINGS_PATH := "user://settings.json"
const UI_PATH := "res://data/ui_strings.json"

## "es" | "en"
var language: String = "es"
var _ui: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_ui_strings()
	_load_language_from_settings()

func _load_ui_strings() -> void:
	_ui.clear()
	if not FileAccess.file_exists(UI_PATH):
		push_warning("LocaleSystem: missing ui_strings.json")
		return
	var f := FileAccess.open(UI_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		_ui = parsed

func _load_language_from_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var lang_idx := int(parsed.get("language", 0))
	language = "en" if lang_idx == 1 else "es"

func set_language(lang: String) -> void:
	var next := "en" if lang == "en" else "es"
	if next == language:
		return
	language = next
	language_changed.emit(language)

func set_language_index(idx: int) -> void:
	set_language("en" if idx == 1 else "es")

func get_language_index() -> int:
	return 1 if language == "en" else 0

## UI string by key. Supports "section.key" nested dicts.
func t(key: String, fallback: String = "") -> String:
	var node: Variant = _ui
	for part in key.split("."):
		if typeof(node) != TYPE_DICTIONARY or not node.has(part):
			return fallback if fallback != "" else key
		node = node[part]
	if typeof(node) == TYPE_DICTIONARY:
		if node.has(language):
			return str(node[language])
		if node.has("en"):
			return str(node["en"])
		if node.has("es"):
			return str(node["es"])
	return str(node)

## Pick localized field from content dict: prefers key_en when language is en.
func field(data: Dictionary, key: String, fallback: String = "") -> String:
	if data.is_empty():
		return fallback
	if language == "en":
		var en_key := key + "_en"
		if data.has(en_key) and str(data[en_key]).strip_edges() != "":
			return str(data[en_key])
	if data.has(key):
		return str(data[key])
	return fallback

func is_english() -> bool:
	return language == "en"
